import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/archive.dart';
import '../../models/parsed_file.dart';
import '../../state/archive_controller.dart';
import '../widgets/csv_table.dart';
import '../widgets/empty_state.dart';
import '../widgets/simple_bar_chart.dart';
import '../widgets/stat_tile.dart';

/// Account tab: Receipts (simple table) + Ad Targeting (wide, with
/// duplicated column names).
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen>
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
              Tab(text: 'Receipts'),
              Tab(text: 'Ad Targeting'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _ReceiptsTab(archive: archive),
              _AdTargetingTab(archive: archive),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReceiptsTab extends StatelessWidget {
  const _ReceiptsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Receipts_v2.csv');
    if (file == null || file.rows.isEmpty) {
      return const EmptyState(
        message: 'No receipts.',
        icon: Icons.receipt_long_outlined,
      );
    }
    final summary = _summarise(file);
    return ListView(
      children: [
        _summaryCard(context, summary),
        const Divider(height: 1),
        for (var i = 0; i < file.rows.length; i++) _row(file, i),
      ],
    );
  }

  Widget _summaryCard(BuildContext context, _ReceiptsSummary s) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.decimalPattern();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spend summary', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in s.totalByCurrency.entries)
                StatTile(
                  label: 'Total · ${entry.key}',
                  value: _money(entry.value, entry.key),
                  icon: Icons.payments_outlined,
                ),
              StatTile(
                label: 'Transactions',
                value: fmt.format(s.count),
                icon: Icons.receipt_long_outlined,
              ),
              StatTile(
                label: 'Active years',
                value: s.yearSpan == null ? '—' : '${s.yearSpan!.$1}–${s.yearSpan!.$2}',
                icon: Icons.calendar_today_outlined,
              ),
              if (s.avgByCurrency.isNotEmpty)
                StatTile(
                  label: 'Avg · ${s.avgByCurrency.entries.first.key}',
                  value: _money(
                    s.avgByCurrency.entries.first.value,
                    s.avgByCurrency.entries.first.key,
                  ),
                  icon: Icons.show_chart,
                ),
            ],
          ),
          if (s.byPaymentMethod.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Payment methods', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            SimpleBarChart(
              horizontal: true,
              data: s.byPaymentMethod.entries
                  .map((e) => (_prettyMethod(e.key), e.value))
                  .toList()
                ..sort((a, b) => b.$2.compareTo(a.$2)),
              valueFormatter: (v) => fmt.format(v),
            ),
          ],
          if (s.byYear.length > 1) ...[
            const SizedBox(height: 16),
            Text('Transactions per year', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            SimpleBarChart(
              data: (s.byYear.entries.toList()
                    ..sort((a, b) => a.key.compareTo(b.key)))
                  .map((e) => (e.key.toString(), e.value))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(ParsedFile file, int i) {
    final r = file.rows[i];
    String f(String k) {
      final idx = file.headers.indexOf(k);
      return (idx == -1 || idx >= r.length) ? '' : r[idx];
    }
    return ListTile(
      leading: const Icon(Icons.receipt_long_outlined),
      title: Text('${f('Description')} · ${f('Currency Code')} ${f('Total Amount')}'),
      subtitle: Text(
        '${f('Invoice Number')} · ${f('Transaction Made At')} · ${_prettyMethod(f('Payment Method Type'))}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ReceiptsSummary {
  _ReceiptsSummary({
    required this.count,
    required this.totalByCurrency,
    required this.avgByCurrency,
    required this.byPaymentMethod,
    required this.byYear,
    required this.yearSpan,
  });
  final int count;
  final Map<String, double> totalByCurrency;
  final Map<String, double> avgByCurrency;
  final Map<String, int> byPaymentMethod;
  final Map<int, int> byYear;
  final (int, int)? yearSpan;
}

_ReceiptsSummary _summarise(ParsedFile file) {
  final headers = file.headers;
  int idx(String k) => headers.indexOf(k);
  final totalIdx = idx('Total Amount');
  final currIdx = idx('Currency Code');
  final methodIdx = idx('Payment Method Type');
  final dateIdx = idx('Transaction Made At');

  final totalByCurrency = <String, double>{};
  final byPaymentMethod = <String, int>{};
  final byYear = <int, int>{};

  int? minYear;
  int? maxYear;

  for (final r in file.rows) {
    String at(int i) => (i < 0 || i >= r.length) ? '' : r[i];
    final total = double.tryParse(at(totalIdx)) ?? 0;
    final curr = at(currIdx).isEmpty ? 'UNK' : at(currIdx);
    totalByCurrency[curr] = (totalByCurrency[curr] ?? 0) + total;
    final method = at(methodIdx).isEmpty ? 'Unknown' : at(methodIdx);
    byPaymentMethod[method] = (byPaymentMethod[method] ?? 0) + 1;
    final yearMatch = RegExp(r'^(\d{4})').firstMatch(at(dateIdx));
    if (yearMatch != null) {
      final y = int.parse(yearMatch.group(1)!);
      byYear[y] = (byYear[y] ?? 0) + 1;
      if (minYear == null || y < minYear) minYear = y;
      if (maxYear == null || y > maxYear) maxYear = y;
    }
  }

  final avgByCurrency = <String, double>{
    for (final c in totalByCurrency.keys)
      c: totalByCurrency[c]! / file.rows.length,
  };

  return _ReceiptsSummary(
    count: file.rows.length,
    totalByCurrency: totalByCurrency,
    avgByCurrency: avgByCurrency,
    byPaymentMethod: byPaymentMethod,
    byYear: byYear,
    yearSpan: (minYear != null && maxYear != null) ? (minYear, maxYear) : null,
  );
}

String _money(double amount, String currency) {
  try {
    return NumberFormat.simpleCurrency(name: currency).format(amount);
  } catch (_) {
    return '${amount.toStringAsFixed(2)} $currency';
  }
}

String _prettyMethod(String s) {
  if (s.isEmpty) return 'Unknown';
  return s
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// Ad Targeting has duplicate column names (Company Names ×3, Job Titles ×3,
/// plus odd-case `degreeClass` and `interfaceLocale` variants). We render it
/// as a positional list of (header, value) pairs so nothing is silently
/// collapsed. Duplicate headers are clearly visible.
class _AdTargetingTab extends StatelessWidget {
  const _AdTargetingTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Ad_Targeting.csv');
    if (file == null || file.rows.isEmpty) {
      return const Center(child: Text('No ad targeting data.'));
    }
    final row = file.rows.first;
    final theme = Theme.of(context);

    // Group consecutive duplicate headers so the UI shows "Company Names"
    // once with its three pipe-separated segments expanded.
    final groups = <_TargetGroup>[];
    for (var i = 0; i < file.headers.length; i++) {
      final key = file.headers[i];
      final value = i < row.length ? row[i] : '';
      if (groups.isNotEmpty && groups.last.key == key) {
        groups.last.values.add(value);
      } else {
        groups.add(_TargetGroup(key: key, values: [value]));
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'What LinkedIn uses to target ads at you (${groups.length} segment keys)',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: groups.length,
            itemBuilder: (ctx, i) {
              final g = groups[i];
              final chips = g.values
                  .expand((v) => v.split('|'))
                  .map((v) => v.trim())
                  .where((v) => v.isNotEmpty)
                  .toList();
              if (chips.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.key, style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final c in chips) Chip(label: Text(c))],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (ctx) => Scaffold(
                    appBar: AppBar(title: const Text('Ad_Targeting.csv (raw)')),
                    body: CsvTable(file: file),
                  ),
                ),
              ),
              icon: const Icon(Icons.table_rows_outlined),
              label: const Text('View raw CSV'),
            ),
          ),
        ),
      ],
    );
  }
}

class _TargetGroup {
  _TargetGroup({required this.key, required this.values});
  final String key;
  final List<String> values;
}
