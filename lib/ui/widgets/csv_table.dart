import 'package:flutter/material.dart';

import '../../models/parsed_file.dart';

/// Simple virtualized table for arbitrary CSV files.
///
/// Uses a horizontal [SingleChildScrollView] wrapping a vertical
/// [ListView.builder] so wide exports (Ad_Targeting.csv has 35 columns)
/// scroll on both axes without materializing every cell up-front.
class CsvTable extends StatelessWidget {
  const CsvTable({required this.file, super.key});

  final ParsedFile file;

  @override
  Widget build(BuildContext context) {
    if (file.rows.isEmpty) {
      return const Center(child: Text('No rows in this file.'));
    }
    final colCount = file.headers.length;
    // Reserve enough width per column so long fields don't collapse to nothing.
    const colWidth = 180.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = colCount * colWidth;
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth < constraints.maxWidth ? constraints.maxWidth : tableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderRow(headers: file.headers, colWidth: colWidth),
                  Expanded(
                    child: ListView.builder(
                      itemCount: file.rows.length,
                      itemBuilder: (ctx, i) => _DataRow(
                        row: file.rows[i],
                        colCount: colCount,
                        colWidth: colWidth,
                        alternate: i.isOdd,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.headers, required this.colWidth});
  final List<String> headers;
  final double colWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < headers.length; i++)
            SizedBox(
              width: colWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  headers[i],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.row,
    required this.colCount,
    required this.colWidth,
    required this.alternate,
  });

  final List<String> row;
  final int colCount;
  final double colWidth;
  final bool alternate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: alternate ? theme.colorScheme.surfaceContainerLow : null,
      child: Row(
        children: [
          for (var i = 0; i < colCount; i++)
            SizedBox(
              width: colWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  i < row.length ? row[i] : '',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
