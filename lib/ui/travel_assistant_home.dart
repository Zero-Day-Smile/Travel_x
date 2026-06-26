import 'package:flutter/material.dart';

import '../domain/hotspot.dart';
import '../domain/trip_preferences.dart';
import '../services/ml_recommender.dart';
import '../services/reels_query_builder.dart';
import 'widgets/hotspot_card.dart';
import 'widgets/preferences_chips.dart';
import 'widgets/reels_row.dart';

class TravelAssistantHome extends StatefulWidget {
  const TravelAssistantHome({super.key});

  @override
  State<TravelAssistantHome> createState() => _TravelAssistantHomeState();
}

class _TravelAssistantHomeState extends State<TravelAssistantHome> {
  final _promptController = TextEditingController();
  bool _isGenerating = false;
  String _response = '';

  List<Hotspot> _hotspots = const [];
  Set<InterestCategory> _categories = const {};
  List<ReelsLink> _reels = const [];
  final Set<String> _visited = {};
  final Set<String> _liked = {};
  final Set<String> _saved = {};
  final Set<String> _skipped = {};

  final MlRecommender _recommender = const MlRecommender();
  final ReelsQueryBuilder _reelsBuilder = const ReelsQueryBuilder();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  List<InterestCategory> _extractCategories(String lower) {
    final cats = <InterestCategory>{};

    bool hasAny(List<String> words) => words.any(lower.contains);

    if (hasAny(['food', 'cafe', 'restaurant', 'street food', 'market'])) {
      cats.add(InterestCategory.food);
      cats.add(InterestCategory.culture);
    }
    if (hasAny(['nightlife', 'club', 'bars', 'bar', 'party'])) {
      cats.add(InterestCategory.nightlife);
    }
    if (hasAny(['shopping', 'mall', 'market', 'souvenir'])) {
      cats.add(InterestCategory.shopping);
    }
    if (hasAny(['nature', 'hike', 'hiking', 'beach', 'park', 'scenic'])) {
      cats.add(InterestCategory.nature);
      cats.add(InterestCategory.adventure);
    }
    if (hasAny(['history', 'museum', 'ancient', 'heritage'])) {
      cats.add(InterestCategory.history);
      cats.add(InterestCategory.culture);
    }
    if (hasAny(['culture', 'art', 'local', 'neighborhood'])) {
      cats.add(InterestCategory.culture);
    }
    if (hasAny(['view', 'views', 'sunset', 'panorama', 'rooftop', 'skyline'])) {
      cats.add(InterestCategory.views);
    }
    if (hasAny(['family', 'kids', 'kid-friendly'])) {
      cats.add(InterestCategory.family);
    }
    if (hasAny(['romantic', 'date', 'couple', 'honeymoon'])) {
      cats.add(InterestCategory.romantic);
    }
    if (hasAny(['adventure', 'hike', 'outdoor'])) {
      cats.add(InterestCategory.adventure);
    }

    return cats.toList();
  }

  String? _extractDestination(String prompt) {
    final lower = prompt.toLowerCase();

    const candidates = [
      'paris',
      'rome',
      'london',
      'new york',
      'tokyo',
      'seoul',
      'bangkok',
      'singapore',
      'dubai',
      'istanbul',
      'barcelona',
      'amsterdam',
      'berlin',
      'madrid',
      'prague',
      'vienna',
      'lisbon',
      'cape town',
      'sydney',
      'melbourne',
      'chennai',
      'bengaluru',
      'mumbai',
      'delhi',
      'goa',
      'kochi',
    ];

    for (final c in candidates) {
      if (lower.contains(c)) return c;
    }

    final toMatch = RegExp(
      r'\bto\s+([a-zA-Z][a-zA-Z\s-]{2,30})',
    ).firstMatch(prompt);
    if (toMatch != null) {
      final raw = toMatch.group(1)!.trim();
      return raw.replaceAll(RegExp(r'[^a-zA-Z\s-]'), '').trim();
    }

    final inMatch = RegExp(
      r'\bin\s+([a-zA-Z][a-zA-Z\s-]{2,30})',
    ).firstMatch(prompt);
    if (inMatch != null) {
      final raw = inMatch.group(1)!.trim();
      return raw.replaceAll(RegExp(r'[^a-zA-Z\s-]'), '').trim();
    }

    return null;
  }

