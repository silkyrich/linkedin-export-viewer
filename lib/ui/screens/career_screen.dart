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
    required this.workingMonths,
    required this.gapMonths,
    required this.careerSpanMonths,
    required this.longestTenureMonths,
    required this.longestTitle,
    required this.longestCompany,
    required this.firstStart,
    required this.lastEnd,
    required this.stillWorking,
  });
  final int companies;

  /// Months *in work* — sum of merged, non-overlapping position intervals.
  final int workingMonths;

  /// Months *between* jobs — the career span minus time in work.
  final int gapMonths;

  /// Total months from first start date until the last known end date
  /// (or now, if there's a currently-open position).
  final int careerSpanMonths;
  final int longestTenureMonths;
  final String longestTitle;
  final String longestCompany;
  final DateTime? firstStart;
  final DateTime? lastEnd;
  final bool stillWorking;
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
  DateTime? firstStart;
  DateTime? lastEnd;
  var stillWorking = false;
  final intervals = <(DateTime, DateTime)>[];

  for (final r in file.rows) {
    String at(int i) => (i < 0 || i >= r.length) ? '' : r[i];
    final company = at(companyIdx);
    if (company.isNotEmpty) companies.add(company);
    final start = _parseLinkedInDate(at(startIdx));
    final finishStr = at(finishIdx);
    final rawEnd = _parseLinkedInDate(finishStr);
    final end = rawEnd ?? DateTime.now();
    if (finishStr.trim().isEmpty) stillWorking = true;
    if (start == null) continue;
    intervals.add((start, end));
    final months = (end.year - start.year) * 12 + (end.month - start.month);
    final clean = months < 0 ? 0 : months;
    if (clean > longestMonths) {
      longestMonths = clean;
      longestTitle = at(titleIdx);
      longestCompany = company;
    }
    if (firstStart == null || start.isBefore(firstStart)) firstStart = start;
    if (lastEnd == null || end.isAfter(lastEnd)) lastEnd = end;
  }

  // Merge overlapping intervals so concurrent jobs don't double-count.
  intervals.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(DateTime, DateTime)>[];
  for (final iv in intervals) {
    if (merged.isEmpty || iv.$1.isAfter(merged.last.$2)) {
      merged.add(iv);
    } else {
      final last = merged.removeLast();
      merged.add((last.$1, iv.$2.isAfter(last.$2) ? iv.$2 : last.$2));
    }
  }
  var workingMonths = 0;
  for (final iv in merged) {
    final m = (iv.$2.year - iv.$1.year) * 12 + (iv.$2.month - iv.$1.month);
    workingMonths += m < 0 ? 0 : m;
  }

  final spanMonths = (firstStart == null || lastEnd == null)
      ? 0
      : ((lastEnd.year - firstStart.year) * 12 +
              (lastEnd.month - firstStart.month))
          .clamp(0, 1 << 30);
  final gap = (spanMonths - workingMonths).clamp(0, 1 << 30);

  return _PositionsSummary(
    companies: companies.length,
    workingMonths: workingMonths,
    gapMonths: gap,
    careerSpanMonths: spanMonths,
    longestTenureMonths: longestMonths,
    longestTitle: longestTitle,
    longestCompany: longestCompany,
    firstStart: firstStart,
    lastEnd: lastEnd,
    stillWorking: stillWorking,
  );
}

Widget _positionsHeader(BuildContext context, _PositionsSummary s) {
  return _PositionsHeader(summary: s);
}

class _PositionsHeader extends StatefulWidget {
  const _PositionsHeader({required this.summary});
  final _PositionsSummary summary;

  @override
  State<_PositionsHeader> createState() => _PositionsHeaderState();
}

class _PositionsHeaderState extends State<_PositionsHeader> {
  int? _retirementAge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.summary;
    final firstYear = s.firstStart?.year;
    final now = DateTime.now();

    // Default assumption: start-working-age 22, retire at 65 → 43-year
    // career. Users override with the slider. We don't store this.
    final defaultAge = 65;
    final age = _retirementAge ?? defaultAge;
    final startAge = 22;
    final retirementYear =
        firstYear == null ? now.year : firstYear - startAge + age;
    final yearsLeft = retirementYear - now.year;
    final totalCareerYears =
        firstYear == null ? 0 : retirementYear - firstYear;

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
                label: 'Time in work',
                value: _duration(s.workingMonths),
                icon: Icons.work_history,
              ),
              if (s.gapMonths > 0)
                StatTile(
                  label: 'Between jobs',
                  value: _duration(s.gapMonths),
                  icon: Icons.pause_circle_outline,
                  hint: 'gaps in timeline',
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
              if (firstYear != null)
                StatTile(
                  label: 'Started working',
                  value: '$firstYear',
                  icon: Icons.flag_outlined,
                ),
              if (firstYear != null && yearsLeft > 0)
                StatTile(
                  label: 'Career left (est.)',
                  value: '${yearsLeft}y',
                  hint: 'retire at $age · ~$retirementYear',
                  icon: Icons.hourglass_bottom,
                ),
            ],
          ),
          if (firstYear != null && totalCareerYears > 0) ...[
            const SizedBox(height: 16),
            _CareerProgressBar(
              summary: s,
              retirementYear: retirementYear,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Retire at', style: theme.textTheme.labelSmall),
                Expanded(
                  child: Slider(
                    value: age.toDouble(),
                    min: 55,
                    max: 75,
                    divisions: 20,
                    label: '$age',
                    onChanged: (v) =>
                        setState(() => _retirementAge = v.round()),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '$age',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CareerProgressBar extends StatelessWidget {
  const _CareerProgressBar({
    required this.summary,
    required this.retirementYear,
  });

  final _PositionsSummary summary;
  final int retirementYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstStart = summary.firstStart;
    if (firstStart == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final totalSpanMonths =
        (retirementYear - firstStart.year) * 12 - firstStart.month + 1;
    if (totalSpanMonths <= 0) return const SizedBox.shrink();

    final workedF = (summary.workingMonths / totalSpanMonths).clamp(0.0, 1.0);
    final gapF = (summary.gapMonths / totalSpanMonths).clamp(0.0, 1.0);
    final toNowMonths = ((now.year - firstStart.year) * 12 +
            (now.month - firstStart.month))
        .clamp(0, totalSpanMonths);
    final nowF = (toNowMonths / totalSpanMonths).clamp(0.0, 1.0);
    final futureF = (1 - nowF).clamp(0.0, 1.0);

    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (ctx, c) {
            final w = c.maxWidth;
            return SizedBox(
              height: 24,
              child: Stack(
                children: [
                  Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Row(
                    children: [
                      Flexible(
                        flex: (workedF * 10000).round(),
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              bottomLeft: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        flex: (gapF * 10000).round(),
                        child: Container(
                          height: 24,
                          color: cs.tertiaryContainer,
                        ),
                      ),
                      Flexible(
                        flex: (futureF * 10000).round(),
                        child: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  Positioned(
                    left: nowF * w - 1,
                    top: -2,
                    bottom: -2,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: cs.onSurface,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${firstStart.year}',
              style: theme.textTheme.labelSmall,
            ),
            const Spacer(),
            Text(
              'Now · ${now.year}',
              style: theme.textTheme.labelSmall,
            ),
            const Spacer(),
            Text(
              'Retire · $retirementYear',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _LegendDot(colour: cs.primary, label: 'In work'),
            _LegendDot(colour: cs.tertiaryContainer, label: 'Between jobs'),
            _LegendDot(
              colour: cs.surfaceContainerHighest,
              label: 'Future (projected)',
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.colour, required this.label});
  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
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
