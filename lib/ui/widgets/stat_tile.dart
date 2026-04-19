import 'package:flutter/material.dart';

/// One compact "big number + label" tile. Used in roll-up cards across
/// Insights, Career, Account, etc.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.hint,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 140, minHeight: 82),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
