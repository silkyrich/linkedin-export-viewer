import 'package:web/web.dart' as web;

/// Opens [url] in a new tab. `noopener,noreferrer` prevents the new page
/// from being able to reach back into our window.
void openUrl(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}
