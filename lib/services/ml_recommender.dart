import 'dart:math';

import '../domain/hotspot.dart';
import '../domain/trip_preferences.dart';

/// Offline “ML-style” recommender.
///
/// Architecture:
/// - Vectorization: map preference categories to a fixed-length vector.
/// - Candidate scoring: cosine similarity + day-fit + small category priors.
///
/// This is intentionally train-ready: weights live in [MlRecommenderConfig].
class MlRecommenderConfig {
  final double similarityWeight;
  final double dayFitWeight;
  final Map<InterestCategory, double> categoryPriors;

  const MlRecommenderConfig({
    required this.similarityWeight,
    required this.dayFitWeight,
    required this.categoryPriors,
  });

  static const defaultConfig = MlRecommenderConfig(
    similarityWeight: 0.75,
    dayFitWeight: 0.25,
    categoryPriors: {
      InterestCategory.food: 1.0,
      InterestCategory.culture: 1.0,
      InterestCategory.history: 0.95,
      InterestCategory.nature: 0.9,
      InterestCategory.nightlife: 0.85,
      InterestCategory.shopping: 0.8,
      InterestCategory.views: 0.9,
      InterestCategory.adventure: 0.85,
      InterestCategory.romantic: 0.8,
      InterestCategory.family: 0.85,
    },
  );
}

class MlRecommender {
  final MlRecommenderConfig config;

  const MlRecommender({this.config = MlRecommenderConfig.defaultConfig});

  /// Returns ranked hotspots (top-k).
  List<Hotspot> recommend({required TripPreferences prefs, required int topK}) {
    final prefVec = _toVector(prefs.categories);

    final candidates = _candidateHotspotsFor(prefs.destination);

    final scored = <Hotspot>[];
    for (final c in candidates) {
      final candVec = _oneHotVector(c.category);
      final similarity = _cosine(prefVec, candVec);

      // day-fit: more days -> allow a wider variety; fewer days -> bias toward
      // high-confidence categories.
      final dayFactor = _dayFit(prefs.days, c.category);

      final prior = config.categoryPriors[c.category] ?? 1.0;
      final affinity =
          (similarity * config.similarityWeight +
              dayFactor * config.dayFitWeight) *
          prior;
      final interestScore = (affinity * 100).clamp(0, 100).round();
      final hiddenGemScore = _hiddenGemScore(
        interestScore: interestScore,
        rating: c.rating,
        popularity: c.popularity,
      );
      final crowdScore = _crowdScore(c.crowdLevel);
      final budgetScore = _budgetScore(prefs.budgetTier, c.costTier);
      final distanceScore = _distanceScore(c.distanceKm);
      final weatherScore = c.indoorFriendly ? 92 : 76;
      final matchScore = _weightedAverage([
        MapEntry(interestScore, 0.36),
        MapEntry(hiddenGemScore, 0.2),
        MapEntry(crowdScore, 0.14),
        MapEntry(budgetScore, 0.12),
        MapEntry(distanceScore, 0.1),
        MapEntry(weatherScore, 0.08),
      ]);

      final why = _explainMatch(prefs, c.category);

      scored.add(
        Hotspot(
          name: c.name,
          category: c.category,
          matchScore: matchScore,
          hiddenGemScore: hiddenGemScore,
          crowdScore: crowdScore,
          budgetScore: budgetScore,
          distanceScore: distanceScore,
          weatherScore: weatherScore,
          distanceKm: c.distanceKm,
          routeMinutes: _routeMinutes(c.distanceKm),
          routeCost: _routeCost(c.costTier, c.distanceKm),
          cost: c.costLabel,
          bestTime: c.bestTime,
          crowd: c.crowdLevel,
          whyMatched: why,
        ),
      );
    }

    scored.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return scored.take(topK).toList();
  }

