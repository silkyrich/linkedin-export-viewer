import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/archive.dart';
import '../../core/linkedin_links.dart';
import '../../state/archive_controller.dart';
import '../widgets/empty_state.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

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
              Tab(text: 'Company Follows'),
              Tab(text: 'Events'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _CompanyFollowsTab(archive: archive),
              _EventsTab(archive: archive),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompanyFollowsTab extends StatelessWidget {
  const _CompanyFollowsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Company Follows.csv');
    if (file == null || file.rows.isEmpty) {
      return const EmptyState(
        message: 'Not following any companies.',
        icon: Icons.domain,
      );
    }
    return ListView.builder(
      itemCount: file.rows.length,
      itemBuilder: (ctx, i) {
        final r = file.rows[i];
        String f(String k) {
          final idx = file.headers.indexOf(k);
          return (idx == -1 || idx >= r.length) ? '' : r[idx];
        }
        final org = f('Organization');
        return ListTile(
          leading: const Icon(Icons.domain),
          title: Text(org),
          trailing: SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    f('Followed On'),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                if (org.isNotEmpty)
                  IconButton(
                    tooltip: 'Find $org on LinkedIn',
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => openLinkedInCompany(org),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EventsTab extends StatelessWidget {
  const _EventsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Events.csv');
    if (file == null || file.rows.isEmpty) {
      return const EmptyState(message: 'No events.', icon: Icons.event_outlined);
    }
    return ListView.builder(
      itemCount: file.rows.length,
      itemBuilder: (ctx, i) {
        final r = file.rows[i];
        String f(String k) {
          final idx = file.headers.indexOf(k);
          return (idx == -1 || idx >= r.length) ? '' : r[idx];
        }
        final url = f('External Url');
        return ListTile(
          leading: const Icon(Icons.event_outlined),
          title: Text(f('Event Name')),
          subtitle: Text(f('Event Time')),
          trailing: SizedBox(
            width: 130,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    f('Status'),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                if (url.isNotEmpty)
                  IconButton(
                    tooltip: 'Open event link',
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => openExternalUrl(url),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
