import '../../firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({
    required this.isConfigured,
    required this.message,
  });

  final bool isConfigured;
  final String message;
}

class FirebaseBootstrap {
  static Future<FirebaseBootstrapResult> initialize() async {
    try {
      // ✅ الحل: لا تعيد التهيئة إذا موجود
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      return const FirebaseBootstrapResult(
        isConfigured: true,
        message: '',
      );
    } on FirebaseException catch (e) {
      // ✅ حل مشكلة duplicate-app
      if (e.code == 'duplicate-app') {
        return const FirebaseBootstrapResult(
          isConfigured: true,
          message: '',
        );
      }

      return FirebaseBootstrapResult(
        isConfigured: false,
        message:
        'Firebase initialization failed.\n\nError: ${e.message ?? e.code}',
      );
    } catch (e) {
      return FirebaseBootstrapResult(
        isConfigured: false,
        message:
        'Firebase initialization failed.\n\nError: $e',
      );
    }
  }
}