  List<_CandidateHotspot> _candidateHotspotsFor(String destination) {
    // Small offline POI set by destination.
    // This is a seed dataset: later we can replace with scraped/Places API data.
    final d = destination.toLowerCase();

    String norm(String s) => s;

    if (d.contains('tokyo')) {
      return [
        _CandidateHotspot(
          norm('Yanaka Ginza snack street'),
          InterestCategory.food,
          rating: 4.6,
          popularity: 0.45,
          distanceKm: 1.2,
          costTier: 1,
          costLabel: '¥800-1500',
          bestTime: '10 AM',
          crowdLevel: 'Medium',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Tsukiji Outer Market'),
          InterestCategory.food,
          rating: 4.5,
          popularity: 0.78,
          distanceKm: 3.8,
          costTier: 2,
          costLabel: '¥1500-3000',
          bestTime: '8 AM',
          crowdLevel: 'High',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Kagurazaka backstreets'),
          InterestCategory.culture,
          rating: 4.5,
          popularity: 0.38,
          distanceKm: 2.4,
          costTier: 1,
          costLabel: 'Free-¥1200',
          bestTime: '4 PM',
          crowdLevel: 'Low',
          indoorFriendly: true,
        ),
        _CandidateHotspot(
          norm('Senso-ji & Asakusa'),
          InterestCategory.history,
          rating: 4.6,
          popularity: 0.86,
          distanceKm: 5.1,
          costTier: 1,
          costLabel: 'Free',
          bestTime: '7 AM',
          crowdLevel: 'High',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Ochanomizu guitar street'),
          InterestCategory.shopping,
          rating: 4.4,
          popularity: 0.34,
          distanceKm: 1.9,
          costTier: 1,
          costLabel: 'Free browsing',
          bestTime: '2 PM',
          crowdLevel: 'Low',
          indoorFriendly: true,
        ),
        _CandidateHotspot(
          norm('Tokyo Metropolitan Gov. view deck'),
          InterestCategory.views,
          rating: 4.5,
          popularity: 0.52,
          distanceKm: 4.5,
          costTier: 1,
          costLabel: 'Free',
          bestTime: 'Sunset',
          crowdLevel: 'Medium',
          indoorFriendly: true,
        ),
        _CandidateHotspot(
          norm('Golden Gai early-evening lanes'),
          InterestCategory.nightlife,
          rating: 4.4,
          popularity: 0.7,
          distanceKm: 3.2,
          costTier: 3,
          costLabel: '¥2500+',
          bestTime: '7 PM',
          crowdLevel: 'High',
          indoorFriendly: true,
        ),
        _CandidateHotspot(
          norm('Meiji Jingu forest walk'),
          InterestCategory.adventure,
          rating: 4.6,
          popularity: 0.66,
          distanceKm: 2.7,
          costTier: 1,
          costLabel: 'Free',
          bestTime: '9 AM',
          crowdLevel: 'Medium',
          indoorFriendly: false,
        ),
      ];
    }

    if (d.contains('paris')) {
      return [
        _CandidateHotspot(
          norm('Rue des Martyrs tasting walk'),
          InterestCategory.food,
          rating: 4.6,
          popularity: 0.46,
          distanceKm: 1.4,
          costTier: 2,
          costLabel: '€12-25',
          bestTime: '11 AM',
          crowdLevel: 'Medium',
          indoorFriendly: true,
        ),
        _CandidateHotspot(
          norm('Le Marais hidden courtyards'),
          InterestCategory.culture,
          rating: 4.5,
          popularity: 0.4,
          distanceKm: 1.8,
          costTier: 1,
          costLabel: 'Free',
          bestTime: '3 PM',
          crowdLevel: 'Low',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Galerie Vivienne passage'),
          InterestCategory.shopping,
          rating: 4.5,
          popularity: 0.42,
          distanceKm: 1.1,
          costTier: 1,
          costLabel: 'Free browsing',
          bestTime: '2 PM',
          crowdLevel: 'Low',
          indoorFriendly: true,
        ),
        _CandidateHotspot(
          norm('Eiffel Tower views'),
          InterestCategory.views,
          rating: 4.6,
          popularity: 0.95,
          distanceKm: 4.2,
          costTier: 1,
          costLabel: 'Free viewpoint',
          bestTime: 'Sunset',
          crowdLevel: 'High',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Montmartre + Sacre-Coeur'),
          InterestCategory.history,
          rating: 4.7,
          popularity: 0.82,
          distanceKm: 3.5,
          costTier: 1,
          costLabel: 'Free',
          bestTime: '8 AM',
          crowdLevel: 'High',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Seine sunset walk'),
          InterestCategory.romantic,
          rating: 4.7,
          popularity: 0.72,
          distanceKm: 1.6,
          costTier: 1,
          costLabel: 'Free',
          bestTime: 'Sunset',
          crowdLevel: 'Medium',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Canal Saint-Martin small bars'),
          InterestCategory.nightlife,
          rating: 4.4,
          popularity: 0.5,
          distanceKm: 2.6,
          costTier: 3,
          costLabel: '€20+',
          bestTime: '8 PM',
          crowdLevel: 'Medium',
          indoorFriendly: true,
        ),
        _CandidateHotspot(
          norm('Luxembourg Gardens'),
          InterestCategory.nature,
          rating: 4.7,
          popularity: 0.7,
          distanceKm: 2.1,
          costTier: 1,
          costLabel: 'Free',
          bestTime: '9 AM',
          crowdLevel: 'Medium',
          indoorFriendly: false,
        ),
      ];
    }

    if (d.contains('rome')) {
      return [
        _CandidateHotspot(
          norm('Testaccio market lunch'),
          InterestCategory.food,
          rating: 4.6,
          popularity: 0.44,
          distanceKm: 2.2,
          costTier: 2,
          costLabel: '€10-20',
          bestTime: '12 PM',
          crowdLevel: 'Medium',
          indoorFriendly: true,
        ),
        _CandidateHotspot(
          norm('Aventine keyhole + quiet streets'),
          InterestCategory.views,
          rating: 4.5,
          popularity: 0.36,
          distanceKm: 1.7,
          costTier: 1,
          costLabel: 'Free',
          bestTime: '8 AM',
          crowdLevel: 'Low',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Colosseum area'),
          InterestCategory.history,
          rating: 4.7,
          popularity: 0.93,
          distanceKm: 2.8,
          costTier: 3,
          costLabel: '€18+',
          bestTime: '8 AM',
          crowdLevel: 'High',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Trastevere food lanes'),
          InterestCategory.food,
          rating: 4.6,
          popularity: 0.68,
          distanceKm: 2.5,
          costTier: 2,
          costLabel: '€12-24',
          bestTime: '6 PM',
          crowdLevel: 'High',
          indoorFriendly: true,
        ),
        _CandidateHotspot(
          norm('Vatican Museums vibe'),
          InterestCategory.culture,
          rating: 4.7,
          popularity: 0.88,
          distanceKm: 4.2,
          costTier: 3,
          costLabel: '€20+',
          bestTime: '9 AM',
          crowdLevel: 'High',
          indoorFriendly: true,
        ),
        _CandidateHotspot(
          norm('Campo de Fiori market'),
          InterestCategory.shopping,
          rating: 4.3,
          popularity: 0.58,
          distanceKm: 1.3,
          costTier: 1,
          costLabel: 'Free browsing',
          bestTime: '10 AM',
          crowdLevel: 'Medium',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Tiber riverside walk'),
          InterestCategory.romantic,
          rating: 4.4,
          popularity: 0.4,
          distanceKm: 1.4,
          costTier: 1,
          costLabel: 'Free',
          bestTime: 'Sunset',
          crowdLevel: 'Low',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Testaccio nightlife'),
          InterestCategory.nightlife,
          rating: 4.3,
          popularity: 0.48,
          distanceKm: 2.6,
          costTier: 3,
          costLabel: '€20+',
          bestTime: '9 PM',
          crowdLevel: 'Medium',
          indoorFriendly: true,
        ),
      ];
    }

    if (d.contains('chennai')) {
      return [
        _CandidateHotspot(
          norm('Besant Nagar food street'),
          InterestCategory.food,
          rating: 4.5,
          popularity: 0.52,
          distanceKm: 2.0,
          costTier: 1,
          costLabel: 'Rs.150-350',
          bestTime: '6 PM',
          crowdLevel: 'Medium',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Broken Bridge sunset point'),
          InterestCategory.views,
          rating: 4.4,
          popularity: 0.38,
          distanceKm: 2.7,
          costTier: 1,
          costLabel: 'Free',
          bestTime: 'Sunset',
          crowdLevel: 'Low',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Mylapore heritage walk'),
          InterestCategory.history,
          rating: 4.6,
          popularity: 0.42,
          distanceKm: 3.2,
          costTier: 1,
          costLabel: 'Free-Rs.200',
          bestTime: '7 AM',
          crowdLevel: 'Low',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Cholamandal Artists Village'),
          InterestCategory.culture,
          rating: 4.5,
          popularity: 0.35,
          distanceKm: 4.8,
          costTier: 2,
          costLabel: 'Rs.50-150',
          bestTime: '3 PM',
          crowdLevel: 'Low',
          indoorFriendly: true,
        ),
        _CandidateHotspot(
          norm('Theosophical Society garden walk'),
          InterestCategory.nature,
          rating: 4.5,
          popularity: 0.32,
          distanceKm: 1.8,
          costTier: 1,
          costLabel: 'Free',
          bestTime: '8 AM',
          crowdLevel: 'Low',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Phoenix Marketcity indoor break'),
          InterestCategory.shopping,
          rating: 4.4,
          popularity: 0.76,
          distanceKm: 5.0,
          costTier: 2,
          costLabel: 'Flexible',
          bestTime: '2 PM',
          crowdLevel: 'High',
          indoorFriendly: true,
        ),
        _CandidateHotspot(
          norm('ECR go-karting / adventure stop'),
          InterestCategory.adventure,
          rating: 4.3,
          popularity: 0.45,
          distanceKm: 6.2,
          costTier: 3,
          costLabel: 'Rs.600+',
          bestTime: '5 PM',
          crowdLevel: 'Medium',
          indoorFriendly: false,
        ),
        _CandidateHotspot(
          norm('Alwarpet quiet cafe lane'),
          InterestCategory.romantic,
          rating: 4.4,
          popularity: 0.36,
          distanceKm: 2.3,
          costTier: 2,
          costLabel: 'Rs.300-700',
          bestTime: '4 PM',
          crowdLevel: 'Low',
          indoorFriendly: true,
        ),
      ];
    }

    // Default fallback for unknown destinations.
    return [
      _CandidateHotspot(
        norm('Local Food Market / Street Food'),
        InterestCategory.food,
        rating: 4.5,
        popularity: 0.42,
        distanceKm: 1.1,
        costTier: 1,
        costLabel: 'Low cost',
        bestTime: '11 AM',
        crowdLevel: 'Medium',
        indoorFriendly: true,
      ),
      _CandidateHotspot(
        norm('Quiet Historic Lane'),
        InterestCategory.history,
        rating: 4.4,
        popularity: 0.34,
        distanceKm: 1.6,
        costTier: 1,
        costLabel: 'Free',
        bestTime: '8 AM',
        crowdLevel: 'Low',
        indoorFriendly: false,
      ),
      _CandidateHotspot(
        norm('Rooftop / Sunset Viewpoint'),
        InterestCategory.views,
        rating: 4.6,
        popularity: 0.45,
        distanceKm: 2.1,
        costTier: 2,
        costLabel: 'Moderate',
        bestTime: 'Sunset',
        crowdLevel: 'Medium',
        indoorFriendly: false,
      ),
      _CandidateHotspot(
        norm('Neighborhood Cafes + Culture'),
        InterestCategory.culture,
        rating: 4.5,
        popularity: 0.36,
        distanceKm: 1.3,
        costTier: 2,
        costLabel: 'Moderate',
        bestTime: '3 PM',
        crowdLevel: 'Low',
        indoorFriendly: true,
      ),
      _CandidateHotspot(
        norm('Parks / Scenic Loop'),
        InterestCategory.nature,
        rating: 4.4,
        popularity: 0.46,
        distanceKm: 2.4,
        costTier: 1,
        costLabel: 'Free',
        bestTime: '7 AM',
        crowdLevel: 'Low',
        indoorFriendly: false,
      ),
      _CandidateHotspot(
        norm('Evening Night Lights District'),
        InterestCategory.nightlife,
        rating: 4.3,
        popularity: 0.55,
        distanceKm: 2.7,
        costTier: 3,
        costLabel: 'Higher',
        bestTime: '8 PM',
        crowdLevel: 'High',
        indoorFriendly: true,
      ),
      _CandidateHotspot(
        norm('Shopping Streets / Markets'),
        InterestCategory.shopping,
        rating: 4.3,
        popularity: 0.48,
        distanceKm: 1.8,
        costTier: 1,
        costLabel: 'Flexible',
        bestTime: '4 PM',
        crowdLevel: 'Medium',
        indoorFriendly: true,
      ),
      _CandidateHotspot(
        norm('Guided Experience (optional)'),
        InterestCategory.adventure,
        rating: 4.5,
        popularity: 0.4,
        distanceKm: 3.1,
        costTier: 3,
        costLabel: 'Higher',
        bestTime: '9 AM',
        crowdLevel: 'Medium',
        indoorFriendly: false,
      ),
    ];
  }

