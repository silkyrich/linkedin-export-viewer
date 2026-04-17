import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Hash strategy keeps GitHub Pages happy under a subpath — no 404 on refresh.
void configureUrlStrategy() {
  setUrlStrategy(const HashUrlStrategy());
}
