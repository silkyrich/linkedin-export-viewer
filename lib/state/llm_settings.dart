import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idb_shim/idb_browser.dart';

/// Providers we can talk to directly from the browser. Each of these has
/// documented support for browser-origin requests when the user supplies
/// their own API key — no backend, no proxy.
enum LlmProvider { openai, anthropic, gemini, ollama }

extension LlmProviderMeta on LlmProvider {
  String get label => switch (this) {
        LlmProvider.openai => 'OpenAI',
        LlmProvider.anthropic => 'Anthropic',
        LlmProvider.gemini => 'Google Gemini',
        LlmProvider.ollama => 'Ollama (local)',
      };

  bool get requiresKey => this != LlmProvider.ollama;

  /// Sensible defaults; the user can override.
  List<String> get models => switch (this) {
        LlmProvider.openai => const [
            'gpt-4o-mini',
            'gpt-4o',
            'gpt-4.1',
            'o4-mini',
          ],
        LlmProvider.anthropic => const [
            'claude-haiku-4-5-20251001',
            'claude-sonnet-4-5',
            'claude-opus-4-5',
            'claude-3-5-sonnet-20241022',
          ],
        LlmProvider.gemini => const [
            'gemini-2.5-flash',
            'gemini-2.5-pro',
            'gemini-1.5-flash',
            'gemini-1.5-pro',
          ],
        LlmProvider.ollama => const [
            'llama3.2',
            'qwen2.5',
            'mistral',
            'gemma2',
          ],
      };

  String get defaultModel => models.first;

  /// Key-field hint text for the UI.
  String get keyHint => switch (this) {
        LlmProvider.openai => 'sk-...',
        LlmProvider.anthropic => 'sk-ant-...',
        LlmProvider.gemini => 'AIza...',
        LlmProvider.ollama => 'Not required',
      };
}

@immutable
class LlmSettings {
  const LlmSettings({
    this.provider = LlmProvider.openai,
    this.model = 'gpt-4o-mini',
    this.apiKey = '',
    this.ollamaBaseUrl = 'http://localhost:11434',
    this.rememberKey = false,
  });

  final LlmProvider provider;
  final String model;
  final String apiKey;
  final String ollamaBaseUrl;
  final bool rememberKey;

  LlmSettings copyWith({
    LlmProvider? provider,
    String? model,
    String? apiKey,
    String? ollamaBaseUrl,
    bool? rememberKey,
  }) =>
      LlmSettings(
        provider: provider ?? this.provider,
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
        ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
        rememberKey: rememberKey ?? this.rememberKey,
      );

  Map<String, Object?> toJson() => {
        'provider': provider.name,
        'model': model,
        'apiKey': rememberKey ? apiKey : '',
        'ollamaBaseUrl': ollamaBaseUrl,
        'rememberKey': rememberKey,
      };

  static LlmSettings fromJson(Map<String, Object?> m) {
    final provName = (m['provider'] as String?) ?? LlmProvider.openai.name;
    final prov = LlmProvider.values.firstWhere(
      (p) => p.name == provName,
      orElse: () => LlmProvider.openai,
    );
    return LlmSettings(
      provider: prov,
      model: (m['model'] as String?) ?? prov.defaultModel,
      apiKey: (m['apiKey'] as String?) ?? '',
      ollamaBaseUrl:
          (m['ollamaBaseUrl'] as String?) ?? 'http://localhost:11434',
      rememberKey: (m['rememberKey'] as bool?) ?? false,
    );
  }
}

/// Small IndexedDB table dedicated to LLM settings so wiping the archive
/// cache ("Clear data") doesn't also wipe the user's provider/model pick.
class _LlmStore {
  static const _dbName = 'linkedin_export_viewer';
  static const _store = 'llm_settings_v1';
  static const _key = 'current';

  Future<Database> _open() async {
    return idbFactoryBrowser.open(
      _dbName,
      version: 2,
      onUpgradeNeeded: (e) {
        final db = e.database;
        if (!db.objectStoreNames.contains(_store)) {
          db.createObjectStore(_store);
        }
        // archive_v1 store (created in cache_service.dart) stays untouched.
        if (!db.objectStoreNames.contains('archive_v1')) {
          db.createObjectStore('archive_v1');
        }
      },
    );
  }

  Future<LlmSettings?> load() async {
    if (!kIsWeb) return null;
    try {
      final db = await _open();
      try {
        final txn = db.transaction(_store, idbModeReadOnly);
        final raw = await txn.objectStore(_store).getObject(_key);
        await txn.completed;
        if (raw is Map) {
          return LlmSettings.fromJson(raw.cast<String, Object?>());
        }
        return null;
      } finally {
        db.close();
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> save(LlmSettings s) async {
    if (!kIsWeb) return;
    try {
      final db = await _open();
      try {
        final txn = db.transaction(_store, idbModeReadWrite);
        await txn.objectStore(_store).put(s.toJson(), _key);
        await txn.completed;
      } finally {
        db.close();
      }
    } catch (_) {}
  }

  Future<void> clear() async {
    if (!kIsWeb) return;
    try {
      final db = await _open();
      try {
        final txn = db.transaction(_store, idbModeReadWrite);
        await txn.objectStore(_store).delete(_key);
        await txn.completed;
      } finally {
        db.close();
      }
    } catch (_) {}
  }
}

final llmSettingsProvider =
    NotifierProvider<LlmSettingsController, LlmSettings>(LlmSettingsController.new);

class LlmSettingsController extends Notifier<LlmSettings> {
  final _store = _LlmStore();

  @override
  LlmSettings build() {
    // Hydrate from IndexedDB asynchronously; emit defaults first.
    _store.load().then((loaded) {
      if (loaded != null) state = loaded;
    });
    return const LlmSettings();
  }

  void setProvider(LlmProvider p) {
    state = state.copyWith(provider: p, model: p.defaultModel);
    _persist();
  }

  void setModel(String m) {
    state = state.copyWith(model: m);
    _persist();
  }

  void setApiKey(String k) {
    state = state.copyWith(apiKey: k);
    _persist();
  }

  void setRememberKey(bool r) {
    state = state.copyWith(rememberKey: r);
    _persist();
  }

  void setOllamaBaseUrl(String u) {
    state = state.copyWith(ollamaBaseUrl: u);
    _persist();
  }

  Future<void> clear() async {
    state = const LlmSettings();
    await _store.clear();
  }

  void _persist() {
    // Only persist non-key fields unless rememberKey is on (handled in toJson).
    _store.save(state);
  }
}
