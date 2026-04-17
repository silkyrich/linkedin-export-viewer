import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/archive.dart';
import '../services/cache_service.dart';
import '../services/parse_service.dart';

final cacheServiceProvider = Provider<CacheService>((_) => CacheService());

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
  Future<LinkedInArchive?> build() async {
    // Auto-restore from the cache on app boot.
    try {
      final bytes = await ref.read(cacheServiceProvider).load();
      if (bytes == null) return null;
      return await parseArchive(bytes);
    } catch (_) {
      // A corrupted cache shouldn't block the app; just fall through.
      return null;
    }
  }

  /// Maximum size we'll parse without confirmation. Bigger archives work too
  /// but may freeze low-end mobile for a few seconds on the main thread.
  static const int largeArchiveThreshold = 50 * 1024 * 1024;

  /// Picks a zip and returns its bytes. Lets the UI confirm before we parse
  /// something unexpectedly huge.
  Future<Uint8List?> pickBytes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    return result?.files.single.bytes;
  }

  Future<void> loadFromPicker() async {
    final bytes = await pickBytes();
    if (bytes == null) return;
    await loadFromBytes(bytes, persist: true);
  }

  Future<void> loadFromAsset({
    String path = 'fixtures/sample_export.zip',
  }) async {
    final data = await rootBundle.load(path);
    await loadFromBytes(data.buffer.asUint8List(), persist: true);
  }

  Future<void> loadFromBytes(Uint8List bytes, {bool persist = false}) async {
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
      if (persist) {
        // Fire-and-forget; cache failures shouldn't surface as UI errors.
        unawaited(ref.read(cacheServiceProvider).save(bytes));
      }
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    } finally {
      ref.read(archiveProgressProvider.notifier).state = null;
    }
  }

  Future<void> clear() async {
    state = const AsyncValue<LinkedInArchive?>.data(null);
    ref.read(archiveProgressProvider.notifier).state = null;
    await ref.read(cacheServiceProvider).clear();
  }
}
