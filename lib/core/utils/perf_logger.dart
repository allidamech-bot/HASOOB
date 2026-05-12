import 'package:flutter/foundation.dart';

class PerfLogger {
  static void logPageOpen(String pageName) {
    if (kDebugMode) {
      debugPrint('[PERF] $pageName: Page Open at ${DateTime.now().toIso8601String()}');
    }
  }

  static void logFirstRender(String pageName) {
    if (kDebugMode) {
      debugPrint('[PERF] $pageName: First Render at ${DateTime.now().toIso8601String()}');
    }
  }

  static void logDataLoaded(String pageName) {
    if (kDebugMode) {
      debugPrint('[PERF] $pageName: Data Loaded at ${DateTime.now().toIso8601String()}');
    }
  }
}
