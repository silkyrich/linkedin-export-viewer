import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/archive_controller.dart';

class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(archiveProgressProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Parsing your archive', style: theme.textTheme.titleLarge),
                const SizedBox(height: 24),
                LinearProgressIndicator(value: progress?.fraction),
                const SizedBox(height: 12),
                Text(
                  progress == null
                      ? 'Starting...'
                      : '${progress.done}/${progress.total} — ${progress.currentPath.isEmpty ? 'finishing' : progress.currentPath}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
