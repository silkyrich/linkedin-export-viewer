import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';

import '../models/archive.dart';
import '../models/entities/message.dart';
import '../models/parsed_file.dart';

/// Per-file progress reported while parsing.
class ParseProgress {
  const ParseProgress({required this.path, required this.done, required this.total});
  final String path;
  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : done / total;
}

typedef ParseProgressCallback = void Function(ParseProgress progress);

/// Decodes a LinkedIn export zip entirely in-process.
///
/// Runs on whatever isolate/worker it's called from. On Flutter web that's the
/// main thread, so we yield between files with `await Future<void>.delayed(...)`
/// to keep the UI responsive. A real Web Worker upgrade is scheduled for later
/// in Phase 1 (see docs/PLAN.md).
Future<LinkedInArchive> parseArchive(
  Uint8List zipBytes, {
  ParseProgressCallback? onProgress,
}) async {
  final archive = ZipDecoder().decodeBytes(zipBytes);

  // Sort so progress updates arrive in a predictable order regardless of
  // the zip's internal file order.
  final entries = archive.files.where((f) => f.isFile).toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  final files = <String, ParsedFile>{};
  final messages = <Message>[];
  final messagesByConversation = <String, List<int>>{};

  final total = entries.length;
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final path = entry.name;
    onProgress?.call(ParseProgress(path: path, done: i, total: total));

    final bytes = entry.content as List<int>;
    if (path.toLowerCase().endsWith('.csv')) {
      final parsed = _parseCsvFile(path, bytes);
      files[path] = parsed;
      if (path == 'messages.csv') {
        for (final row in parsed.rows) {
          final m = Message.fromCsvRow(row);
          if (m == null) continue;
          messagesByConversation
              .putIfAbsent(m.conversationId, () => <int>[])
              .add(messages.length);
          messages.add(m);
        }
      }
    } else {
      // Non-CSV (Articles/*.html etc.) — keep the raw bytes so the
      // Articles viewer can render them later.
      files[path] = ParsedFile(
        path: path,
        headers: const [],
        rows: const [],
        rawBytes: bytes,
      );
    }

    // Yield back to the event loop so the UI doesn't freeze during a
    // long parse on the main thread.
    await Future<void>.delayed(Duration.zero);
  }

  onProgress?.call(ParseProgress(path: '', done: total, total: total));

  return LinkedInArchive(
    files: files,
    messages: messages,
    messagesByConversation: messagesByConversation,
  );
}

ParsedFile _parseCsvFile(String path, List<int> bytes) {
  final text = utf8.decode(bytes, allowMalformed: true);
  // Connections.csv starts with a "Notes:" preamble and a quoted paragraph
  // before the real column header. Skip those so downstream code sees a
  // regular CSV.
  final cleaned = path == 'Connections.csv' ? _stripConnectionsPreamble(text) : text;

  final rows = const CsvToListConverter(
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(cleaned);

  if (rows.isEmpty) {
    return ParsedFile(path: path, headers: const [], rows: const []);
  }

  final headers = rows.first.map((e) => e.toString()).toList();
  final dataRows = rows
      .skip(1)
      .map((r) => r.map((e) => e.toString()).toList())
      .toList();

  return ParsedFile(path: path, headers: headers, rows: dataRows);
}

String _stripConnectionsPreamble(String text) {
  final lines = const LineSplitter().convert(text);
  final headerIndex = lines.indexWhere(
    (l) => l.startsWith('First Name,Last Name,URL,'),
  );
  if (headerIndex == -1) return text;
  return lines.sublist(headerIndex).join('\n');
}
