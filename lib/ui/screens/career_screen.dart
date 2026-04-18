import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/linkedin_links.dart';
import '../../models/archive.dart';
import '../../state/archive_controller.dart';
import '../widgets/kv_card.dart';

class CareerScreen extends ConsumerStatefulWidget {
  const CareerScreen({super.key});

  @override
  ConsumerState<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends ConsumerState<CareerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

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
            isScrollable: true,
            tabs: const [
              Tab(text: 'Positions'),
              Tab(text: 'Applications'),
              Tab(text: 'Saved Jobs'),
              Tab(text: 'Preferences'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _PositionsTab(archive: archive),
              _ApplicationsTab(archive: archive),
              _SavedJobsTab(archive: archive),
              _PreferencesTab(archive: archive),
            ],
          ),
        ),
      ],
    );
  }
}

class _PositionsTab extends StatelessWidget {
  const _PositionsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Positions.csv');
    if (file == null || file.rows.isEmpty) {
      return const Center(child: Text('No positions.'));
    }
    return ListView.builder(
      itemCount: file.rows.length,
      itemBuilder: (ctx, i) {
        final r = file.rows[i];
        String f(String k) {
          final idx = file.headers.indexOf(k);
          return (idx == -1 || idx >= r.length) ? '' : r[idx];
        }
        final company = f('Company Name');
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
                    if (company.isNotEmpty)
                      IconButton(
                        tooltip: 'Find $company on LinkedIn',
                        icon: const Icon(Icons.open_in_new, size: 18),
                        onPressed: () => openLinkedInCompany(company),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(company, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  [f('Started On'), f('Finished On')]
                      .where((s) => s.isNotEmpty)
                      .join(' – '),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (f('Location').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(f('Location'),
                      style: Theme.of(context).textTheme.labelSmall),
                ],
                if (f('Description').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(f('Description')),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ApplicationsTab extends StatelessWidget {
  const _ApplicationsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Jobs/Job Applications.csv');
    if (file == null || file.rows.isEmpty) {
      return const Center(child: Text('No job applications.'));
    }
    return ListView.builder(
      itemCount: file.rows.length,
      itemBuilder: (ctx, i) {
        final r = file.rows[i];
        String f(String k) {
          final idx = file.headers.indexOf(k);
          return (idx == -1 || idx >= r.length) ? '' : r[idx];
        }
        final jobUrl = f('Job Url');
        return ExpansionTile(
          leading: const Icon(Icons.assignment_outlined),
          title: Text(f('Job Title'), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${f('Company Name')} · ${f('Application Date')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: jobUrl.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Open job on LinkedIn',
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => openLinkedInJob(jobUrl),
                ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (f('Resume Name').isNotEmpty)
                    Text('Resume: ${f('Resume Name')}',
                        style: Theme.of(context).textTheme.bodySmall),
                  if (f('Contact Email').isNotEmpty)
                    Text('Contact: ${f('Contact Email')}',
                        style: Theme.of(context).textTheme.bodySmall),
                  if (f('Job Url').isNotEmpty)
                    Text(f('Job Url'),
                        style: Theme.of(context).textTheme.bodySmall),
                  if (f('Question And Answers').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Screening:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(f('Question And Answers')),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SavedJobsTab extends StatelessWidget {
  const _SavedJobsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Jobs/Saved Jobs.csv');
    if (file == null || file.rows.isEmpty) {
      return const Center(child: Text('No saved jobs.'));
    }
    return ListView.builder(
      itemCount: file.rows.length,
      itemBuilder: (ctx, i) {
        final r = file.rows[i];
        String f(String k) {
          final idx = file.headers.indexOf(k);
          return (idx == -1 || idx >= r.length) ? '' : r[idx];
        }
        final jobUrl = f('Job Url');
        return ListTile(
          leading: const Icon(Icons.bookmark_outline),
          title: Text(f('Job Title')),
          subtitle: Text(f('Company Name')),
          trailing: SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    f('Saved Date'),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                if (jobUrl.isNotEmpty)
                  IconButton(
                    tooltip: 'Open job on LinkedIn',
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => openLinkedInJob(jobUrl),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PreferencesTab extends StatelessWidget {
  const _PreferencesTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Jobs/Job Seeker Preferences.csv');
    if (file == null || file.rows.isEmpty) {
      return const Center(child: Text('No job-seeker preferences.'));
    }
    final row = file.rows.first;
    final entries = <MapEntry<String, String>>[];
    for (var i = 0; i < file.headers.length; i++) {
      entries.add(MapEntry(file.headers[i], i < row.length ? row[i] : ''));
    }
    return ListView(
      children: [
        KvCard(title: 'Job Seeker Preferences', entries: entries),
        _alertsCard(archive),
      ],
    );
  }

  Widget _alertsCard(LinkedInArchive archive) {
    final alerts = archive.file('SavedJobAlerts.csv');
    if (alerts == null || alerts.rows.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Saved Job Alerts',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            for (final r in alerts.rows) Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                r.isNotEmpty ? r.first : '',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
