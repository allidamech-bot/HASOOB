import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class AppWebUtils {
  static void downloadBytes(Uint8List bytes, String fileName) {
    if (!kIsWeb) return;

    final blob = web.Blob([bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..click();
    web.URL.revokeObjectURL(url);
  }

  static void downloadText(String content, String fileName) {
    if (!kIsWeb) return;

    final blob = web.Blob(
      [content.toJS].toJS,
      web.BlobPropertyBag(type: 'text/plain', endings: 'native'),
    );
    final url = web.URL.createObjectURL(blob);
    web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..click();
    web.URL.revokeObjectURL(url);
  }
}
