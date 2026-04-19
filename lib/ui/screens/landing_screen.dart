import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/archive_controller.dart';
import '../shell/dropzone_stub.dart'
    if (dart.library.js_interop) '../shell/dropzone_web.dart';

/// First screen a visitor sees. Offers two entry points:
///   1. Upload your own LinkedIn export zip.
///   2. Try the committed synthetic fixture (demo mode).
///
/// Both routes feed the same [ArchiveController.loadFromBytes] pipeline,
/// so everything downstream is identical.
class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final archiveState = ref.watch(archiveControllerProvider);

    final cs = theme.colorScheme;
    return Scaffold(
      body: DropZone(
        onDrop: (bytes, name) async {
          if (!context.mounted) return;
          final proceed = await _maybeConfirmLarge(context, bytes.length);
          if (!proceed) return;
          await ref
              .read(archiveControllerProvider.notifier)
              .loadFromBytes(bytes, persist: true);
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primaryContainer.withValues(alpha: 0.4),
                cs.surface,
                cs.tertiaryContainer.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          Icons.hub,
                          size: 40,
                          color: cs.onPrimary,
                        ),
                      ).asCenter(),
                      const SizedBox(height: 24),
                      Text(
                        'LinkedIn Export Viewer',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Browse everything LinkedIn has on you — privately, in this browser tab.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(icon: Icons.lock_outline, label: 'No upload'),
                          _Pill(icon: Icons.dns_outlined, label: 'No server'),
                          _Pill(icon: Icons.visibility_off_outlined, label: 'No tracking'),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _PickerTile(state: archiveState),
                      const SizedBox(height: 12),
                      _DemoTile(state: archiveState),
                      const SizedBox(height: 16),
                      Text(
                        'Tip: drop the zip anywhere on this page.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'How to get your export: linkedin.com → Me → Settings → '
                        'Data privacy → Get a copy of your data.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/about'),
                        child: const Text('About · MIT License'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

extension on Widget {
  Widget asCenter() => Align(alignment: Alignment.center, child: this);
}

Future<bool> _maybeConfirmLarge(BuildContext context, int byteLength) async {
  if (byteLength <= ArchiveController.largeArchiveThreshold) return true;
  final mib = (byteLength / (1024 * 1024)).toStringAsFixed(1);
  final proceed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Large archive'),
      content: Text(
        'This zip is $mib MB. Parsing it will stay in your browser but '
        'may freeze the tab for a few seconds on a phone. Continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return proceed == true;
}

class _PickerTile extends ConsumerWidget {
  const _PickerTile({required this.state});
  final AsyncValue<Object?> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = state.isLoading;
    return FilledButton.icon(
      onPressed: busy ? null : () => _pickAndLoad(context, ref),
      icon: const Icon(Icons.file_upload_outlined),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(busy ? 'Parsing...' : 'Upload your LinkedIn zip'),
      ),
    );
  }

  Future<void> _pickAndLoad(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(archiveControllerProvider.notifier);
    final bytes = await controller.pickBytes();
    if (bytes == null) return;
    if (!context.mounted) return;
    if (bytes.length > ArchiveController.largeArchiveThreshold) {
      final mib = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Large archive'),
          content: Text(
            'This zip is $mib MB. Parsing it will stay in your browser but '
            'may freeze the tab for a few seconds on a phone. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    await controller.loadFromBytes(bytes, persist: true);
  }
}

class _DemoTile extends ConsumerWidget {
  const _DemoTile({required this.state});
  final AsyncValue<Object?> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = state.isLoading;
    return OutlinedButton.icon(
      onPressed: busy
          ? null
          : () =>
              ref.read(archiveControllerProvider.notifier).loadFromAsset(),
      icon: const Icon(Icons.auto_awesome_outlined),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(busy ? 'Parsing demo data...' : 'Try with sample data'),
      ),
    );
  }
}
