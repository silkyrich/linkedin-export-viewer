import 'package:flutter/foundation.dart';
import 'package:idb_shim/idb_browser.dart';

/// IndexedDB-backed cache for the raw uploaded zip bytes.
///
/// We store the bytes (not the parsed archive) so model changes don't
/// invalidate the cache and we can re-run parsing with new schema handling.
class CacheService {
  CacheService({IdbFactory? factory}) : _factory = factory ?? _defaultFactory();

  static IdbFactory _defaultFactory() {
    if (kIsWeb) return idbFactoryBrowser;
    // Non-web (tests, desktop) — use an in-memory factory so the
    // same code path exercises without touching the file system.
    return idbFactoryMemoryFs;
  }

  static const _dbName = 'linkedin_export_viewer';
  static const _store = 'archive_v1';
  static const _key = 'current';

  final IdbFactory _factory;

  Future<Database> _open() async {
    return _factory.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (e) {
        final db = e.database;
        if (!db.objectStoreNames.contains(_store)) {
          db.createObjectStore(_store);
        }
      },
    );
  }

  Future<void> save(Uint8List bytes) async {
    final db = await _open();
    try {
      final txn = db.transaction(_store, idbModeReadWrite);
      await txn.objectStore(_store).put(bytes, _key);
      await txn.completed;
    } finally {
      db.close();
    }
  }

  Future<Uint8List?> load() async {
    final db = await _open();
    try {
      final txn = db.transaction(_store, idbModeReadOnly);
      final result = await txn.objectStore(_store).getObject(_key);
      await txn.completed;
      if (result is Uint8List) return result;
      if (result is List<int>) return Uint8List.fromList(result);
      return null;
    } finally {
      db.close();
    }
  }

  Future<void> clear() async {
    final db = await _open();
    try {
      final txn = db.transaction(_store, idbModeReadWrite);
      await txn.objectStore(_store).delete(_key);
      await txn.completed;
    } finally {
      db.close();
    }
  }
}
