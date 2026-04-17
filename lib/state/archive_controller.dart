import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/archive.dart';
import '../services/parse_service.dart';

/// Lightweight progress signal exposed to UI while an archive is parsing.
@immutable
class ArchiveLoadProgress {
  const ArchiveLoadProgress({
    required this.currentPath,
    required this.done,
    required this.total,
  });

  final String currentPath;
  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : done / total;
}

final archiveProgressProvider = StateProvider<ArchiveLoadProgress?>((ref) => null);

final archiveControllerProvider =
    AsyncNotifierProvider<ArchiveController, LinkedInArchive?>(
  ArchiveController.new,
);

/// Owns the parsed LinkedIn archive for the lifetime of the session.
///
/// Three ways to load:
///   - `loadFromPicker()` — opens the file picker, user chooses a real zip.
///   - `loadFromAsset()` — loads the committed synthetic fixture (demo mode).
///   - `loadFromBytes(bytes)` — direct byte injection (used by tests and cache).
class ArchiveController extends AsyncNotifier<LinkedInArchive?> {
  @override
  Future<LinkedInArchive?> build() async => null;

  Future<void> loadFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    await loadFromBytes(bytes);
  }

  Future<void> loadFromAsset({
    String path = 'fixtures/sample_export.zip',
  }) async {
    final data = await rootBundle.load(path);
    await loadFromBytes(data.buffer.asUint8List());
  }

  Future<void> loadFromBytes(Uint8List bytes) async {
    state = const AsyncValue<LinkedInArchive?>.loading();
    try {
      final archive = await parseArchive(
        bytes,
        onProgress: (p) {
          ref.read(archiveProgressProvider.notifier).state = ArchiveLoadProgress(
            currentPath: p.path,
            done: p.done,
            total: p.total,
          );
        },
      );
      state = AsyncValue.data(archive);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    } finally {
      ref.read(archiveProgressProvider.notifier).state = null;
    }
  }

  void clear() {
    state = const AsyncValue<LinkedInArchive?>.data(null);
    ref.read(archiveProgressProvider.notifier).state = null;
  }
}
