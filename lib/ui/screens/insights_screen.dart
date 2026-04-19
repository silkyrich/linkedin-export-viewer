import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/archive.dart';
import '../../state/archive_controller.dart';
import '../../state/flow_index.dart';
import '../widgets/avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/simple_bar_chart.dart';
import '../widgets/stat_tile.dart';

/// Cross-cutting dashboard. Answers the single question a user most often
/// asks when they open their archive: "what does this all add up to?"
///
/// Pulls aggregates from across every CSV so you get one screen with:
///   - Headline counts (messages, contacts, years active, positions, skills)
///   - Top employers across your connections
///   - Top correspondents
///   - Connection growth per year
///   - LinkedIn Premium spend summary
///   - Longest tenure
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archive = ref.watch(archiveControllerProvider).valueOrNull;
    if (archive == null) {
      return const EmptyState(message: 'No archive loaded.');
    }
    final flow = ref.watch(flowIndexProvider);
    final theme = Theme.of(context);

    final data = _compute(archive, flow);
    final fmt = NumberFormat.decimalPattern();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Insights', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'One-page roll-up across every file in your archive.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),

        // Headline numbers
        _Card(
          title: 'At a glance',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              StatTile(
                label: 'Connections',
                value: fmt.format(data.connectionCount),
                icon: Icons.people_outline,
              ),
              StatTile(
                label: 'Messages',
                value: fmt.format(data.messageCount),
                icon: Icons.chat_bubble_outline,
              ),
              StatTile(
                label: 'Conversations',
                value: fmt.format(data.conversationCount),
                icon: Icons.forum_outlined,
              ),
              StatTile(
                label: 'Years active',
                value: data.yearsActive == null ? '—' : '${data.yearsActive}',
                icon: Icons.calendar_today_outlined,
              ),
              StatTile(
                label: 'Positions',
                value: '${data.positionCount}',
                icon: Icons.work_outline,
              ),
              StatTile(
                label: 'Skills',
                value: '${data.skillCount}',
                icon: Icons.workspace_premium_outlined,
              ),
              StatTile(
                label: 'Endorsements',
                value: fmt.format(data.endorsementsReceived),
                icon: Icons.thumb_up_outlined,
                hint: 'received',
              ),
              StatTile(
                label: 'Applications',
                value: '${data.applicationCount}',
                icon: Icons.assignment_outlined,
              ),
              if (data.premiumSpend != null)
                StatTile(
                  label: 'Premium spent · ${data.premiumCurrency}',
                  value: _money(data.premiumSpend!, data.premiumCurrency!),
                  icon: Icons.payments_outlined,
                ),
              StatTile(
                label: 'Ad segments',
                value: '${data.adSegmentCount}',
                icon: Icons.ads_click,
                hint: 'LinkedIn uses these to target you',
              ),
              if (data.likesCount > 0)
                StatTile(
                  label: 'Likes given',
                  value: fmt.format(data.likesCount),
                  icon: Icons.favorite_border,
                ),
              if (data.commentsCount > 0)
                StatTile(
                  label: 'Comments made',
                  value: fmt.format(data.commentsCount),
                  icon: Icons.chat_bubble_outline,
                ),
              if (data.sharesCount > 0)
                StatTile(
                  label: 'Shares',
                  value: fmt.format(data.sharesCount),
                  icon: Icons.share_outlined,
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (data.topEmployers.isNotEmpty)
          _Card(
            title: 'Top companies in your network',
            child: SimpleBarChart(
              horizontal: true,
              data: data.topEmployers
                  .map((e) => (e.$1, e.$2))
                  .toList(),
              valueFormatter: (v) => fmt.format(v),
            ),
          ),

        if (data.topCorrespondents.isNotEmpty)
          _Card(
            title: 'Most-messaged contacts',
            child: Column(
              children: [
                for (final c in data.topCorrespondents)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Avatar(name: c.name, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${c.sent}↑ ${c.received}↓',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        if (data.connectionsPerYear.length >= 2)
          _Card(
            title: 'Connections added per year',
            child: SimpleBarChart(
              data: (data.connectionsPerYear.entries.toList()
                    ..sort((a, b) => a.key.compareTo(b.key)))
                  .map((e) => (e.key.toString().substring(2), e.value))
                  .toList(),
            ),
          ),

        if (data.longestTenureYears != null)
          _Card(
            title: 'Longest tenure',
            child: Row(
              children: [
                Icon(Icons.trending_up,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data.longestTitle} at ${data.longestCompany}',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        _formatTenure(data.longestTenureYears!),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (data.topSkill != null)
          _Card(
            title: 'Most endorsed skill',
            child: Row(
              children: [
                Chip(
                  label: Text(data.topSkill!.$1),
                  backgroundColor: theme.colorScheme.primaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  '${data.topSkill!.$2} endorsements received',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TopContact {
  _TopContact({required this.name, required this.sent, required this.received});
  final String name;
  final int sent;
  final int received;
}

class _InsightsData {
  _InsightsData({
    required this.connectionCount,
    required this.messageCount,
    required this.conversationCount,
    required this.yearsActive,
    required this.positionCount,
    required this.skillCount,
    required this.endorsementsReceived,
    required this.applicationCount,
    required this.adSegmentCount,
    required this.premiumSpend,
    required this.premiumCurrency,
    required this.topEmployers,
    required this.topCorrespondents,
    required this.connectionsPerYear,
    required this.longestTenureYears,
    required this.longestTitle,
    required this.longestCompany,
    required this.topSkill,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
  });
  final int connectionCount;
  final int messageCount;
  final int conversationCount;
  final int? yearsActive;
  final int positionCount;
  final int skillCount;
  final int endorsementsReceived;
  final int applicationCount;
  final int adSegmentCount;
  final double? premiumSpend;
  final String? premiumCurrency;
  final List<(String, int)> topEmployers;
  final List<_TopContact> topCorrespondents;
  final Map<int, int> connectionsPerYear;
  final double? longestTenureYears;
  final String longestTitle;
  final String longestCompany;
  final (String, int)? topSkill;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
}

_InsightsData _compute(LinkedInArchive archive, FlowIndex? flow) {
  // Connections
  final connectionsFile = archive.file('Connections.csv');
  final companyCounts = <String, int>{};
  final connectionsPerYear = <int, int>{};
  if (connectionsFile != null) {
    final companyIdx = connectionsFile.headers.indexOf('Company');
    final dateIdx = connectionsFile.headers.indexOf('Connected On');
    for (final r in connectionsFile.rows) {
      final c = (companyIdx >= 0 && companyIdx < r.length) ? r[companyIdx] : '';
      if (c.isNotEmpty) companyCounts[c] = (companyCounts[c] ?? 0) + 1;
      final d = (dateIdx >= 0 && dateIdx < r.length) ? r[dateIdx] : '';
      final yearMatch = RegExp(r'(\d{4})').firstMatch(d);
      if (yearMatch != null) {
        final y = int.parse(yearMatch.group(1)!);
        connectionsPerYear[y] = (connectionsPerYear[y] ?? 0) + 1;
      }
    }
  }
  final topEmployers = companyCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // Top correspondents from flow index (already computed per-contact
  // sent/received totals).
  final topContacts = <_TopContact>[];
  if (flow != null) {
    final sorted = flow.contacts.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    for (final c in sorted.take(6)) {
      topContacts.add(_TopContact(
        name: c.name,
        sent: c.totalOutgoing,
        received: c.totalIncoming,
      ));
    }
  }

  // Positions: longest tenure.
  double? longestYears;
  var longestTitle = '';
  var longestCompany = '';
  int positionCount = 0;
  final positionsFile = archive.file('Positions.csv');
  if (positionsFile != null) {
    positionCount = positionsFile.rows.length;
    final titleIdx = positionsFile.headers.indexOf('Title');
    final companyIdx = positionsFile.headers.indexOf('Company Name');
    final startIdx = positionsFile.headers.indexOf('Started On');
    final finishIdx = positionsFile.headers.indexOf('Finished On');
    for (final r in positionsFile.rows) {
      String at(int i) => (i < 0 || i >= r.length) ? '' : r[i];
      final start = _parseDate(at(startIdx));
      final end = _parseDate(at(finishIdx)) ?? DateTime.now();
      if (start == null) continue;
      final months = (end.year - start.year) * 12 + (end.month - start.month);
      final years = months / 12.0;
      if (longestYears == null || years > longestYears) {
        longestYears = years;
        longestTitle = at(titleIdx);
        longestCompany = at(companyIdx);
      }
    }
  }

  // Skills count
  final skillsFile = archive.file('Skills.csv');
  final skillCount = skillsFile?.rows.length ?? 0;

  // Endorsements count + top skill
  (String, int)? topSkill;
  int endorsementsReceived = 0;
  final endFile = archive.file('Endorsement_Received_Info.csv');
  if (endFile != null) {
    endorsementsReceived = endFile.rows.length;
    final skillIdx = endFile.headers.indexOf('Skill Name');
    final counts = <String, int>{};
    for (final r in endFile.rows) {
      if (skillIdx < 0 || skillIdx >= r.length) continue;
      counts[r[skillIdx]] = (counts[r[skillIdx]] ?? 0) + 1;
    }
    if (counts.isNotEmpty) {
      final best = counts.entries
          .reduce((a, b) => a.value >= b.value ? a : b);
      topSkill = (best.key, best.value);
    }
  }

  // Applications
  final applicationsFile = archive.file('Jobs/Job Applications.csv');
  final applicationCount = applicationsFile?.rows.length ?? 0;

  // Premium spend
  double? spend;
  String? currency;
  final receiptsFile = archive.file('Receipts_v2.csv');
  if (receiptsFile != null && receiptsFile.rows.isNotEmpty) {
    final totalIdx = receiptsFile.headers.indexOf('Total Amount');
    final currIdx = receiptsFile.headers.indexOf('Currency Code');
    final byCurrency = <String, double>{};
    for (final r in receiptsFile.rows) {
      String at(int i) => (i < 0 || i >= r.length) ? '' : r[i];
      final c = at(currIdx).isEmpty ? 'UNK' : at(currIdx);
      final v = double.tryParse(at(totalIdx)) ?? 0;
      byCurrency[c] = (byCurrency[c] ?? 0) + v;
    }
    // Pick the largest currency bucket (most archives only have one).
    if (byCurrency.isNotEmpty) {
      final biggest = byCurrency.entries
          .reduce((a, b) => a.value >= b.value ? a : b);
      spend = biggest.value;
      currency = biggest.key;
    }
  }

  // Ad segment count (just count non-empty, non-duplicate segment columns).
  var adSegmentCount = 0;
  final adFile = archive.file('Ad_Targeting.csv');
  if (adFile != null && adFile.rows.isNotEmpty) {
    final row = adFile.rows.first;
    for (final v in row) {
      if (v.trim().isNotEmpty) adSegmentCount++;
    }
  }

  final years =
      (flow != null && !flow.isEmpty)
          ? (flow.maxDate.difference(flow.minDate).inDays / 365).round()
          : null;

  final likesCount = archive.file('Reactions.csv')?.rows.length ?? 0;
  final commentsCount = archive.file('Comments.csv')?.rows.length ?? 0;
  final sharesCount = archive.file('Shares.csv')?.rows.length ?? 0;

  return _InsightsData(
    connectionCount: archive.connectionCount,
    messageCount: archive.messageCount,
    conversationCount: archive.conversationCount,
    yearsActive: years,
    positionCount: positionCount,
    skillCount: skillCount,
    endorsementsReceived: endorsementsReceived,
    applicationCount: applicationCount,
    adSegmentCount: adSegmentCount,
    premiumSpend: spend,
    premiumCurrency: currency,
    topEmployers: topEmployers
        .take(7)
        .map((e) => (e.key, e.value))
        .toList(),
    topCorrespondents: topContacts,
    connectionsPerYear: connectionsPerYear,
    longestTenureYears: longestYears,
    longestTitle: longestTitle,
    longestCompany: longestCompany,
    topSkill: topSkill,
    likesCount: likesCount,
    commentsCount: commentsCount,
    sharesCount: sharesCount,
  );
}

DateTime? _parseDate(String s) {
  if (s.trim().isEmpty) return null;
  const months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };
  final parts = s.trim().split(RegExp(r'\s+'));
  if (parts.length == 3) {
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
  return null;
}

String _money(double v, String currency) {
  try {
    return NumberFormat.simpleCurrency(name: currency).format(v);
  } catch (_) {
    return '${v.toStringAsFixed(2)} $currency';
  }
}

String _formatTenure(double years) {
  if (years < 1) {
    final months = (years * 12).round();
    return '$months month${months == 1 ? '' : 's'}';
  }
  final y = years.floor();
  final m = ((years - y) * 12).round();
  if (m == 0) return '$y year${y == 1 ? '' : 's'}';
  return '$y y $m m';
}
