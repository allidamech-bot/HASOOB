import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    return web;
  }

  static String get selectedPlatformLabel {
    if (kIsWeb) {
      return 'web';
    }
    return defaultTargetPlatform.name;
  }

  static bool get hasWebConfig => missingRequiredFields(web).isEmpty;

  static List<String> missingRequiredFields(Object? options) {
    if (options == null) {
      return const ['FirebaseOptions.currentPlatform'];
    }

    final missing = <String>[];
    for (final field in const [
      'apiKey',
      'appId',
      'projectId',
      'messagingSenderId',
      'authDomain',
    ]) {
      final value = readStringField(options, field);
      if (value == null || value.trim().isEmpty) {
        missing.add(field);
      }
    }
    return missing;
  }

  static String? readStringField(Object options, String field) {
    try {
      final dynamic dynamicOptions = options;
      final Object? value = switch (field) {
        'apiKey' => dynamicOptions.apiKey,
        'appId' => dynamicOptions.appId,
        'projectId' => dynamicOptions.projectId,
        'messagingSenderId' => dynamicOptions.messagingSenderId,
        'authDomain' => dynamicOptions.authDomain,
        _ => null,
      };
      return value?.toString();
    } catch (_) {
      return null;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDgPS4mzsNLIV1Qbqgl3iE5zaT0H8ByOeY',
    appId: '1:532543856833:web:8a2d44c376471c6b797440',
    messagingSenderId: '532543856833',
    projectId: 'hasoob-4a281',
    authDomain: 'hasoob-4a281.firebaseapp.com',
    storageBucket: 'hasoob-4a281.firebasestorage.app',
    measurementId: 'G-T9XPNLDDVY',
  );
}
