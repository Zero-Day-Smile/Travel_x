import '../domain/trip_preferences.dart';

class ReelsQueryBuilder {
  const ReelsQueryBuilder();

  /// Returns web links (search URLs). No scraping from the app.
  List<ReelsLink> build({
    required String destination,
    required Set<InterestCategory> categories,
    required int maxLinks,
  }) {
    final cats = categories.isEmpty
        ? InterestCategory.values.toSet()
        : categories;
    final picked = cats.take(maxLinks).toList();

    return picked.map((c) {
      final q = '$destination ${_label(c)} reels';
      final yt =
          'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(q)}';
      return ReelsLink(
        category: c,
        title: '${_label(c).toUpperCase()} reels',
        url: yt,
      );
    }).toList();
  }

  String _label(InterestCategory c) {
    return switch (c) {
      InterestCategory.food => 'food',
      InterestCategory.nightlife => 'nightlife',
      InterestCategory.shopping => 'shopping',
      InterestCategory.nature => 'nature',
      InterestCategory.history => 'history',
      InterestCategory.culture => 'culture',
      InterestCategory.views => 'views',
      InterestCategory.family => 'family',
      InterestCategory.romantic => 'romantic',
      InterestCategory.adventure => 'adventure',
    };
  }
}

class ReelsLink {
  final InterestCategory category;
  final String title;
  final String url;

  const ReelsLink({
    required this.category,
    required this.title,
    required this.url,
  });
}
