import 'package:flutter/material.dart';

/// A lean horizontal / vertical bar chart for simple label→value datasets.
/// Vertical layout by default, flips to horizontal when caller passes
/// [horizontal] true (useful for categorical labels that don't fit
/// under narrow vertical bars).
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    required this.data,
    this.horizontal = false,
    this.height = 140,
    this.valueFormatter,
    super.key,
  });

  final List<(String label, num value)> data;
  final bool horizontal;
  final double height;
  final String Function(num)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return const SizedBox.shrink();
    final maxV = data.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    return horizontal
        ? _horizontal(theme, maxV)
        : _vertical(theme, maxV);
  }

  Widget _vertical(ThemeData theme, num maxV) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (ctx, c) {
          final cols = data.length;
          final colWidth = c.maxWidth / cols;
          return Stack(
            children: [
              for (var i = 0; i < data.length; i++)
                Positioned(
                  left: i * colWidth,
                  bottom: 22,
                  width: colWidth,
                  height: c.maxHeight - 22,
                  child: _VerticalBar(
                    label: data[i].$1,
                    value: data[i].$2,
                    max: maxV,
                    colour: theme.colorScheme.primary,
                    valueFormatter: valueFormatter,
                  ),
                ),
              for (var i = 0; i < data.length; i++)
                Positioned(
                  left: i * colWidth,
                  bottom: 0,
                  width: colWidth,
                  height: 18,
                  child: Center(
                    child: Text(
                      data[i].$1,
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _horizontal(ThemeData theme, num maxV) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, v) in data)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, c) {
                      final w = (v / maxV) * c.maxWidth;
                      return Stack(
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          Container(
                            width: w.toDouble().clamp(4.0, c.maxWidth),
                            height: 10,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text(
                    valueFormatter == null
                        ? v.toString()
                        : valueFormatter!(v),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VerticalBar extends StatelessWidget {
  const _VerticalBar({
    required this.label,
    required this.value,
    required this.max,
    required this.colour,
    required this.valueFormatter,
  });
  final String label;
  final num value;
  final num max;
  final Color colour;
  final String Function(num)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (ctx, c) {
        final h = (value / max) * (c.maxHeight - 18);
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              valueFormatter == null ? value.toString() : valueFormatter!(value),
              style: theme.textTheme.labelSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 14,
              height: h.toDouble().clamp(2.0, c.maxHeight - 18),
              decoration: BoxDecoration(
                color: colour,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          ],
        );
      },
    );
  }
}
