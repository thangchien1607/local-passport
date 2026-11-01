import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Chèn script Maps JavaScript API vào trang và chờ tải xong.
Future<void> loadMapsSdk(String apiKey) {
  final done = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src =
        'https://maps.googleapis.com/maps/api/js'
        '?key=${Uri.encodeQueryComponent(apiKey)}'
    ..async = true;
  script.onload = ((web.Event _) => done.complete()).toJS;
  script.onerror = ((web.Event _) => done.completeError(
    StateError('không tải được Maps JavaScript API'),
  )).toJS;
  web.document.head!.append(script);
  return done.future;
}