  int _hiddenGemScore({
    required int interestScore,
    required double rating,
    required double popularity,
  }) {
    final ratingScore = ((rating - 3.5) / 1.5 * 100).clamp(0, 100);
    final antiPopularity = ((1 - popularity) * 100).clamp(0, 100);
    return _weightedAverage([
      MapEntry(interestScore, 0.38),
      MapEntry(ratingScore.round(), 0.32),
      MapEntry(antiPopularity.round(), 0.3),
    ]);
  }

  int _crowdScore(String crowdLevel) {
    return switch (crowdLevel) {
      'Low' => 94,
      'Medium' => 78,
      'High' => 52,
      _ => 70,
    };
  }

  int _budgetScore(String budgetTier, int costTier) {
    final desiredTier = switch (budgetTier) {
      'budget' => 1,
      'mid' => 2,
      'premium' => 3,
      'any' => costTier,
      _ => 2,
    };
    final gap = (desiredTier - costTier).abs();
    return switch (gap) {
      0 => 94,
      1 => 76,
      _ => 48,
    };
  }

  int _distanceScore(double distanceKm) {
    if (distanceKm <= 1.5) return 95;
    if (distanceKm <= 3) return 82;
    if (distanceKm <= 5) return 68;
    return 54;
  }

  int _routeMinutes(double distanceKm) {
    return (distanceKm * 8 + 6).round();
  }

