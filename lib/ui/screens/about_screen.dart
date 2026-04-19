import 'package:flutter/material.dart';

import '../../core/linkedin_links.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _repoUrl = 'https://github.com/silkyrich/linkedin-export-viewer';
  static const _siteUrl = 'https://silkyrich.github.io/linkedin-export-viewer/';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('About', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your data stays in your browser',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'LinkedIn Export Viewer is a static site. When you upload '
                  'your LinkedIn data-export zip, the file is opened by the '
                  'JavaScript running in this tab and never sent to any '
                  'server. There is no backend. The hosting provider (GitHub '
                  'Pages) only serves the HTML/JS — it does not receive your '
                  'archive.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'To keep things convenient across page refreshes, the raw '
                  'zip bytes are cached in your browser\'s IndexedDB. Use '
                  '"Clear data" in the banner above to wipe that cache at '
                  'any time — or use your browser\'s "clear site data" '
                  'option.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Deep-links to LinkedIn open in a new tab with '
                  'noopener/noreferrer so the destination page cannot reach '
                  'back into this one. LinkedIn will see your normal browser '
                  'activity as soon as you arrive on their site — that is '
                  'unchanged by using this viewer.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How to get your export',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'On LinkedIn: Me → Settings & Privacy → Data Privacy → '
                  'Get a copy of your data. Pick "Want something in '
                  'particular?" or download everything. LinkedIn emails '
                  'you a .zip when it is ready (usually minutes for the '
                  'fast bundle, 24h for the full archive).',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('License', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'MIT License. You can fork, host your own copy, and modify '
                  'it freely. See the LICENSE file in the repo for the full '
                  'text. This project is not affiliated with LinkedIn.',
                ),
                const SizedBox(height: 4),
                const Text(
                  '"LinkedIn" is a trademark of LinkedIn Corporation. Schema '
                  'names and CSV headers used here come from the data export '
                  'LinkedIn provides to its own members.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Built with', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'Flutter web (CanvasKit), Riverpod, go_router, the archive + '
                  'csv packages, idb_shim for IndexedDB caching, and '
                  'two_dimensional_scrollables for big tables. The Flow '
                  'graph uses a plain CustomPainter — no JS charting '
                  'library.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => openExternalUrl(_repoUrl),
                icon: const Icon(Icons.code),
                label: const Text('Source on GitHub'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => openExternalUrl(_siteUrl),
                icon: const Icon(Icons.public),
                label: const Text('Live site'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
