import 'dart:convert';

import 'package:http/http.dart' as http;

import '../state/llm_settings.dart';

/// Thin provider-agnostic chat wrapper. Each method is a direct
/// browser-origin call to the provider's public API; no backend, no
/// proxy. The user supplies the key.
class LlmClient {
  /// Sends a single system+user turn and returns the full assistant
  /// response as a plain string. Throws [LlmError] with a human-readable
  /// message on failure.
  static Future<String> chat({
    required LlmSettings settings,
    required String system,
    required String user,
    int maxTokens = 2000,
  }) async {
    try {
      return switch (settings.provider) {
        LlmProvider.openai => await _openai(settings, system, user, maxTokens),
        LlmProvider.anthropic => await _anthropic(settings, system, user, maxTokens),
        LlmProvider.gemini => await _gemini(settings, system, user, maxTokens),
        LlmProvider.ollama => await _ollama(settings, system, user, maxTokens),
      };
    } on LlmError {
      rethrow;
    } catch (e) {
      throw LlmError('Network error: $e');
    }
  }

  static Future<String> _openai(
    LlmSettings s,
    String system,
    String user,
    int maxTokens,
  ) async {
    final resp = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${s.apiKey}',
      },
      body: jsonEncode({
        'model': s.model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        'max_tokens': maxTokens,
      }),
    );
    if (resp.statusCode >= 400) throw _parseError(resp);
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    final content = choices?.first?['message']?['content'] as String?;
    if (content == null) throw const LlmError('OpenAI returned empty response.');
    return content;
  }

  static Future<String> _anthropic(
    LlmSettings s,
    String system,
    String user,
    int maxTokens,
  ) async {
    final resp = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': s.apiKey,
        'anthropic-version': '2023-06-01',
        // Required for browser-origin requests.
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: jsonEncode({
        'model': s.model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user},
        ],
      }),
    );
    if (resp.statusCode >= 400) throw _parseError(resp);
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = json['content'] as List?;
    if (content == null || content.isEmpty) {
      throw const LlmError('Anthropic returned empty response.');
    }
    final buf = StringBuffer();
    for (final block in content) {
      if (block is Map && block['type'] == 'text') {
        buf.write(block['text']);
      }
    }
    final text = buf.toString();
    if (text.isEmpty) throw const LlmError('Anthropic returned no text blocks.');
    return text;
  }

  static Future<String> _gemini(
    LlmSettings s,
    String system,
    String user,
    int maxTokens,
  ) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${s.model}:generateContent?key=${s.apiKey}',
    );
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': user},
            ],
          },
        ],
        'generationConfig': {'maxOutputTokens': maxTokens},
      }),
    );
    if (resp.statusCode >= 400) throw _parseError(resp);
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    final parts = candidates?.first?['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw const LlmError('Gemini returned empty response.');
    }
    final buf = StringBuffer();
    for (final p in parts) {
      if (p is Map && p['text'] != null) buf.write(p['text']);
    }
    return buf.toString();
  }

  static Future<String> _ollama(
    LlmSettings s,
    String system,
    String user,
    int maxTokens,
  ) async {
    final base = s.ollamaBaseUrl.trim().isEmpty
        ? 'http://localhost:11434'
        : s.ollamaBaseUrl.trim();
    final resp = await http.post(
      Uri.parse('$base/api/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': s.model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        'stream': false,
        'options': {'num_predict': maxTokens},
      }),
    );
    if (resp.statusCode >= 400) throw _parseError(resp);
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = json['message']?['content'] as String?;
    if (content == null) throw const LlmError('Ollama returned empty response.');
    return content;
  }

  static LlmError _parseError(http.Response r) {
    try {
      final body = jsonDecode(r.body);
      if (body is Map) {
        final err = body['error'];
        if (err is Map && err['message'] is String) {
          return LlmError('${r.statusCode}: ${err['message']}');
        }
        if (err is String) return LlmError('${r.statusCode}: $err');
      }
      return LlmError('${r.statusCode}: ${r.body}');
    } catch (_) {
      return LlmError('HTTP ${r.statusCode}');
    }
  }
}

class LlmError implements Exception {
  const LlmError(this.message);
  final String message;
  @override
  String toString() => message;
}
