import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/archive.dart';
import '../../state/archive_controller.dart';
import '../widgets/csv_table.dart';

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
      return const Center(child: Text('No receipts.'));
    }
    return ListView.builder(
      itemCount: file.rows.length,
      itemBuilder: (ctx, i) {
        final r = file.rows[i];
        String f(String k) {
          final idx = file.headers.indexOf(k);
          return (idx == -1 || idx >= r.length) ? '' : r[idx];
        }
        return ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text('${f('Description')} · ${f('Currency Code')} ${f('Total Amount')}'),
          subtitle: Text(
            '${f('Invoice Number')} · ${f('Transaction Made At')} · ${f('Payment Method Type')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
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
