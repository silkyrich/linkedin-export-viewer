import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/linkedin_links.dart';
import '../../models/archive.dart';
import '../../models/parsed_file.dart';
import '../../state/archive_controller.dart';
import '../widgets/kv_card.dart';
import '../widgets/simple_bar_chart.dart';
import '../widgets/stat_tile.dart';

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
    final summary = _positionsSummary(file);
    return ListView.builder(
      itemCount: file.rows.length + 1,
      itemBuilder: (ctx, index) {
        if (index == 0) return _positionsHeader(context, summary);
        final i = index - 1;
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
    final summary = _applicationsSummary(file);
    return ListView.builder(
      itemCount: file.rows.length + 1,
      itemBuilder: (ctx, index) {
        if (index == 0) return _applicationsHeader(context, summary);
        final i = index - 1;
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

// ---------------------------------------------------------------------------
// Summary helpers

class _PositionsSummary {
  _PositionsSummary({
    required this.companies,
    required this.totalMonths,
    required this.longestTenureMonths,
    required this.longestTitle,
    required this.longestCompany,
    required this.firstYear,
  });
  final int companies;
  final int totalMonths;
  final int longestTenureMonths;
  final String longestTitle;
  final String longestCompany;
  final int? firstYear;
}

_PositionsSummary _positionsSummary(ParsedFile file) {
  final titleIdx = file.headers.indexOf('Title');
  final companyIdx = file.headers.indexOf('Company Name');
  final startIdx = file.headers.indexOf('Started On');
  final finishIdx = file.headers.indexOf('Finished On');

  final companies = <String>{};
  var longestMonths = 0;
  var longestTitle = '';
  var longestCompany = '';
  int? firstYear;
  var totalMonths = 0;

  for (final r in file.rows) {
    String at(int i) => (i < 0 || i >= r.length) ? '' : r[i];
    final company = at(companyIdx);
    if (company.isNotEmpty) companies.add(company);
    final start = _parseLinkedInDate(at(startIdx));
    final end = _parseLinkedInDate(at(finishIdx)) ?? DateTime.now();
    if (start == null) continue;
    final months = (end.year - start.year) * 12 + (end.month - start.month);
    final clean = months < 0 ? 0 : months;
    totalMonths += clean;
    if (clean > longestMonths) {
      longestMonths = clean;
      longestTitle = at(titleIdx);
      longestCompany = company;
    }
    if (firstYear == null || start.year < firstYear) firstYear = start.year;
  }

  return _PositionsSummary(
    companies: companies.length,
    totalMonths: totalMonths,
    longestTenureMonths: longestMonths,
    longestTitle: longestTitle,
    longestCompany: longestCompany,
    firstYear: firstYear,
  );
}

Widget _positionsHeader(BuildContext context, _PositionsSummary s) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Career summary', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            StatTile(
              label: 'Experience',
              value: _duration(s.totalMonths),
              icon: Icons.schedule,
            ),
            StatTile(
              label: 'Companies',
              value: '${s.companies}',
              icon: Icons.domain,
            ),
            StatTile(
              label: 'Longest tenure',
              value: _duration(s.longestTenureMonths),
              hint: [s.longestTitle, s.longestCompany]
                  .where((x) => x.isNotEmpty)
                  .join(' · '),
              icon: Icons.trending_up,
            ),
            if (s.firstYear != null)
              StatTile(
                label: 'Started working',
                value: s.firstYear.toString(),
                icon: Icons.flag_outlined,
              ),
          ],
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Applications summary

class _ApplicationsSummary {
  _ApplicationsSummary({
    required this.total,
    required this.companies,
    required this.byMonth,
    required this.topCompanies,
  });
  final int total;
  final int companies;
  final Map<String, int> byMonth; // 'YYYY-MM' -> count
  final List<(String, int)> topCompanies;
}

_ApplicationsSummary _applicationsSummary(ParsedFile file) {
  final dateIdx = file.headers.indexOf('Application Date');
  final companyIdx = file.headers.indexOf('Company Name');
  final byMonth = <String, int>{};
  final byCompany = <String, int>{};

  for (final r in file.rows) {
    String at(int i) => (i < 0 || i >= r.length) ? '' : r[i];
    final date = _parseLinkedInDate(at(dateIdx));
    if (date != null) {
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      byMonth[key] = (byMonth[key] ?? 0) + 1;
    }
    final c = at(companyIdx);
    if (c.isNotEmpty) byCompany[c] = (byCompany[c] ?? 0) + 1;
  }

  final top = byCompany.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return _ApplicationsSummary(
    total: file.rows.length,
    companies: byCompany.length,
    byMonth: byMonth,
    topCompanies: top.take(5).map((e) => (e.key, e.value)).toList(),
  );
}

Widget _applicationsHeader(BuildContext context, _ApplicationsSummary s) {
  final theme = Theme.of(context);
  // Keep only the last ~18 months in the chart so it stays readable.
  final entries = s.byMonth.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final recent = entries.length > 18
      ? entries.sublist(entries.length - 18)
      : entries;

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Applications summary', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            StatTile(label: 'Applications', value: '${s.total}'),
            StatTile(label: 'Unique companies', value: '${s.companies}'),
            if (s.topCompanies.isNotEmpty)
              StatTile(
                label: 'Top target',
                value: s.topCompanies.first.$1,
                hint: '${s.topCompanies.first.$2} applications',
              ),
          ],
        ),
        if (recent.length >= 2) ...[
          const SizedBox(height: 16),
          Text('Applications per month (last ${recent.length} months)',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          SimpleBarChart(
            data: [
              for (final e in recent)
                (_shortMonth(e.key), e.value),
            ],
          ),
        ],
      ],
    ),
  );
}

String _shortMonth(String yyyyMm) {
  final parts = yyyyMm.split('-');
  if (parts.length != 2) return yyyyMm;
  const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final m = int.tryParse(parts[1]) ?? 0;
  final mm = (m >= 1 && m <= 12) ? names[m] : parts[1];
  return '$mm\n${parts[0].substring(2)}'; // "Apr\n26"
}

String _duration(int months) {
  if (months < 12) return '${months}m';
  final y = months ~/ 12;
  final m = months % 12;
  if (m == 0) return '${y}y';
  return '${y}y ${m}m';
}

DateTime? _parseLinkedInDate(String s) {
  if (s.trim().isEmpty) return null;
  // Formats we see: "Jun 2 1833", "02 Jun 1833", "Jun 1833", "2024-03"
  const months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };
  final parts = s.trim().split(RegExp(r'\s+'));
  if (parts.length == 3) {
    // Could be "02 Jun 1833" or "Jun 02 1833"
    final m1 = months[parts[0]];
    final m2 = months[parts[1]];
    if (m1 != null) {
      final d = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && y != null) return DateTime.utc(y, m1, d);
    }
    if (m2 != null) {
      final d = int.tryParse(parts[0]);
      final y = int.tryParse(parts[2]);
      if (d != null && y != null) return DateTime.utc(y, m2, d);
    }
  }
  if (parts.length == 2) {
    final m = months[parts[0]];
    final y = int.tryParse(parts[1]);
    if (m != null && y != null) return DateTime.utc(y, m, 1);
  }
  // ISO fallback
  try {
    return DateTime.parse(s.contains('-') && !s.contains('T')
        ? '${s}T00:00:00Z'
        : s);
  } catch (_) {
    return null;
  }
}