  String _routeCost(int costTier, double distanceKm) {
    final base = switch (costTier) {
      1 => 40,
      2 => 90,
      _ => 160,
    };
    final estimate = base + (distanceKm * 18).round();
    return 'Rs.$estimate';
  }

  int _weightedAverage(List<MapEntry<int, double>> values) {
    var total = 0.0;
    var weights = 0.0;
    for (final entry in values) {
      total += entry.key * entry.value;
      weights += entry.value;
    }
    if (weights == 0) return 0;
    return (total / weights).clamp(0, 100).round();
  }

  List<double> _toVector(Set<InterestCategory> cats) {
    final all = InterestCategory.values;
    final vec = List<double>.filled(all.length, 0);

    for (final c in cats) {
      final idx = all.indexOf(c);
      if (idx >= 0) vec[idx] = 1.0;
    }

    // If user gave no categories, return a mild uniform vector.
    if (cats.isEmpty) {
      final v = 1.0 / all.length;
      for (var i = 0; i < vec.length; i++) {
        vec[i] = v;
      }
    }

    return vec;
  }

  List<double> _oneHotVector(InterestCategory cat) {
    final all = InterestCategory.values;
    final vec = List<double>.filled(all.length, 0);
    final idx = all.indexOf(cat);
    if (idx >= 0) vec[idx] = 1.0;
    return vec;
  }

