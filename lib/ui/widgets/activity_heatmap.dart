import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/flow_index.dart';

/// GitHub-style activity grid: one cell per day, rows = days of the week,
/// columns = weeks. Color intensity scales with log(message count + 1).
///
/// Hover a cell to see the date + exact count. Tap a cell to pin the
/// tooltip (useful on touch devices). Tap outside or on the pinned cell
/// again to dismiss.
class ActivityHeatmap extends ConsumerStatefulWidget {
  const ActivityHeatmap({super.key});

  static const _cellSize = 10.0;
  static const _cellGap = 2.0;
  static const _rowStride = _cellSize + _cellGap;

  @override
  ConsumerState<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends ConsumerState<ActivityHeatmap> {
  int? _hoverOffset;
  Offset? _hoverPos;
  int? _pinOffset;

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(flowIndexProvider);
    if (index == null || index.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final start = DateTime.utc(
      index.minDate.year,
      index.minDate.month,
      index.minDate.day,
    );
    final now = index.maxDate;
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

    final activeOffset = _pinOffset ?? _hoverOffset;

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
              height: 7 * ActivityHeatmap._rowStride + 42,
              child: Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: _HeatmapPaintArea(
                    start: start,
                    weeks: weeks,
                    counts: counts,
                    maxCount: maxCount,
                    hoverOffset: activeOffset,
                    hoverPos: activeOffset != null ? _hoverPos : null,
                    surface: theme.colorScheme.surfaceContainerHighest,
                    primary: theme.colorScheme.primary,
                    outline: theme.colorScheme.onSurface,
                    inverseSurface: theme.colorScheme.inverseSurface,
                    onInverseSurface: theme.colorScheme.onInverseSurface,
                    onHoverChanged: (offset, pos) {
                      setState(() {
                        _hoverOffset = offset;
                        _hoverPos = pos;
                      });
                    },
                    onTap: (offset) {
                      setState(() {
                        _pinOffset = _pinOffset == offset ? null : offset;
                      });
                    },
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
                const Spacer(),
                Text(
                  _pinOffset != null ? 'Tap cell again to unpin' : 'Hover for details',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// MouseRegion + GestureDetector + CustomPaint for the heatmap grid. Hover
/// tooltip is positioned inside this Stack so it scrolls with the content.
class _HeatmapPaintArea extends StatelessWidget {
  const _HeatmapPaintArea({
    required this.start,
    required this.weeks,
    required this.counts,
    required this.maxCount,
    required this.hoverOffset,
    required this.hoverPos,
    required this.surface,
    required this.primary,
    required this.outline,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.onHoverChanged,
    required this.onTap,
  });

  final DateTime start;
  final int weeks;
  final Map<int, int> counts;
  final int maxCount;
  final int? hoverOffset;
  final Offset? hoverPos;
  final Color surface;
  final Color primary;
  final Color outline;
  final Color inverseSurface;
  final Color onInverseSurface;
  final void Function(int? offset, Offset? pos) onHoverChanged;
  final void Function(int offset) onTap;

  @override
  Widget build(BuildContext context) {
    final stride = ActivityHeatmap._rowStride;
    final gridWidth = weeks * stride;
    final gridHeight = 7 * stride;

    int? cellAt(Offset local) {
      final w = (local.dx / stride).floor();
      final d = (local.dy / stride).floor();
      if (w < 0 || w >= weeks || d < 0 || d >= 7) return null;
      return w * 7 + d;
    }

    return SizedBox(
      width: gridWidth,
      height: gridHeight + 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MouseRegion(
            onHover: (e) => onHoverChanged(cellAt(e.localPosition), e.localPosition),
            onExit: (_) => onHoverChanged(null, null),
            child: GestureDetector(
              onTapDown: (details) {
                final offset = cellAt(details.localPosition);
                if (offset != null) {
                  onTap(offset);
                  onHoverChanged(offset, details.localPosition);
                }
              },
              child: CustomPaint(
                size: Size(gridWidth, gridHeight),
                painter: _HeatmapPainter(
                  start: start,
                  weeks: weeks,
                  counts: counts,
                  maxCount: maxCount,
                  hoverOffset: hoverOffset,
                  surface: surface,
                  primary: primary,
                  outline: outline,
                ),
              ),
            ),
          ),
          if (hoverOffset != null && hoverPos != null)
            _tooltipPositioned(hoverOffset!, hoverPos!, gridWidth, gridHeight),
        ],
      ),
    );
  }

  Widget _tooltipPositioned(
    int offset,
    Offset pos,
    double gridWidth,
    double gridHeight,
  ) {
    final day = start.add(Duration(days: offset));
    final count = counts[offset] ?? 0;
    final dateStr = DateFormat('EEE, d MMM yyyy').format(day);
    final label = count == 0
        ? '$dateStr · no activity'
        : '$dateStr · $count ${count == 1 ? 'message' : 'messages'}';

    // Position the tooltip to the right of the cell when there's room;
    // otherwise flip it to the left.
    const tooltipW = 240.0;
    final preferRight = pos.dx + tooltipW + 16 < gridWidth;
    final left = preferRight ? pos.dx + 14 : pos.dx - tooltipW - 8;
    final top = pos.dy < gridHeight / 2 ? pos.dy + 14 : pos.dy - 36;

    return Positioned(
      left: left.clamp(0, gridWidth - tooltipW).toDouble(),
      top: top.clamp(0, gridHeight + 24).toDouble(),
      child: IgnorePointer(
        child: Container(
          constraints: const BoxConstraints(maxWidth: tooltipW),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: inverseSurface,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: onInverseSurface,
              fontSize: 12,
              height: 1.3,
            ),
          ),
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
    required this.hoverOffset,
    required this.surface,
    required this.primary,
    required this.outline,
  });

  final DateTime start;
  final int weeks;
  final Map<int, int> counts;
  final int maxCount;
  final int? hoverOffset;
  final Color surface;
  final Color primary;
  final Color outline;

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
        if (hoverOffset == offset) {
          final stroke = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = outline;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              rect.inflate(1),
              const Radius.circular(3),
            ),
            stroke,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) =>
      old.counts != counts ||
      old.weeks != weeks ||
      old.primary != primary ||
      old.surface != surface ||
      old.hoverOffset != hoverOffset;
}
