import 'package:flutter/material.dart';

/// Non-web fallback. Sandboxed iframe rendering only works in the browser,
/// so outside of web we show a plain-text preview — enough for tests.
Widget buildArticleFrame(String html) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Text(_stripTags(html)),
  );
}

String _stripTags(String html) =>
    html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
