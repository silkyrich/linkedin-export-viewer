import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/archive_controller.dart';
import '../../state/theme_controller.dart';
import '../widgets/linkedout_logo.dart';

/// Visible reassurance that nothing leaves the browser — but a light one.
///
/// The first iteration of this banner was a full sentence + four buttons,
/// which ate roughly 60 px of every screen's vertical real estate. This
/// version is a single 44 px strip: a lock icon, a short label that
/// collapses to just the icon below 500 px, and four icon-only actions.
/// "Clear data" was a fat text button; now it's an icon with a confirm
/// dialog so we don't accidentally wipe on misclick.
class PrivacyBanner extends ConsumerWidget {
  const PrivacyBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasArchive = ref.watch(
      archiveControllerProvider.select((s) => s.valueOrNull != null),
    );
    if (!hasArchive) return const SizedBox.shrink();
    final onBg = theme.colorScheme.onSecondaryContainer;

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxWidth < 500;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => context.go('/about'),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: LinkedOutLogo(size: 24),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.lock_outline, size: 14, color: onBg),
                const SizedBox(width: 6),
                if (!tight)
                  Expanded(
                    child: Text(
                      'Private. Stays in this tab.',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: onBg,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                _BannerIconButton(
                  tooltip: 'Search everything',
                  icon: Icons.search,
                  onPressed: () => context.go('/search'),
                ),
                _BannerIconButton(
                  tooltip: 'About',
                  icon: Icons.info_outline,
                  onPressed: () => context.go('/about'),
                ),
                const _ThemeToggle(),
                _BannerIconButton(
                  tooltip: 'Clear data (wipe the cached archive)',
                  icon: Icons.delete_sweep_outlined,
                  onPressed: () => _confirmClear(context, ref),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear archive?'),
        content: const Text(
          'This removes the cached zip from this browser. You\'ll need '
          'to upload it again (or use the demo data) next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(archiveControllerProvider.notifier).clear();
    }
  }
}

/// Compact icon button with lighter padding than IconButton's default so
/// the banner stays short on mobile.
class _BannerIconButton extends StatelessWidget {
  const _BannerIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: onPressed,
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

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
    return _BannerIconButton(
      tooltip: '$tooltip (tap to cycle)',
      icon: icon,
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}
