import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/presentation/screens/ai_accountant_screen.dart';

void main() {
  testWidgets('AI CFO beta workspace renders label, guidance, and input',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiAccountantScreen(workspaceMode: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('AI CFO Beta'), findsOneWidget);
    expect(
        find.textContaining('Add invoices, customers, products'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
  });
}
