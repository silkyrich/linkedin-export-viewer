import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/archive.dart';
import '../../state/archive_controller.dart';
import '../../state/flow_index.dart';

/// "What LinkedIn knows about you at a glance" card for the top of /me.
///
/// Pulls big numbers from the archive and — where it's cheap — the
/// top-3 most-messaged contacts from the flow index. Intentionally
/// avoids anything that requires re-scanning a big file per rebuild.
class SummaryCard extends ConsumerWidget {
  const SummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archive = ref.watch(archiveControllerProvider).valueOrNull;
    final flow = ref.watch(flowIndexProvider);
    if (archive == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final stats = _compute(archive, flow);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_graph, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  "What's in this archive",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final s in stats.bigNumbers)
                  _Stat(label: s.$1, value: s.$2),
              ],
            ),
            if (stats.activeSince != null) ...[
              const SizedBox(height: 12),
              Text(
                'Active ${DateFormat.yMMM().format(stats.activeSince!)}'
                ' → ${DateFormat.yMMM().format(stats.activeUntil!)} '
                '(${stats.activeYears} years)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
            if (stats.topContacts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Most-messaged contacts',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              for (final c in stats.topContacts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${c.totalOutgoing} sent · ${c.totalIncoming} received',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStats {
  _SummaryStats({
    required this.bigNumbers,
    required this.activeSince,
    required this.activeUntil,
    required this.activeYears,
    required this.topContacts,
  });
  final List<(String, String)> bigNumbers;
  final DateTime? activeSince;
  final DateTime? activeUntil;
  final int activeYears;
  final List<FlowContact> topContacts;
}

String _fmt(int n) => NumberFormat.decimalPattern().format(n);

int _rows(LinkedInArchive a, String path) => a.file(path)?.rows.length ?? 0;

_SummaryStats _compute(LinkedInArchive archive, FlowIndex? flow) {
  final nums = <(String, String)>[
    ('Messages', _fmt(archive.messageCount)),
    ('Conversations', _fmt(archive.conversationCount)),
    ('Connections', _fmt(archive.connectionCount)),
    ('Positions', _fmt(_rows(archive, 'Positions.csv'))),
    ('Skills', _fmt(_rows(archive, 'Skills.csv'))),
    ('Endorsements',
        _fmt(_rows(archive, 'Endorsement_Received_Info.csv'))),
    ('Invitations', _fmt(_rows(archive, 'Invitations.csv'))),
    ('Courses', _fmt(_rows(archive, 'Learning.csv'))),
  ];

  final since = flow != null && !flow.isEmpty ? flow.minDate : null;
  final until = flow != null && !flow.isEmpty ? flow.maxDate : null;
  final years = (since != null && until != null)
      ? (until.difference(since).inDays / 365).round()
      : 0;

  final top = <FlowContact>[];
  if (flow != null && flow.contacts.isNotEmpty) {
    final sorted = flow.contacts.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    top.addAll(sorted.take(3));
  }

  return _SummaryStats(
    bigNumbers: nums,
    activeSince: since,
    activeUntil: until,
    activeYears: years,
    topContacts: top,
  );
}
