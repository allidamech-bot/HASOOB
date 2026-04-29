import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Minimal smoke test', (WidgetTester tester) async {
    // Build a simple widget to verify test environment works.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('HASOOB'),
        ),
      ),
    );

    // Verify that the text appears.
    expect(find.text('HASOOB'), findsOneWidget);
  });
}
