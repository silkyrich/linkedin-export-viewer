import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/archive_controller.dart';
import '../../state/theme_controller.dart';

/// Visible reassurance that nothing leaves the browser.
///
/// Displayed at the top of every screen when an archive is loaded.
class _ThemeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final icon = switch (mode) {
      ThemeMode.system => Icons.brightness_auto_outlined,
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
    };
    final tooltip = switch (mode) {
      ThemeMode.system => 'Theme: system',
      ThemeMode.light => 'Theme: light',
      ThemeMode.dark => 'Theme: dark',
    };
    return IconButton(
      tooltip: '$tooltip (tap to cycle)',
      icon: Icon(icon),
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}

class PrivacyBanner extends ConsumerWidget {
  const PrivacyBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasArchive = ref.watch(
      archiveControllerProvider.select((s) => s.valueOrNull != null),
    );
    if (!hasArchive) return const SizedBox.shrink();
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 18, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Your data stays in this browser tab. Nothing uploaded.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Search everything',
              icon: const Icon(Icons.search),
              onPressed: () => context.go('/search'),
            ),
            IconButton(
              tooltip: 'About',
              icon: const Icon(Icons.info_outline),
              onPressed: () => context.go('/about'),
            ),
            _ThemeToggle(),
            TextButton(
              onPressed: () =>
                  ref.read(archiveControllerProvider.notifier).clear(),
              child: const Text('Clear data'),
            ),
          ],
        ),
      ),
    );
  }
}