  String _extractTone(String lower) {
    if (lower.contains('budget') ||
        lower.contains('cheap') ||
        lower.contains('affordable')) {
      return 'budget-friendly';
    }
    if (lower.contains('luxury') || lower.contains('premium')) {
      return 'premium';
    }
    if (lower.contains('family') || lower.contains('kids')) {
      return 'family-friendly';
    }
    if (lower.contains('romantic') || lower.contains('date')) {
      return 'romantic';
    }
    if (lower.contains('adventure') ||
        lower.contains('hike') ||
        lower.contains('outdoor')) {
      return 'adventure-focused';
    }
    if (lower.contains('relaxed') ||
        lower.contains('slow') ||
        lower.contains('easy')) {
      return 'relaxed';
    }
    return 'balanced';
  }

  String _extractTripType(String lower) {
    if (lower.contains('food') ||
        lower.contains('cafe') ||
        lower.contains('restaurant')) {
      return 'food & culture';
    }
    if (lower.contains('nature') ||
        lower.contains('hike') ||
        lower.contains('beach')) {
      return 'nature & views';
    }
    if (lower.contains('shopping')) {
      return 'shopping & neighborhoods';
    }
    if (lower.contains('history') ||
        lower.contains('museum') ||
        lower.contains('ancient')) {
      return 'history & museums';
    }
    if (lower.contains('nightlife') ||
        lower.contains('club') ||
        lower.contains('bars')) {
      return 'nightlife highlights';
    }
    if (lower.contains('road trip') || lower.contains('rental car')) {
      return 'day trips';
    }
    return 'sights & local experiences';
  }

  String _extractBudget(String lower) {
    if (lower.contains('ultra') || lower.contains('no budget')) {
      return 'Focus on experiences — reserve popular attractions early.';
    }

    if (lower.contains('mid') || lower.contains('moderate')) {
      return 'Mix free sights with a few paid “must-do” experiences. Use transit/metro when possible.';
    }

    if (lower.contains('budget') ||
        lower.contains('cheap') ||
        lower.contains('affordable')) {
      return 'Prioritize walkable areas, free museums, and local markets. Book only the top 1–2 attractions ahead.';
    }

    if (lower.contains('luxury') || lower.contains('premium')) {
      return 'Plan one signature experience per day. Consider guided tours to save time and skip lines.';
    }

    return 'Keep it flexible: 1–2 paid activities/day, and build your days around neighborhoods.';
  }

  int _extractDays(String lower) {
    final weekend = lower.contains('weekend');
    if (weekend) return 2;

    final match = RegExp(r'(\d{1,2})\s*(day|days|d)\b').firstMatch(lower);
    if (match != null) {
      return int.parse(match.group(1)!);
    }

    if (lower.contains('a week') || lower.contains('week')) return 7;

    return 4; // default
  }

  String _budgetTierFromPrompt(String lower) {
    if (lower.contains('ultra') || lower.contains('no budget')) return 'any';
    if (lower.contains('luxury') || lower.contains('premium')) return 'premium';
    if (lower.contains('budget') ||
        lower.contains('cheap') ||
        lower.contains('affordable')) {
      return 'budget';
    }
    if (lower.contains('mid') || lower.contains('moderate')) return 'mid';
    return 'mid';
  }

