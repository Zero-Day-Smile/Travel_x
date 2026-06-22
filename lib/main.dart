import 'package:flutter/material.dart';

void main() {
  runApp(const TravelAiApp());
}

class TravelAiApp extends StatelessWidget {
  const TravelAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const TravelAssistantHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TravelAssistantHome extends StatefulWidget {
  const TravelAssistantHome({super.key});

  @override
  State<TravelAssistantHome> createState() => _TravelAssistantHomeState();
}

class _TravelAssistantHomeState extends State<TravelAssistantHome> {
  final _promptController = TextEditingController();
  bool _isGenerating = false;
  String _response = "";

  // Basic “AI assistant” flow (no external API). Generates deterministic suggestions
  // based on keywords.
  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _response = "";
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));

    final lower = prompt.toLowerCase();
    final destination = _extractDestination(prompt) ?? 'your destination';

    final tone = _extractTone(lower);
    final tripType = _extractTripType(lower);
    final budget = _extractBudget(lower);
    final days = _extractDays(lower);

    final itinerary = _buildItinerary(
      destination: destination,
      tripType: tripType,
      days: days,
      budget: budget,
    );

    final tips = _buildPackingTips(lower);

    final answer = [
      'Here’s a quick plan for $destination ($days days) — $tone.',
      '',
      'Day-by-day itinerary:',
      for (final day in itinerary) '• $day',
      '',
      'Top recommendations:',
      '• Food idea: try local street food/market tasting',
      '• Best time to visit: aim for morning for sights, sunset for views',
      '• Photo spots: pick 2–3 viewpoints and revisit at different times',
      '',
      'Budget notes:',
      budget,
      '',
      'Packing & practical tips:',
      for (final t in tips) '• $t',
      '',
      'If you share your dates, travel style (relaxed vs packed), and interests, I can refine this.'
    ].join('\n');

    // “Streaming-like” effect.
    const chunkSize = 45;
    for (var i = 0; i < answer.length; i += chunkSize) {
      setState(() {
        _response = answer.substring(0, i + chunkSize > answer.length ? answer.length : i + chunkSize);
      });
      await Future<void>.delayed(const Duration(milliseconds: 18));
    }

    setState(() {
      _isGenerating = false;
    });
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
      'vienna',
      'cape town',
      'sydney',
      'melbourne',
    ];

    for (final c in candidates) {
      if (lower.contains(c)) return c;
    }

    // Heuristic: if prompt contains “to X” or “in X”.
    final toMatch = RegExp(r'\bto\s+([a-zA-Z][a-zA-Z\s-]{2,30})').firstMatch(prompt);
    if (toMatch != null) {
      final raw = toMatch.group(1)!.trim();
      return raw.replaceAll(RegExp(r'[^a-zA-Z\s-]'), '').trim();
    }

    final inMatch = RegExp(r'\bin\s+([a-zA-Z][a-zA-Z\s-]{2,30})').firstMatch(prompt);
    if (inMatch != null) {
      final raw = inMatch.group(1)!.trim();
      return raw.replaceAll(RegExp(r'[^a-zA-Z\s-]'), '').trim();
    }

    return null;
  }

  String _extractTone(String lower) {
    if (lower.contains('budget') || lower.contains('cheap') || lower.contains('affordable')) {
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
    if (lower.contains('adventure') || lower.contains('hike') || lower.contains('outdoor')) {
      return 'adventure-focused';
    }
    if (lower.contains('relaxed') || lower.contains('slow') || lower.contains('easy')) {
      return 'relaxed';
    }
    return 'balanced';
  }

  String _extractTripType(String lower) {
    if (lower.contains('food') || lower.contains('cafe') || lower.contains('restaurant')) {
      return 'food & culture';
    }
    if (lower.contains('nature') || lower.contains('hike') || lower.contains('beach')) {
      return 'nature & views';
    }
    if (lower.contains('shopping')) {
      return 'shopping & neighborhoods';
    }
    if (lower.contains('history') || lower.contains('museum') || lower.contains('ancient')) {
      return 'history & museums';
    }
    if (lower.contains('nightlife') || lower.contains('club') || lower.contains('bars')) {
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

    if (lower.contains('budget') || lower.contains('cheap') || lower.contains('affordable')) {
      return 'Prioritize walkable areas, free museums, and local markets. Book only the top 1–2 attractions ahead.';
    }

    if (lower.contains('luxury') || lower.contains('premium')) {
      return 'Plan one signature experience per day. Consider guided tours to save time and skip lines.';
    }

    return 'Keep it flexible: 1–2 paid activities/day, and build your days around neighborhoods.';
  }

  int _extractDays(String lower) {
    // Examples: "3 days", "for 7d", "weekend".
    final weekend = lower.contains('weekend');
    if (weekend) return 2;

    final match = RegExp(r'(\d{1,2})\s*(day|days|d)\b').firstMatch(lower);
    if (match != null) {
      return int.parse(match.group(1)!);
    }

    // “a week”, “5 days” etc.
    if (lower.contains('a week') || lower.contains('week')) return 7;

    return 4; // default
  }

  List<String> _buildPackingTips(String lower) {
    final List<String> tips = [];
    tips.add('Bring a reusable water bottle and a small day bag.');
    tips.add('Pack comfortable walking shoes — most itineraries are step-heavy.');

    if (lower.contains('rain') || lower.contains('wet') || lower.contains('storm')) {
      tips.add('Add a compact umbrella or lightweight rain jacket.');
    } else {
      tips.add('Include sunscreen and a hat for midday sun.');
    }

    if (lower.contains('winter') || lower.contains('snow') || lower.contains('cold')) {
      tips.add('Layering: base + warm mid + windproof outer layer.');
    } else if (lower.contains('summer') || lower.contains('hot') || lower.contains('warm')) {
      tips.add('Lightweight breathable clothes, plus a quick-dry option.');
    }

    if (lower.contains('international') || lower.contains('passport') || lower.contains('visa') || lower.contains('country')) {
      tips.add('Keep passport/ID and travel docs in an easy-access pouch.');
    }

    tips.add('Carry offline maps/screenshots for areas with weak signal.');

    // Keep it short for “basic frontend” request.
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
          'Day $d: Arrive + check-in; do an easy “orientation walk” and a local dinner nearby ($tripType).',
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
        out.add('Day $d: Morning sights ($focus), afternoon flexible time, evening local experience.');
      }
    }
    return out;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                            Expanded(
                              flex: 5,
                              child: _buildLeft(context),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 4,
                              child: _buildRight(context),
                            ),
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
        _ResponseCard(
          response: _response,
          isGenerating: _isGenerating,
        ),
      ],
    );
  }

  Widget _buildRight(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Try prompts',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _PromptChip(
              label: '3 days in Paris',
              onTap: () => setState(() => _promptController.text = 'Plan a 3-day trip to Paris for first-time visitors.'),
            ),
            _PromptChip(
              label: 'Tokyo food + culture',
              onTap: () => setState(() => _promptController.text = 'I want a Tokyo itinerary focused on food and culture. 5 days, mid budget.'),
            ),
            _PromptChip(
              label: 'Romantic weekend',
              onTap: () => setState(() => _promptController.text = 'Plan a romantic weekend in London for 2 days.'),
            ),
            _PromptChip(
              label: 'Budget road trip',
              onTap: () => setState(() => _promptController.text = 'Budget road trip: 4 days with day trips, keep it affordable.'),
            ),
            _PromptChip(
              label: 'Adventure + nature',
              onTap: () => setState(() => _promptController.text = 'Adventure-focused trip with hiking/beach time for 4 days.'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'How it works',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _InfoList(
          items: const [
            'Type what you want (destination, days, budget, vibe).',
            'Press Generate to get a basic itinerary.',
            'Refine by adding dates or preferences.',
          ],
        ),
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
          child: const Icon(
            Icons.airplanemode_active_rounded,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Travel AI',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Your simple travel assistant (offline demo UI).',
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
                hintText: 'Example: Plan 4 days in Tokyo for a budget-friendly food tour',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'Quick fill',
                  onPressed: isGenerating
                      ? null
                      : () => onQuickFill('Plan a 4-day trip to Tokyo focused on food and neighborhoods. Mid budget. Keep it practical.'),
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
                    label: Text(isGenerating ? 'Generating...' : 'Generate itinerary'),
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
  const _ResponseCard({
    required this.response,
    required this.isGenerating,
  });

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
                if (isGenerating) const SizedBox(width: 10),
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
                'Type a prompt above and press Generate. This demo runs locally without calling any AI API.',
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

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }
}

class _InfoList extends StatelessWidget {
  const _InfoList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}

