import 'package:flutter/material.dart';

/// A simple key-value list rendered as a card. Used by the single-record
/// screens (Profile, Registration, Verifications) where the export has
/// one row with many named fields.
class KvCard extends StatelessWidget {
  const KvCard({
    required this.title,
    required this.entries,
    super.key,
  });

  final String title;
  final List<MapEntry<String, String>> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = entries.where((e) => e.value.trim().isNotEmpty).toList();
    if (shown.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final e in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.key,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      e.value,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
