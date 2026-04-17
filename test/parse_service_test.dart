import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:linkedin_export_viewer/services/parse_service.dart';

void main() {
  late Uint8List zipBytes;

  setUpAll(() {
    zipBytes = File('fixtures/sample_export.zip').readAsBytesSync();
  });

  test('parses the synthetic export end-to-end', () async {
    final archive = await parseArchive(zipBytes);

    // Core files present.
    expect(archive.file('Profile.csv'), isNotNull);
    expect(archive.file('messages.csv'), isNotNull);
    expect(archive.file('Connections.csv'), isNotNull);

    // Profile has one row.
    expect(archive.file('Profile.csv')!.rows, hasLength(1));

    // Messages decoded into typed model.
    expect(archive.messageCount, greaterThan(15000));
    expect(archive.conversationCount, greaterThan(10));

    // Connections preamble was skipped — header row exposes the real columns.
    final connections = archive.file('Connections.csv')!;
    expect(connections.headers.first, 'First Name');
    expect(connections.rows.length, greaterThan(1500));

    // Articles kept as raw bytes.
    final article = archive.files.entries
        .firstWhere((e) => e.key.startsWith('Articles/Articles/') && e.key.endsWith('.html'));
    expect(article.value.rawBytes, isNotNull);
    expect(article.value.rawBytes!.isNotEmpty, isTrue);
  });

  test('reports progress for every file', () async {
    final seen = <String>{};
    await parseArchive(zipBytes, onProgress: (p) => seen.add(p.path));
    // At least one CSV per expected category.
    expect(seen, contains('Profile.csv'));
    expect(seen, contains('messages.csv'));
  });

  test('messages link back to their conversation index', () async {
    final archive = await parseArchive(zipBytes);
    final firstConvoId = archive.messagesByConversation.keys.first;
    final indices = archive.messagesByConversation[firstConvoId]!;
    expect(indices, isNotEmpty);
    for (final i in indices) {
      expect(archive.messages[i].conversationId, firstConvoId);
    }
  });
}
