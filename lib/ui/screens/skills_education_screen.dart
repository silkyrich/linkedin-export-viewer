import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/archive.dart';
import '../../state/archive_controller.dart';
import '../widgets/kv_card.dart';

class SkillsEducationScreen extends ConsumerWidget {
  const SkillsEducationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archive = ref.watch(archiveControllerProvider).valueOrNull;
    if (archive == null) {
      return const Center(child: Text('No archive loaded.'));
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _skillsCard(archive, theme),
        ..._educationCards(archive),
        _verificationCard(archive),
      ],
    );
  }
}

Widget _skillsCard(LinkedInArchive archive, ThemeData theme) {
  final file = archive.file('Skills.csv');
  if (file == null || file.rows.isEmpty) return const SizedBox.shrink();
  final skills = file.rows
      .map((r) => r.isNotEmpty ? r.first : '')
      .where((s) => s.trim().isNotEmpty)
      .toList();
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Skills (${skills.length})', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final s in skills) Chip(label: Text(s))],
          ),
        ],
      ),
    ),
  );
}

List<Widget> _educationCards(LinkedInArchive archive) {
  final file = archive.file('Education.csv');
  if (file == null) return const [];
  final cards = <Widget>[];
  for (final row in file.rows) {
    String field(String k) {
      final idx = file.headers.indexOf(k);
      return (idx == -1 || idx >= row.length) ? '' : row[idx];
    }

    final school = field('School Name');
    if (school.isEmpty) continue;
    cards.add(KvCard(
      title: school,
      entries: [
        MapEntry('Degree', field('Degree Name')),
        MapEntry('Dates', '${field('Start Date')} – ${field('End Date')}'),
        MapEntry('Notes', field('Notes')),
        MapEntry('Activities', field('Activities')),
      ],
    ));
  }
  return cards;
}

Widget _verificationCard(LinkedInArchive archive) {
  final file = archive.file('Verifications/Verifications.csv');
  if (file == null || file.rows.isEmpty) return const SizedBox.shrink();
  final row = file.rows.first;
  final entries = <MapEntry<String, String>>[];
  for (var i = 0; i < file.headers.length; i++) {
    final v = i < row.length ? row[i] : '';
    if (v.trim().isEmpty) continue;
    entries.add(MapEntry(file.headers[i], v));
  }
  return KvCard(title: 'Identity Verification', entries: entries);
}
