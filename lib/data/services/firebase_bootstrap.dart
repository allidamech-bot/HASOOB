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
  });

  final bool isConfigured;
  final String message;
  final String selectedPlatform;
  final bool webConfigExists;
  final List<String> missingFields;
}

class FirebaseBootstrap {
  static Future<FirebaseBootstrapResult> initialize() async {
    final selectedPlatform = DefaultFirebaseOptions.selectedPlatformLabel;
    final webConfigExists = DefaultFirebaseOptions.hasWebConfig;
    debugPrint('[Startup][Firebase] selectedPlatform=$selectedPlatform');
    debugPrint('[Startup][Firebase] webConfigExists=$webConfigExists');

    final Object? selectedOptions;
    try {
      selectedOptions = DefaultFirebaseOptions.currentPlatform;
    } catch (e) {
      debugPrint('[Startup][Firebase] currentPlatform failed: $e');
      return FirebaseBootstrapResult(
        isConfigured: false,
        message: 'Firebase initialization failed.\n\n'
            'Selected platform: $selectedPlatform\n'
            'Web config exists: $webConfigExists\n'
            'Missing Firebase config field(s): FirebaseOptions.currentPlatform\n'
            'Error: $e',
        selectedPlatform: selectedPlatform,
        webConfigExists: webConfigExists,
        missingFields: const ['FirebaseOptions.currentPlatform'],
      );
    }

    final missingFields = DefaultFirebaseOptions.missingRequiredFields(selectedOptions);
    _logMissingFields(missingFields);
    if (missingFields.isNotEmpty) {
      return FirebaseBootstrapResult(
        isConfigured: false,
        message: 'Firebase initialization skipped.\n\n'
            'Selected platform: $selectedPlatform\n'
            'Web config exists: $webConfigExists\n'
            'Missing Firebase config field(s): ${missingFields.join(', ')}',
        selectedPlatform: selectedPlatform,
        webConfigExists: webConfigExists,
        missingFields: missingFields,
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
      );
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        return FirebaseBootstrapResult(
          isConfigured: true,
          message: '',
          selectedPlatform: selectedPlatform,
          webConfigExists: webConfigExists,
        );
      }

      return FirebaseBootstrapResult(
        isConfigured: false,
        message: _failureMessage(
          selectedPlatform: selectedPlatform,
          webConfigExists: webConfigExists,
          missingFields: missingFields,
          error: e.message ?? e.code,
        ),
        selectedPlatform: selectedPlatform,
        webConfigExists: webConfigExists,
        missingFields: missingFields,
      );
    } catch (e) {
      return FirebaseBootstrapResult(
        isConfigured: false,
        message: _failureMessage(
          selectedPlatform: selectedPlatform,
          webConfigExists: webConfigExists,
          missingFields: missingFields,
          error: e,
        ),
        selectedPlatform: selectedPlatform,
        webConfigExists: webConfigExists,
        missingFields: missingFields,
      );
    }
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

  static String _failureMessage({
    required String selectedPlatform,
    required bool webConfigExists,
    required List<String> missingFields,
    required Object error,
  }) {
    return 'Firebase initialization failed.\n\n'
        'Selected platform: $selectedPlatform\n'
        'Web config exists: $webConfigExists\n'
        'Missing Firebase config field(s): ${missingFields.isEmpty ? 'none' : missingFields.join(', ')}\n'
        'Error: $error';
  }
}
