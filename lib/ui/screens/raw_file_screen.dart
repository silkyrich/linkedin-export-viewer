import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/archive_controller.dart';
import '../widgets/csv_table.dart';

/// Generic fallback viewer for any ParsedFile not covered by a dedicated
/// screen. Useful while we're still building out category-specific UIs.
class RawFileScreen extends ConsumerWidget {
  const RawFileScreen({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archive = ref.watch(archiveControllerProvider).valueOrNull;
    if (archive == null) {
      return const Center(child: Text('No archive loaded.'));
    }
    final file = archive.file(path);
    if (file == null) {
      return Center(child: Text('File not found in archive: $path'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(path, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${file.rows.length} rows · ${file.headers.length} columns',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        Expanded(child: CsvTable(file: file)),
      ],
    );
  }
}