  List<String> _buildPackingTips(String lower) {
    final List<String> tips = [];
    tips.add('Bring a reusable water bottle and a small day bag.');
    tips.add(
      'Pack comfortable walking shoes — most itineraries are step-heavy.',
    );

    if (lower.contains('rain') ||
        lower.contains('wet') ||
        lower.contains('storm')) {
      tips.add('Add a compact umbrella or lightweight rain jacket.');
    } else {
      tips.add('Include sunscreen and a hat for midday sun.');
    }

    if (lower.contains('winter') ||
        lower.contains('snow') ||
        lower.contains('cold')) {
      tips.add('Layering: base + warm mid + windproof outer layer.');
    } else if (lower.contains('summer') ||
        lower.contains('hot') ||
        lower.contains('warm')) {
      tips.add('Lightweight breathable clothes, plus a quick-dry option.');
    }

    if (lower.contains('international') ||
        lower.contains('passport') ||
        lower.contains('visa') ||
        lower.contains('country')) {
      tips.add('Keep passport/ID and travel docs in an easy-access pouch.');
    }

    tips.add('Carry offline maps/screenshots for areas with weak signal.');

    return tips.take(6).toList();
  }

  List<String> _buildItinerary({
    required String destination,
    required String tripType,
    required int days,
    required String budget,
  }) {
    final List<String> out = [];
    for (var d = 1; d <= days; d++) {
      if (d == 1) {
        out.add(
          'Day $d: Arrive + check-in; do an easy “orientation walk” and a local dinner nearby ($tripType). Budget logic: $budget',
        );
      } else if (d == days) {
        out.add(
          'Day $d: Top highlight + souvenir stop; relaxed final meal, then depart. ($tripType).',
        );
      } else {
        final focus = switch (d % 3) {
          0 => 'viewpoint / sunset stop',
          1 => 'major attraction + nearby neighborhood',
          _ => 'local food markets + cultural spots',
        };
        out.add(
          'Day $d: Morning sights ($focus), afternoon flexible time, evening local experience.',
        );
      }
    }
    return out;
  }

  List<Hotspot> _optimizedRoute() {
    final route = [..._hotspots.where((h) => !_skipped.contains(h.name))];
    route.sort((a, b) {
      final aRouteScore =
          a.distanceScore + a.budgetScore + a.crowdScore - a.routeMinutes;
      final bRouteScore =
          b.distanceScore + b.budgetScore + b.crowdScore - b.routeMinutes;
      return bRouteScore.compareTo(aRouteScore);
    });
    return route.take(4).toList();
  }

  String _chatSuggestion() {
    if (_hotspots.isEmpty) {
      return 'Tell Dravik your time, budget, and mood. Try: I am bored in Chennai with Rs.500.';
    }

    final candidates = _hotspots.where((h) => !_skipped.contains(h.name));
    final best = candidates.isEmpty ? _hotspots.first : candidates.first;
    final learned = _liked.isNotEmpty || _saved.isNotEmpty
        ? 'Based on your saved/liked memory, '
        : '';
    return '${learned}there is ${best.name} ${best.distanceKm.toStringAsFixed(1)} km away. Average cost ${best.cost}. Best around ${best.bestTime}. Want directions?';
  }

  String _similarTravelerSegment() {
    if (_categories.contains(InterestCategory.food) &&
        _categories.contains(InterestCategory.views)) {
      return 'Food + Sunset Explorers usually pick cafes, street food lanes, and quiet viewpoints.';
    }
    if (_categories.contains(InterestCategory.culture) ||
        _categories.contains(InterestCategory.history)) {
      return 'Culture Seekers usually save heritage walks, art villages, markets, and old neighborhoods.';
    }
    if (_categories.contains(InterestCategory.adventure) ||
        _categories.contains(InterestCategory.nature)) {
      return 'Outdoor Explorers usually prefer parks, scenic loops, beaches, and low-crowd morning routes.';
    }
    return 'Balanced Explorers usually mix food, local culture, one viewpoint, and one flexible indoor stop.';
  }

