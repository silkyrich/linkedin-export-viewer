import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../state/activity_index.dart';

/// GitHub-style activity grid — but broader than messages. Now aggregates
/// every dated thing in the archive (messages + likes + comments + shares +
/// applications + endorsements + invitations) and supports multiple
/// time granularities.
///
/// Hover any cell for a breakdown. Tap a cell to navigate to Messages
/// with the time range filter pre-applied.
class ActivityHeatmap extends ConsumerStatefulWidget {
  const ActivityHeatmap({super.key});

  @override
  ConsumerState<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

enum _Granularity { day, week, month, year }

extension on _Granularity {
  String get label => switch (this) {
        _Granularity.day => 'Day',
        _Granularity.week => 'Week',
        _Granularity.month => 'Month',
        _Granularity.year => 'Year',
      };

  /// Cell edge length in the grid, in logical pixels.
  double get cellSize => switch (this) {
        _Granularity.day => 10,
        _Granularity.week => 18,
        _Granularity.month => 32,
        _Granularity.year => 56,
      };

  double get cellGap => switch (this) {
        _Granularity.day => 2,
        _Granularity.week => 3,
        _Granularity.month => 4,
        _Granularity.year => 6,
      };
}

class _ActivityHeatmapState extends ConsumerState<ActivityHeatmap> {
  _Granularity _gran = _Granularity.day;
  _Bucket? _hoverBucket;
  Offset? _hoverPos;
  _Bucket? _pinBucket;

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(activityIndexProvider);
    if (index.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final start = DateTime.utc(
      index.minDate!.year,
      index.minDate!.month,
      index.minDate!.day,
    );
    final end = DateTime.utc(
      index.maxDate!.year,
      index.maxDate!.month,
      index.maxDate!.day,
    );

    final buckets = _makeBuckets(index, _gran, start, end);
    if (buckets.isEmpty) return const SizedBox.shrink();
    final maxCount = buckets.fold<int>(0, (m, b) => b.total > m ? b.total : m);
    final active = _pinBucket ?? _hoverBucket;

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
                  '${DateFormat.yMMM().format(start)} → ${DateFormat.yMMM().format(end)}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Messages, likes, comments, shares, applications, endorsements.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<_Granularity>(
              segments: [
                for (final g in _Granularity.values)
                  ButtonSegment(value: g, label: Text(g.label)),
              ],
              selected: {_gran},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _gran = s.first;
                _hoverBucket = null;
                _pinBucket = null;
              }),
            ),
            const SizedBox(height: 12),
            _HeatmapGrid(
              gran: _gran,
              buckets: buckets,
              maxCount: maxCount,
              hoverBucket: active,
              hoverPos: active != null ? _hoverPos : null,
              surface: theme.colorScheme.surfaceContainerHighest,
              primary: theme.colorScheme.primary,
              outline: theme.colorScheme.onSurface,
              inverseSurface: theme.colorScheme.inverseSurface,
              onInverseSurface: theme.colorScheme.onInverseSurface,
              onHover: (b, pos) => setState(() {
                _hoverBucket = b;
                _hoverPos = pos;
              }),
              onTap: (b) {
                setState(() => _pinBucket = _pinBucket == b ? null : b);
                _drillDown(context, b);
              },
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
                  'Tap a cell to view its messages',
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

  void _drillDown(BuildContext context, _Bucket b) {
    final from = _fmtDate(b.from);
    final to = _fmtDate(b.to);
    context.go('/messages?from=$from&to=$to');
  }
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One bucket in the grid — holds aggregated counts per kind for its range.
class _Bucket {
  _Bucket({
    required this.from,
    required this.to,
    required this.label,
    required this.column,
    required this.row,
    required this.total,
    required this.byKind,
  });
  final DateTime from;
  final DateTime to;
  final String label;
  final int column;
  final int row;
  final int total;
  final Map<ActivityKind, int> byKind;
}

List<_Bucket> _makeBuckets(
  ActivityIndex index,
  _Granularity gran,
  DateTime start,
  DateTime end,
) {
  switch (gran) {
    case _Granularity.day:
      return _dayBuckets(index, start, end);
    case _Granularity.week:
      return _weekBuckets(index, start, end);
    case _Granularity.month:
      return _monthBuckets(index, start, end);
    case _Granularity.year:
      return _yearBuckets(index, start, end);
  }
}

int _epochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

Map<ActivityKind, int> _mergeCounts(
  ActivityIndex index,
  DateTime fromInclusive,
  DateTime toInclusive,
) {
  final out = <ActivityKind, int>{};
  final firstEpoch = _epochDay(fromInclusive);
  final lastEpoch = _epochDay(toInclusive);
  for (var d = firstEpoch; d <= lastEpoch; d++) {
    final bucket = index.perDay[d];
    if (bucket == null) continue;
    for (final e in bucket.entries) {
      out[e.key] = (out[e.key] ?? 0) + e.value;
    }
  }
  return out;
}

int _sum(Map<ActivityKind, int> m) =>
    m.values.fold<int>(0, (a, b) => a + b);

List<_Bucket> _dayBuckets(ActivityIndex index, DateTime start, DateTime end) {
  // Anchor to the week of [start] so columns are whole weeks.
  final s = start.subtract(Duration(days: start.weekday % 7));
  final weeks = ((end.difference(s).inDays + 7) / 7).ceil();
  final out = <_Bucket>[];
  for (var w = 0; w < weeks; w++) {
    for (var d = 0; d < 7; d++) {
      final day = s.add(Duration(days: w * 7 + d));
      if (day.isBefore(start) || day.isAfter(end)) continue;
      final counts = _mergeCounts(index, day, day);
      final total = _sum(counts);
      out.add(_Bucket(
        from: day,
        to: day,
        label: DateFormat('EEE, d MMM yyyy').format(day),
        column: w,
        row: d,
        total: total,
        byKind: counts,
      ));
    }
  }
  return out;
}

List<_Bucket> _weekBuckets(ActivityIndex index, DateTime start, DateTime end) {
  // Week = Monday-Sunday, Flutter weekday is 1..7 (Mon..Sun).
  final firstMonday = start.subtract(Duration(days: start.weekday - 1));
  final totalWeeks = ((end.difference(firstMonday).inDays + 7) / 7).ceil();
  const rows = 5; // per column
  final out = <_Bucket>[];
  for (var w = 0; w < totalWeeks; w++) {
    final from = firstMonday.add(Duration(days: w * 7));
    final to = from.add(const Duration(days: 6));
    if (to.isBefore(start) || from.isAfter(end)) continue;
    final counts = _mergeCounts(index, from, to);
    out.add(_Bucket(
      from: from,
      to: to,
      label: 'Week of ${DateFormat('d MMM yyyy').format(from)}',
      column: w ~/ rows,
      row: w % rows,
      total: _sum(counts),
      byKind: counts,
    ));
  }
  return out;
}

List<_Bucket> _monthBuckets(ActivityIndex index, DateTime start, DateTime end) {
  final out = <_Bucket>[];
  final firstYear = start.year;
  final lastYear = end.year;
  for (var y = firstYear; y <= lastYear; y++) {
    for (var m = 1; m <= 12; m++) {
      final from = DateTime.utc(y, m, 1);
      final to = DateTime.utc(y, m + 1, 0); // day 0 = last day of prev month
      if (to.isBefore(start) || from.isAfter(end)) continue;
      final counts = _mergeCounts(index, from, to);
      out.add(_Bucket(
        from: from,
        to: to,
        label: DateFormat('MMMM yyyy').format(from),
        column: m - 1, // months as columns
        row: y - firstYear, // years as rows
        total: _sum(counts),
        byKind: counts,
      ));
    }
  }
  return out;
}

List<_Bucket> _yearBuckets(ActivityIndex index, DateTime start, DateTime end) {
  final out = <_Bucket>[];
  for (var y = start.year; y <= end.year; y++) {
    final from = DateTime.utc(y, 1, 1);
    final to = DateTime.utc(y, 12, 31);
    final counts = _mergeCounts(index, from, to);
    out.add(_Bucket(
      from: from,
      to: to,
      label: '$y',
      column: y - start.year,
      row: 0,
      total: _sum(counts),
      byKind: counts,
    ));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Rendering

class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({
    required this.gran,
    required this.buckets,
    required this.maxCount,
    required this.hoverBucket,
    required this.hoverPos,
    required this.surface,
    required this.primary,
    required this.outline,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.onHover,
    required this.onTap,
  });

  final _Granularity gran;
  final List<_Bucket> buckets;
  final int maxCount;
  final _Bucket? hoverBucket;
  final Offset? hoverPos;
  final Color surface;
  final Color primary;
  final Color outline;
  final Color inverseSurface;
  final Color onInverseSurface;
  final void Function(_Bucket? b, Offset? pos) onHover;
  final void Function(_Bucket b) onTap;

  @override
  Widget build(BuildContext context) {
    final stride = gran.cellSize + gran.cellGap;
    final maxCol = buckets.fold<int>(0, (m, b) => b.column > m ? b.column : m) + 1;
    final maxRow = buckets.fold<int>(0, (m, b) => b.row > m ? b.row : m) + 1;
    final width = maxCol * stride;
    final height = maxRow * stride;

    _Bucket? cellAt(Offset local) {
      final col = (local.dx / stride).floor();
      final row = (local.dy / stride).floor();
      for (final b in buckets) {
        if (b.column == col && b.row == row) return b;
      }
      return null;
    }

    return SizedBox(
      height: height + 18,
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: gran == _Granularity.day,
          child: SizedBox(
            width: width,
            height: height + 18,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                MouseRegion(
                  onHover: (e) => onHover(cellAt(e.localPosition), e.localPosition),
                  onExit: (_) => onHover(null, null),
                  child: GestureDetector(
                    onTapDown: (details) {
                      final b = cellAt(details.localPosition);
                      if (b != null) {
                        onTap(b);
                        onHover(b, details.localPosition);
                      }
                    },
                    child: CustomPaint(
                      size: Size(width, height),
                      painter: _GridPainter(
                        gran: gran,
                        buckets: buckets,
                        maxCount: maxCount,
                        hoverBucket: hoverBucket,
                        surface: surface,
                        primary: primary,
                        outline: outline,
                      ),
                    ),
                  ),
                ),
                if (hoverBucket != null && hoverPos != null)
                  _tooltipPositioned(
                    hoverBucket!,
                    hoverPos!,
                    width,
                    height,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tooltipPositioned(
    _Bucket b,
    Offset pos,
    double gridWidth,
    double gridHeight,
  ) {
    final parts = <String>[b.label];
    if (b.total == 0) {
      parts.add('no activity');
    } else {
      for (final e in _sorted(b.byKind)) {
        parts.add('${e.value} ${e.key.plural(e.value)}');
      }
    }
    const tooltipW = 280.0;
    final preferRight = pos.dx + tooltipW + 16 < gridWidth;
    final left = preferRight ? pos.dx + 14 : pos.dx - tooltipW - 8;
    final top = pos.dy < gridHeight / 2 ? pos.dy + 14 : pos.dy - 70;

    return Positioned(
      left: left.clamp(0, (gridWidth - tooltipW).clamp(0, double.infinity)).toDouble(),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                parts.first,
                style: TextStyle(
                  color: onInverseSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              for (final line in parts.skip(1))
                Text(
                  line,
                  style: TextStyle(
                    color: onInverseSurface,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Iterable<MapEntry<ActivityKind, int>> _sorted(Map<ActivityKind, int> m) {
    final list = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.gran,
    required this.buckets,
    required this.maxCount,
    required this.hoverBucket,
    required this.surface,
    required this.primary,
    required this.outline,
  });

  final _Granularity gran;
  final List<_Bucket> buckets;
  final int maxCount;
  final _Bucket? hoverBucket;
  final Color surface;
  final Color primary;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = gran.cellSize;
    final gap = gran.cellGap;
    final stride = cell + gap;
    final logMax = maxCount == 0 ? 1.0 : log(maxCount + 1);

    for (final b in buckets) {
      final intensity = b.total == 0
          ? 0.0
          : (log(b.total + 1) / logMax).clamp(0.1, 1.0);
      final color = b.total == 0 ? surface : Color.lerp(surface, primary, intensity)!;
      final rect = Rect.fromLTWH(
        b.column * stride,
        b.row * stride,
        cell,
        cell,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cell / 5)),
        Paint()..color = color,
      );
      if (b == hoverBucket) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.inflate(1.5),
            Radius.circular(cell / 4),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = outline,
        );
      }
      // Month/year cells get the count written inside.
      if (gran == _Granularity.month || gran == _Granularity.year) {
        if (b.total > 0) {
          final tp = TextPainter(
            text: TextSpan(
              text: gran == _Granularity.year
                  ? b.total.toString()
                  : _shortCount(b.total),
              style: TextStyle(
                color: intensity > 0.5
                    ? _contrastingColor(primary)
                    : _contrastingColor(surface),
                fontSize: gran == _Granularity.year ? 14 : 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            textDirection: ui.TextDirection.ltr,
            textAlign: TextAlign.center,
          )..layout(maxWidth: cell);
          tp.paint(
            canvas,
            Offset(
              b.column * stride + (cell - tp.width) / 2,
              b.row * stride + (cell - tp.height) / 2,
            ),
          );
        }
      }
    }
  }

  String _shortCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
    return n.toString();
  }

  Color _contrastingColor(Color bg) {
    // Rough luminance via sRGB components; good enough for chart labels.
    final r = ((bg.r) * 255).round();
    final g = ((bg.g) * 255).round();
    final b = ((bg.b) * 255).round();
    final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
    return lum > 0.6 ? Colors.black87 : Colors.white;
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.buckets != buckets ||
      old.gran != gran ||
      old.hoverBucket != hoverBucket ||
      old.primary != primary ||
      old.surface != surface;
}
