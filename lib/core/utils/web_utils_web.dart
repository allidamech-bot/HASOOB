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

  static String browserHint() {
    try {
      final navigator = js.context['navigator'];
      final userAgent = navigator == null
          ? ''
          : js.JsObject.fromBrowserObject(navigator)['userAgent']?.toString() ?? '';
      final isIos = RegExp(r'iPad|iPhone|iPod').hasMatch(userAgent) ||
          userAgent.contains('Macintosh') && userAgent.contains('Mobile');
      final isSafari = userAgent.contains('Safari') &&
          !userAgent.contains('CriOS') &&
          !userAgent.contains('FxiOS') &&
          !userAgent.contains('EdgiOS');
      if (isIos && isSafari) {
        return 'Platform: Web / iOS Safari';
      }
      if (isIos) {
        return 'Platform: Web / iOS browser';
      }
      if (isSafari) {
        return 'Platform: Web / Safari';
      }
      return 'Platform: Web';
    } catch (_) {
      return 'Platform: Web';
    }
  }
}
