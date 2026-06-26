import 'trip_preferences.dart';

class Hotspot {
  final String name;
  final InterestCategory category;
  final int matchScore;
  final int hiddenGemScore;
  final int crowdScore;
  final int budgetScore;
  final int distanceScore;
  final int weatherScore;
  final double distanceKm;
  final int routeMinutes;
  final String routeCost;
  final String cost;
  final String bestTime;
  final String crowd;
  final String whyMatched;

  const Hotspot({
    required this.name,
    required this.category,
    required this.matchScore,
    required this.hiddenGemScore,
    required this.crowdScore,
    required this.budgetScore,
    required this.distanceScore,
    required this.weatherScore,
    required this.distanceKm,
    required this.routeMinutes,
    required this.routeCost,
    required this.cost,
    required this.bestTime,
    required this.crowd,
    required this.whyMatched,
  });
}
