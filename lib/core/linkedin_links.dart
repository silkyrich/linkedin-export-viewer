import 'links_stub.dart' if (dart.library.js_interop) 'links_web.dart';

/// Open a profile. Prefers the captured LinkedIn URL; falls back to a
/// people-search query when we only know the name (e.g. from a
/// Recommendation row that doesn't store the URL).
void openLinkedInProfile({String? url, String? name}) {
  if (url != null && url.trim().isNotEmpty) {
    openUrl(url.trim());
    return;
  }
  if (name != null && name.trim().isNotEmpty) {
    final q = Uri.encodeComponent(name.trim());
    openUrl('https://www.linkedin.com/search/results/people/?keywords=$q');
  }
}

/// Open a company. LinkedIn company IDs aren't in the export, so we fall
/// back to a company search by name.
void openLinkedInCompany(String name) {
  final q = Uri.encodeComponent(name.trim());
  if (q.isEmpty) return;
  openUrl('https://www.linkedin.com/search/results/companies/?keywords=$q');
}

/// Open a job URL exactly as LinkedIn stored it.
void openLinkedInJob(String url) {
  if (url.trim().isEmpty) return;
  openUrl(url.trim());
}

/// Open an arbitrary URL (e.g. Publications.csv → Url column).
void openExternalUrl(String url) {
  if (url.trim().isEmpty) return;
  openUrl(url.trim());
}
