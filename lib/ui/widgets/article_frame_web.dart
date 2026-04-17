import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Sandboxed iframe rendering of an Article's raw HTML.
///
/// Uses `srcdoc` so the HTML is inline (no same-origin fetches) and the
/// `sandbox` attribute blocks scripts, top-level navigation, and form
/// submissions. The user's archive content never gets to run JS against
/// our page.
Widget buildArticleFrame(String html) {
  final viewType = 'article-iframe-${html.hashCode}';
  // Registration is idempotent per viewType, so re-registering across
  // rebuilds is cheap.
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
    final iframe = web.HTMLIFrameElement()
      ..srcdoc = html.toJS
      ..setAttribute('sandbox', 'allow-same-origin')
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    return iframe;
  });
  return HtmlElementView(viewType: viewType);
}
