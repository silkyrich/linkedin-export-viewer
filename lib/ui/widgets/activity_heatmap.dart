import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/flow_index.dart';

/// GitHub-style activity grid: one cell per day, rows = days of the week,
/// columns = weeks. Color intensity scales with log(message count + 1).
///
/// Reads straight from the FlowIndex events list so no extra passes over
/// the message corpus are needed.
class ActivityHeatmap extends ConsumerWidget {
  const ActivityHeatmap({super.key});

  static const _cellSize = 10.0;
  static const _cellGap = 2.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(flowIndexProvider);
    if (index == null || index.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final now = index.maxDate;
    final start = DateTime.utc(
      index.minDate.year,
      index.minDate.month,
      index.minDate.day,
    );
    final lastDay = DateTime.utc(now.year, now.month, now.day);
    final weeks = ((lastDay.difference(start).inDays + 7) / 7).ceil();

    // Bucket events per day.
    final counts = <int, int>{};
    var maxCount = 0;
    for (final e in index.events) {
      final d = DateTime.utc(e.date.year, e.date.month, e.date.day);
      final offset = d.difference(start).inDays;
      if (offset < 0) continue;
      final v = (counts[offset] ?? 0) + 1;
      counts[offset] = v;
      if (v > maxCount) maxCount = v;
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.grid_on_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Activity', style: theme.textTheme.titleMedium),
                ),
                Text(
                  '${DateFormat.yMMM().format(start)} → ${DateFormat.yMMM().format(now)}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 7 * (_cellSize + _cellGap),
              child: Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: CustomPaint(
                    size: Size(
                      weeks * (_cellSize + _cellGap),
                      7 * (_cellSize + _cellGap),
                    ),
                    painter: _HeatmapPainter(
                      start: start,
                      weeks: weeks,
                      counts: counts,
                      maxCount: maxCount,
                      surface: theme.colorScheme.surfaceContainerHighest,
                      primary: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Less', style: theme.textTheme.labelSmall),
                const SizedBox(width: 6),
                for (var i = 0; i < 5; i++)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        theme.colorScheme.surfaceContainerHighest,
                        theme.colorScheme.primary,
                        i / 4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                const SizedBox(width: 6),
                Text('More', style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.start,
    required this.weeks,
    required this.counts,
    required this.maxCount,
    required this.surface,
    required this.primary,
  });

  final DateTime start;
  final int weeks;
  final Map<int, int> counts;
  final int maxCount;
  final Color surface;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = ActivityHeatmap._cellSize;
    const gap = ActivityHeatmap._cellGap;
    final logMax = maxCount == 0 ? 1.0 : log(maxCount + 1);

    for (var w = 0; w < weeks; w++) {
      for (var d = 0; d < 7; d++) {
        final offset = w * 7 + d;
        final count = counts[offset] ?? 0;
        final intensity = count == 0
            ? 0.0
            : (log(count + 1) / logMax).clamp(0.1, 1.0);
        final color = count == 0
            ? surface
            : Color.lerp(surface, primary, intensity)!;
        final rect = Rect.fromLTWH(
          w * (cell + gap),
          d * (cell + gap),
          cell,
          cell,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) =>
      old.counts != counts ||
      old.weeks != weeks ||
      old.primary != primary ||
      old.surface != surface;
}
