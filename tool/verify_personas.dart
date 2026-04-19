// Sanity-check script for the fixture generator: prints the top senders
// to Ada in messages.csv so we can verify the crafted personas dominate.
// Run: dart run tool/verify_personas.dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:csv/csv.dart';

void main() {
  final raw = File('fixtures/sample_export/messages.csv').readAsStringSync();
  final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(raw);
  final headers = rows.first.cast<String>();
  final fromIdx = headers.indexOf('FROM');
  final counts = <String, int>{};
  for (final r in rows.skip(1)) {
    final name = (fromIdx < r.length ? r[fromIdx] : '').toString();
    if (name.isEmpty || name == 'Ada Byron-Lovelace') continue;
    counts[name] = (counts[name] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  print('Top 15 correspondents (messages sent to Ada):');
  for (final e in sorted.take(15)) {
    print('  ${e.value.toString().padLeft(5)}  ${e.key}');
  }
}
