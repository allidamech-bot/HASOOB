import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({
    required this.isConfigured,
    required this.message,
    required this.selectedPlatform,
    required this.webConfigExists,
    this.missingFields = const [],
    this.errorType,
    this.errorMessage,
    this.stackTrace,
    this.configDiagnostics = const {},
  });

  final bool isConfigured;
  final String message;
  final String selectedPlatform;
  final bool webConfigExists;
  final List<String> missingFields;
  final String? errorType;
  final String? errorMessage;
  final String? stackTrace;
  final Map<String, bool> configDiagnostics;
}

class FirebaseBootstrap {
  static Future<FirebaseBootstrapResult> initialize() async {
    final selectedPlatform = DefaultFirebaseOptions.selectedPlatformLabel;
    final webConfigExists = DefaultFirebaseOptions.hasWebConfig;
    debugPrint('[Startup][Firebase] selectedPlatform=$selectedPlatform');
    debugPrint('[Startup][Firebase] webConfigExists=$webConfigExists');

    Object? selectedOptions;
    try {
      selectedOptions = DefaultFirebaseOptions.currentPlatform;
    } catch (e, st) {
      debugPrint('[Startup][Firebase] currentPlatform failed: $e');
      return FirebaseBootstrapResult(
        isConfigured: false,
        message: 'Firebase initialization failed: currentPlatform error',
        selectedPlatform: selectedPlatform,
        webConfigExists: webConfigExists,
        missingFields: const ['FirebaseOptions.currentPlatform'],
        errorType: e.runtimeType.toString(),
        errorMessage: e.toString(),
        stackTrace: st.toString(),
      );
    }

    final missingFields = DefaultFirebaseOptions.missingRequiredFields(selectedOptions);
    _logMissingFields(missingFields);

    final configDiagnostics = _captureConfigDiagnostics(selectedOptions);

    if (missingFields.isNotEmpty) {
      return FirebaseBootstrapResult(
        isConfigured: false,
        message: 'Firebase initialization skipped: missing required fields',
        selectedPlatform: selectedPlatform,
        webConfigExists: webConfigExists,
        missingFields: missingFields,
        configDiagnostics: configDiagnostics,
      );
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: selectedOptions as FirebaseOptions,
        );
      }

      return FirebaseBootstrapResult(
        isConfigured: true,
        message: '',
        selectedPlatform: selectedPlatform,
        webConfigExists: webConfigExists,
        configDiagnostics: configDiagnostics,
      );
    } on FirebaseException catch (e, st) {
      if (e.code == 'duplicate-app') {
        return FirebaseBootstrapResult(
          isConfigured: true,
          message: '',
          selectedPlatform: selectedPlatform,
          webConfigExists: webConfigExists,
          configDiagnostics: configDiagnostics,
        );
      }

      _logFailure(selectedPlatform, e, st, configDiagnostics);

      return FirebaseBootstrapResult(
        isConfigured: false,
        message: 'Firebase initialization failed: ${e.message ?? e.code}',
        selectedPlatform: selectedPlatform,
        webConfigExists: webConfigExists,
        missingFields: missingFields,
        errorType: 'FirebaseException(${e.code})',
        errorMessage: e.message,
        stackTrace: st.toString(),
        configDiagnostics: configDiagnostics,
      );
    } catch (e, st) {
      _logFailure(selectedPlatform, e, st, configDiagnostics);

      return FirebaseBootstrapResult(
        isConfigured: false,
        message: 'Firebase initialization failed: $e',
        selectedPlatform: selectedPlatform,
        webConfigExists: webConfigExists,
        missingFields: missingFields,
        errorType: e.runtimeType.toString(),
        errorMessage: e.toString(),
        stackTrace: st.toString(),
        configDiagnostics: configDiagnostics,
      );
    }
  }

  static Map<String, bool> _captureConfigDiagnostics(Object? options) {
    if (options == null) return {};
    final fields = [
      'apiKey',
      'appId',
      'projectId',
      'messagingSenderId',
      'authDomain',
    ];
    final diagnostics = <String, bool>{};
    for (final field in fields) {
      final value = DefaultFirebaseOptions.readStringField(options, field);
      diagnostics[field] = value != null && value.trim().isNotEmpty;
    }
    return diagnostics;
  }

  static void _logFailure(
    String platform,
    Object error,
    StackTrace st,
    Map<String, bool> diagnostics,
  ) {
    debugPrint('[Startup][Firebase] FATAL: $error');
    debugPrint('[Startup][Firebase] Platform: $platform');
    diagnostics.forEach((key, present) {
      debugPrint('[Startup][Firebase] Config: $key present=$present');
    });
    debugPrint('[Startup][Firebase] RuntimeType: ${error.runtimeType}');
    debugPrint('[Startup][Firebase] StackTrace:\n$st');
  }

  static void _logMissingFields(List<String> missingFields) {
    if (missingFields.isEmpty) {
      debugPrint('[Startup][Firebase] missingFields=none');
      return;
    }
    for (final field in missingFields) {
      debugPrint('[Startup][Firebase] nullOrEmptyField=$field');
    }
  }
}

