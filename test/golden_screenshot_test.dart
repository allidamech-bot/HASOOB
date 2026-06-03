import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/widgets/premium_splash_screen.dart';

void main() {
  testWidgets('Generate Screenshots', (WidgetTester tester) async {
    // We will render the widget and capture it using the golden file mechanism
    
    // 1. Desktop Size
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: PremiumSplashScreen()),
      ),
    );
    // Allow animations to progress to a visible state
    await tester.pump(const Duration(milliseconds: 800));
    
    await expectLater(
      find.byType(PremiumSplashScreen),
      matchesGoldenFile('goldens/desktop_entrance_screenshot.png'),
    );

    // 2. Mobile Size
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: PremiumSplashScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    
    await expectLater(
      find.byType(PremiumSplashScreen),
      matchesGoldenFile('goldens/mobile_entrance_screenshot.png'),
    );
    
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, skip: Platform.environment.containsKey('GITHUB_ACTIONS'));
}
