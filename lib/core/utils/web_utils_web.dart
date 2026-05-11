// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

class WebUtils {
  static void logDiagnostic(String message) {
    try {
      js.context.callMethod('logDiagnostic', [message]);
    } catch (e) {
      // ignore
    }
  }

  static void removeSplash() {
    try {
      js.context.callMethod('removeSplashFromWeb');
    } catch (e) {
      // ignore
    }
  }
}
