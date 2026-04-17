import 'package:flutter/foundation.dart';

/// A single CSV (or HTML blob) extracted from a LinkedIn export zip.
///
/// [path] is the path inside the zip (e.g. `Profile.csv`, `Jobs/Saved Jobs.csv`).
/// [headers] is the column header row for CSVs; empty for non-CSV files.
/// [rows] is the data rows, already parsed. Fields are kept as [String] so
/// downstream screens can format them without losing information (`shouldParseNumbers: false`
/// on the CSV parser). For Articles/*.html, [rawBytes] holds the raw file contents
/// and [rows]/[headers] are empty.
@immutable
class ParsedFile {
  const ParsedFile({
    required this.path,
    required this.headers,
    required this.rows,
    this.rawBytes,
    this.warnings = const [],
  });

  final String path;
  final List<String> headers;
  final List<List<String>> rows;
  final List<int>? rawBytes;
  final List<String> warnings;

  bool get isEmpty => rows.isEmpty && (rawBytes?.isEmpty ?? true);
}
