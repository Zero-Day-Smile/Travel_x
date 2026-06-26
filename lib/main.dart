import 'package:flutter/material.dart';

import 'ui/travel_assistant_home.dart';

void main() {
  runApp(const TravelAiApp());
}

class TravelAiApp extends StatelessWidget {
  const TravelAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dravik Explore AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const TravelAssistantHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}
