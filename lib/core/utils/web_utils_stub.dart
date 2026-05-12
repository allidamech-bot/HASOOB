class WebUtils {
  static void logDiagnostic(String message) {}
  static void removeSplash() {}
  static String browserHint() => 'Platform: native';
  static bool isStartupDebugEnabled() => false;
  static void registerSyncLifecycleHook(void Function(String eventName) onEvent) {}
  static void unregisterSyncLifecycleHook() {}
}
