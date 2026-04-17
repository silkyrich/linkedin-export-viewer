import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/archive.dart';
import '../../models/parsed_file.dart';
import '../../state/archive_controller.dart';
import '../widgets/kv_card.dart';

/// "Me" — single-record data LinkedIn holds about the viewer:
/// Profile, Profile Summary, Registration, Email Addresses, PhoneNumbers,
/// Languages, Whatsapp Phone Numbers.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archive = ref.watch(archiveControllerProvider).valueOrNull;
    if (archive == null) {
      return const Center(child: Text('No archive loaded.'));
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _singleRowCard(archive, 'Profile.csv', 'Profile'),
        _singleRowCard(archive, 'Profile Summary.csv', 'Profile Summary'),
        _singleRowCard(archive, 'Registration.csv', 'Registration'),
        _multiRowCard(archive, 'Email Addresses.csv', 'Email Addresses'),
        _multiRowCard(archive, 'PhoneNumbers.csv', 'Phone Numbers'),
        _multiRowCard(archive, 'Whatsapp Phone Numbers.csv', 'WhatsApp'),
        _multiRowCard(archive, 'Languages.csv', 'Languages'),
      ],
    );
  }
}

Widget _singleRowCard(LinkedInArchive archive, String path, String title) {
  final file = archive.file(path);
  if (file == null || file.rows.isEmpty) return const SizedBox.shrink();
  return KvCard(
    title: title,
    entries: _pairHeaders(file, file.rows.first),
  );
}

Widget _multiRowCard(LinkedInArchive archive, String path, String title) {
  final file = archive.file(path);
  if (file == null || file.rows.isEmpty) return const SizedBox.shrink();
  if (file.rows.length == 1) {
    return KvCard(title: title, entries: _pairHeaders(file, file.rows.first));
  }
  // Multiple rows → render each as its own mini-section inside one card.
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          for (var i = 0; i < file.rows.length; i++) ...[
            if (i > 0) const Divider(height: 24),
            _RowList(entries: _pairHeaders(file, file.rows[i])),
          ],
        ],
      ),
    ),
  );
}

List<MapEntry<String, String>> _pairHeaders(ParsedFile file, List<String> row) {
  final out = <MapEntry<String, String>>[];
  for (var i = 0; i < file.headers.length; i++) {
    out.add(MapEntry(file.headers[i], i < row.length ? row[i] : ''));
  }
  return out;
}

class _RowList extends StatelessWidget {
  const _RowList({required this.entries});

  final List<MapEntry<String, String>> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = entries.where((e) => e.value.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '${e.key}: ',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextSpan(text: e.value),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