  void _remember(String name, Set<String> bucket) {
    setState(() {
      bucket.add(name);
      if (identical(bucket, _skipped)) {
        _saved.remove(name);
        _liked.remove(name);
      } else {
        _skipped.remove(name);
      }
    });
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    final lower = prompt.toLowerCase();
    final destination = _extractDestination(prompt) ?? 'your destination';
    final days = _extractDays(lower);

    final categories = _extractCategories(lower).toSet();
    final budgetTier = _budgetTierFromPrompt(lower);

    final prefs = TripPreferences(
      destination: destination,
      categories: categories,
      days: days,
      budgetTier: budgetTier,
    );

    final ranked = _recommender.recommend(prefs: prefs, topK: 6);
    final reelsLinks = _reelsBuilder.build(
      destination: destination,
      categories: categories,
      maxLinks: 6,
    );

    setState(() {
      _isGenerating = true;
      _response = '';
      _hotspots = ranked;
      _categories = categories;
      _reels = reelsLinks;
    });

    await Future<void>.delayed(const Duration(milliseconds: 450));

    // Existing itinerary text generation.
    final tripType = _extractTripType(lower);
    final budget = _extractBudget(lower);
    final tone = _extractTone(lower);

    final itinerary = _buildItinerary(
      destination: destination,
      tripType: tripType,
      days: days,
      budget: budget,
    );

    final tips = _buildPackingTips(lower);

    final answer = [
      'Dravik Explore AI: what should you do next in $destination?',
      '',
      'Context detected: $days days, $tone, $tripType.',
      '',
      'Day-by-day itinerary:',
      for (final day in itinerary) '• $day',
      '',
      'Top next actions:',
      for (final h in ranked.take(3))
        '• ${h.name} — ${h.matchScore}% match, ${h.hiddenGemScore}% hidden-gem score, best around ${h.bestTime}. ${h.whyMatched}',
      '',
      'Smart route optimization:',
      for (final h in _optimizedRoute().take(3))
        '• ${h.name}: ${h.routeMinutes} min, route cost about ${h.routeCost}, ${h.crowd.toLowerCase()} crowd.',
      '',
      'Travel chat assistant:',
      _chatSuggestion(),
      '',
      'Similar traveler matching:',
      _similarTravelerSegment(),
      '',
      'Budget intelligence:',
      budget,
      '',
      'Packing & practical tips:',
      for (final t in tips) '• $t',
      '',
      'Discovery scores combine interest match, hidden-gem potential, crowd, budget, distance, and weather fit.',
    ].join('\n');

    const chunkSize = 55;
    for (var i = 0; i < answer.length; i += chunkSize) {
      setState(() {
        _response = answer.substring(
          0,
          i + chunkSize > answer.length ? answer.length : i + chunkSize,
        );
      });
      await Future<void>.delayed(const Duration(milliseconds: 14));
    }

    setState(() {
      _isGenerating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dravik Explore AI'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.offline_bolt_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Offline demo',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildLeft(context)),
                            const SizedBox(width: 18),
                            Expanded(flex: 4, child: _buildRight(context)),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildLeft(context),
                              const SizedBox(height: 14),
                              _buildRight(context),
                            ],
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeft(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 10),
        _PromptComposer(
          controller: _promptController,
          isGenerating: _isGenerating,
          onGenerate: _generate,
          onQuickFill: (text) {
            setState(() {
              _promptController.text = text;
            });
          },
        ),
        const SizedBox(height: 12),
        _ResponseCard(response: _response, isGenerating: _isGenerating),
      ],
    );
  }

  Widget _buildRight(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          'Dravik Explore AI (MVP)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Dravik answers: what to do next. Enter your context, then Generate to see ranked “things to do” + explainability + reels demo links.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text(
          'Smart Traveler Profile (MVP)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Detected interests (offline)',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        PreferencesChips(categories: _categories),
        const SizedBox(height: 16),
        Text(
          'What to do next (ranked hotspots)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        if (_hotspots.isEmpty)
          Text(
            'Generate a plan to see ranked hotspots.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Column(
            children: [
              for (final h in _hotspots)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HotspotCard(hotspot: h),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.check_circle_outline),
                            label: const Text('Visited'),
                            onPressed: () => _remember(h.name, _visited),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.favorite_border),
                            label: const Text('Like'),
                            onPressed: () => _remember(h.name, _liked),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.bookmark_border),
                            label: const Text('Save'),
                            onPressed: () => _remember(h.name, _saved),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.close),
                            label: const Text('Skip'),
                            onPressed: () => _remember(h.name, _skipped),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        _InsightPanel(
          title: 'Smart Route Optimization',
          icon: Icons.route_outlined,
          child: _hotspots.isEmpty
              ? const Text('Generate recommendations to optimize a route.')
              : Column(
                  children: [
                    for (final entry in _optimizedRoute().indexed)
                      _RouteStep(index: entry.$1 + 1, hotspot: entry.$2),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _InsightPanel(
          title: 'Travel Chat Assistant',
          icon: Icons.chat_bubble_outline,
          child: Text(_chatSuggestion()),
        ),
        const SizedBox(height: 12),
        _InsightPanel(
          title: 'Similar Traveler Matching',
          icon: Icons.diversity_3_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_similarTravelerSegment()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in _hotspots.take(3))
                    Chip(label: Text(h.name), avatar: const Icon(Icons.place)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _InsightPanel(
          title: 'Travel Memory System',
          icon: Icons.memory_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MemoryChip(label: 'Visited', count: _visited.length),
              _MemoryChip(label: 'Liked', count: _liked.length),
              _MemoryChip(label: 'Saved', count: _saved.length),
              _MemoryChip(label: 'Skipped', count: _skipped.length),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Reels to watch (safe demo links)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        ReelsRow(links: _reels),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.airplanemode_active_rounded, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dravik Explore AI',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Answers what to do next, not just where to go.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PromptComposer extends StatelessWidget {
  const _PromptComposer({
    required this.controller,
    required this.isGenerating,
    required this.onGenerate,
    required this.onQuickFill,
  });

  final TextEditingController controller;
  final bool isGenerating;
  final VoidCallback onGenerate;
  final void Function(String text) onQuickFill;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Describe your trip',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 5,
              enabled: !isGenerating,
              decoration: InputDecoration(
                hintText:
                    'Example: I have 4 hours in Chennai, Rs.1000, food and sunset views',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'Quick fill',
                  onPressed: isGenerating
                      ? null
                      : () => onQuickFill(
                          'I have 4 hours in Chennai with Rs.1000. I like street food, photography, hidden places, and sunset views.',
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isGenerating ? null : onGenerate,
                    icon: const Icon(Icons.travel_explore_rounded),
                    label: Text(isGenerating ? 'Generating...' : 'Generate'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: isGenerating
                      ? null
                      : () {
                          controller.clear();
                        },
                  icon: const Icon(Icons.clear_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({required this.response, required this.isGenerating});

  final String response;
  final bool isGenerating;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Assistant output',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (isGenerating)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (!isGenerating && response.isEmpty)
              Text(
                'Type a prompt above and press Generate. This demo runs offline.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              SelectableText(
                response.isEmpty ? 'Generating...' : response,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  const _InsightPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _RouteStep extends StatelessWidget {
  const _RouteStep({required this.index, required this.hotspot});

  final int index;
  final Hotspot hotspot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, child: Text('$index')),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotspot.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${hotspot.routeMinutes} min • ${hotspot.routeCost} route • ${hotspot.distanceKm.toStringAsFixed(1)} km • ${hotspot.crowd} crowd',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryChip extends StatelessWidget {
  const _MemoryChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $count'),
      avatar: const Icon(Icons.insights_outlined),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }
}
