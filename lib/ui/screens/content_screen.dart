import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/linkedin_links.dart';
import '../../models/archive.dart';
import '../../state/archive_controller.dart';

class ContentScreen extends ConsumerStatefulWidget {
  const ContentScreen({super.key});

  @override
  ConsumerState<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends ConsumerState<ContentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final archive = ref.watch(archiveControllerProvider).valueOrNull;
    if (archive == null) {
      return const Center(child: Text('No archive loaded.'));
    }
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Publications'),
              Tab(text: 'Projects'),
              Tab(text: 'Rich Media'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _PublicationsTab(archive: archive),
              _ProjectsTab(archive: archive),
              _RichMediaTab(archive: archive),
            ],
          ),
        ),
      ],
    );
  }
}

class _PublicationsTab extends StatelessWidget {
  const _PublicationsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Publications.csv');
    if (file == null || file.rows.isEmpty) {
      return const Center(child: Text('No publications in this archive.'));
    }
    return ListView.builder(
      itemCount: file.rows.length,
      itemBuilder: (ctx, i) {
        final r = file.rows[i];
        String f(String k) {
          final idx = file.headers.indexOf(k);
          return (idx == -1 || idx >= r.length) ? '' : r[idx];
        }
        final url = f('Url');
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(f('Name')),
            subtitle: Text('${f('Publisher')} · ${f('Published On')}\n\n${f('Description')}'),
            isThreeLine: true,
            trailing: url.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Open publication',
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => openExternalUrl(url),
                  ),
          ),
        );
      },
    );
  }
}

class _ProjectsTab extends StatelessWidget {
  const _ProjectsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Projects.csv');
    if (file == null || file.rows.isEmpty) {
      return const Center(child: Text('No projects in this archive.'));
    }
    return ListView.builder(
      itemCount: file.rows.length,
      itemBuilder: (ctx, i) {
        final r = file.rows[i];
        String f(String k) {
          final idx = file.headers.indexOf(k);
          return (idx == -1 || idx >= r.length) ? '' : r[idx];
        }
        final started = f('Started On');
        final finished = f('Finished On');
        final url = f('Url');
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(f('Title'),
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (url.isNotEmpty)
                      IconButton(
                        tooltip: 'Open project',
                        icon: const Icon(Icons.open_in_new, size: 18),
                        onPressed: () => openExternalUrl(url),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [started, if (finished.isNotEmpty) finished].where((s) => s.isNotEmpty).join(' – '),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                Text(f('Description')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RichMediaTab extends StatelessWidget {
  const _RichMediaTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Rich_Media.csv');
    if (file == null || file.rows.isEmpty) {
      return const Center(child: Text('No rich media in this archive.'));
    }
    return ListView.builder(
      itemCount: file.rows.length,
      itemBuilder: (ctx, i) {
        final r = file.rows[i];
        String f(String k) {
          final idx = file.headers.indexOf(k);
          return (idx == -1 || idx >= r.length) ? '' : r[idx];
        }
        final link = f('Media Link');
        return ListTile(
          leading: const Icon(Icons.photo_outlined),
          title: Text(f('Media Description'),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(link,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    f('Date/Time'),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                if (link.isNotEmpty)
                  IconButton(
                    tooltip: 'Open media',
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => openExternalUrl(link),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
