class TripPreferences {
  final String destination;
  final Set<InterestCategory> categories;
  final int days;
  final String budgetTier;

  const TripPreferences({
    required this.destination,
    required this.categories,
    required this.days,
    required this.budgetTier,
  });

  static const allCategories = InterestCategory.values;
}

enum InterestCategory {
  food,
  nightlife,
  shopping,
  nature,
  history,
  culture,
  views,
  family,
  romantic,
  adventure,
}
