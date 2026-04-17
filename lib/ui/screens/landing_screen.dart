import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/archive_controller.dart';

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
      body: SafeArea(
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
                  const SizedBox(height: 32),
                  Text(
                    'How to get your export: linkedin.com → Me → Settings → '
                    'Data privacy → Get a copy of your data.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends ConsumerWidget {
  const _PickerTile({required this.state});
  final AsyncValue<Object?> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = state.isLoading;
    return FilledButton.icon(
      onPressed: busy
          ? null
          : () =>
              ref.read(archiveControllerProvider.notifier).loadFromPicker(),
      icon: const Icon(Icons.file_upload_outlined),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(busy ? 'Parsing...' : 'Upload your LinkedIn zip'),
      ),
    );
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