  double _cosine(List<double> a, List<double> b) {
    double dot = 0;
    double na = 0;
    double nb = 0;

    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }

    final denom = sqrt(na) * sqrt(nb);
    if (denom == 0) return 0;
    return dot / denom;
  }

  double _dayFit(int days, InterestCategory cat) {
    // Rough heuristic to mimic a “learned” prior.
    // More days = better chance to include variety.
    if (days <= 2) {
      return (cat == InterestCategory.food ||
              cat == InterestCategory.culture ||
              cat == InterestCategory.history)
          ? 1.0
          : 0.6;
    }

    if (days <= 4) {
      return (cat == InterestCategory.nature || cat == InterestCategory.views)
          ? 0.95
          : 0.75;
    }

    return 1.0;
  }

  String _explainMatch(TripPreferences prefs, InterestCategory cat) {
    final cats = prefs.categories;
    final contains = cats.contains(cat);

    if (contains) {
      return 'Matches your preference: ${_label(cat)}.';
    }

    // Soft explainability: infer nearest likely category.
    final dest = prefs.destination;
    return 'Good add-on for $dest: fits the ${_label(cat)} vibe for your trip length.';
  }

  String _label(InterestCategory c) {
    return switch (c) {
      InterestCategory.food => 'food',
      InterestCategory.nightlife => 'nightlife',
      InterestCategory.shopping => 'shopping',
      InterestCategory.nature => 'nature',
      InterestCategory.history => 'history',
      InterestCategory.culture => 'culture',
      InterestCategory.views => 'great views',
      InterestCategory.family => 'family-friendly',
      InterestCategory.romantic => 'romantic',
      InterestCategory.adventure => 'adventure',
    };
  }
}

class _CandidateHotspot {
  final String name;
  final InterestCategory category;
  final double rating;
  final double popularity;
  final double distanceKm;
  final int costTier;
  final String costLabel;
  final String bestTime;
  final String crowdLevel;
  final bool indoorFriendly;

  const _CandidateHotspot(
    this.name,
    this.category, {
    required this.rating,
    required this.popularity,
    required this.distanceKm,
    required this.costTier,
    required this.costLabel,
    required this.bestTime,
    required this.crowdLevel,
    required this.indoorFriendly,
  });
}
