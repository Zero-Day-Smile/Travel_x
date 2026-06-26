// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:travel_x/main.dart';

void main() {
  testWidgets('Dravik Explore AI smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TravelAiApp());

    // Verify that the basic UI is present.
    expect(find.text('Dravik Explore AI'), findsWidgets);
    expect(find.text('Describe your trip'), findsOneWidget);
    expect(find.text('Generate'), findsOneWidget);
  });
}
