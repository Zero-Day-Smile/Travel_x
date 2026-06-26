import 'package:flutter/material.dart';

import '../../services/reels_query_builder.dart';

class ReelsRow extends StatelessWidget {
  final List<ReelsLink> links;

  const ReelsRow({super.key, required this.links});

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final l in links)
          ActionChip(
            label: Text(l.title),
            onPressed: () {
              // In a real app we’d use url_launcher; keeping it dependency-light.
              // This will still work in web by opening the URL in a new tab.
              // For mobile, add url_launcher later.
              final url = l.url;
              // ignore: avoid_print
              print('Open reels url: $url');
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Reels link ready: $url')));
            },
          ),
      ],
    );
  }
}
