import 'dart:convert';

import 'package:web/web.dart' as web;

/// Trigger a browser download of a text blob as [filename].
/// Uses a base64 data URL — works for our dossier-sized payloads (~50 KB).
void downloadTextFile(String filename, String content) {
  final encoded = base64Encode(utf8.encode(content));
  final anchor = web.HTMLAnchorElement()
    ..href = 'data:text/markdown;charset=utf-8;base64,$encoded'
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
