import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/features/ai_accountant/presentation/screens/ai_accountant_screen.dart';

void main() {
  testWidgets('AI CFO beta workspace renders label, guidance, and input',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiAccountantScreen(workspaceMode: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI CFO Beta'), findsOneWidget);
    expect(
        find.textContaining('Add invoices, customers, products'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
  });
}