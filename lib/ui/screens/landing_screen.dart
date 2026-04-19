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
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'LinkedIn Export Viewer',
                      style: theme.textTheme.displaySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Drop the zip LinkedIn emailed you. Everything stays in '
                      'this browser tab — no server, no upload, no tracking.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _PickerTile(state: archiveState),
                    const SizedBox(height: 16),
                    _DemoTile(state: archiveState),
                    const SizedBox(height: 16),
                    Text(
                      'Tip: drop the zip anywhere on this page.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'How to get your export: linkedin.com → Me → Settings → '
                      'Data privacy → Get a copy of your data.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
    );
  }
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
