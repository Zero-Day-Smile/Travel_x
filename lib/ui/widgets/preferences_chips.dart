import 'package:flutter/material.dart';

import '../../domain/trip_preferences.dart';

class PreferencesChips extends StatelessWidget {
  final Set<InterestCategory> categories;

  const PreferencesChips({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    final cats = categories.isEmpty ? <InterestCategory>{} : categories;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in cats)
          Chip(
            label: Text(_label(c)),
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          ),
      ],
    );
  }

  String _label(InterestCategory c) {
    return switch (c) {
      InterestCategory.food => 'Food',
      InterestCategory.nightlife => 'Nightlife',
      InterestCategory.shopping => 'Shopping',
      InterestCategory.nature => 'Nature',
      InterestCategory.history => 'History',
      InterestCategory.culture => 'Culture',
      InterestCategory.views => 'Views',
      InterestCategory.family => 'Family',
      InterestCategory.romantic => 'Romantic',
      InterestCategory.adventure => 'Adventure',
    };
  }
}
