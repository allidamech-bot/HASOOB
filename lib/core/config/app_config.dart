class AppConfig {
  static const bool isTestingMode = bool.fromEnvironment(
    'HASOOB_USE_MOCK_REPOSITORIES',
    defaultValue: false,
  );

  static const String appName = "HASOOB";
  static const String appVersion = "1.0.0";
}
