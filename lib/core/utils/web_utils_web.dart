// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

class WebUtils {
  static final List<StreamSubscription<dynamic>> _lifecycleSubscriptions = [];

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

  static void reloadPage() {
    try {
      html.window.location.reload();
    } catch (e) {
      // ignore
    }
  }

  static bool isStartupDebugEnabled() {
    try {
      return js.context.callMethod('isStartupDebugEnabled') == true;
    } catch (e) {
      return false;
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

  static void registerSyncLifecycleHook(void Function(String eventName) onEvent) {
    try {
      unregisterSyncLifecycleHook();
      _lifecycleSubscriptions.addAll([
        html.document.onVisibilityChange.listen((_) {
          onEvent(html.document.visibilityState == 'visible' ? 'visible' : 'hidden');
        }),
        html.window.onFocus.listen((_) => onEvent('focus')),
        html.window.onBlur.listen((_) => onEvent('blur')),
        html.window.onPageHide.listen((_) => onEvent('pagehide')),
        html.window.onPageShow.listen((_) => onEvent('pageshow')),
        html.window.onOnline.listen((_) => onEvent('online')),
        html.window.onOffline.listen((_) => onEvent('offline')),
      ]);
      logDiagnostic('sync lifecycle hook registered');
    } catch (e) {
      logDiagnostic('sync lifecycle hook registration failed: $e');
    }
  }

  static void unregisterSyncLifecycleHook() {
    try {
      for (final subscription in _lifecycleSubscriptions) {
        subscription.cancel();
      }
      _lifecycleSubscriptions.clear();
    } catch (_) {}
  }
}
