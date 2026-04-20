import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/linkedin_links.dart';
import '../../models/archive.dart';
import '../../models/parsed_file.dart';
import '../../state/archive_controller.dart';
import '../widgets/article_frame_stub.dart'
    if (dart.library.js_interop) '../widgets/article_frame_web.dart';

class LearningScreen extends ConsumerStatefulWidget {
  const LearningScreen({super.key});

  @override
  ConsumerState<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends ConsumerState<LearningScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final archive = ref.watch(archiveControllerProvider).valueOrNull;
    if (archive == null) {
      return const Center(child: Text('No archive loaded.'));
    }
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Courses'),
              Tab(text: 'Articles'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _CoursesTab(archive: archive),
              _ArticlesTab(archive: archive),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoursesTab extends StatelessWidget {
  const _CoursesTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Learning.csv');
    if (file == null || file.rows.isEmpty) {
      return const Center(child: Text('No learning history.'));
    }
    return ListView.builder(
      itemCount: file.rows.length,
      itemBuilder: (ctx, i) {
        final r = file.rows[i];
        String f(String k) {
          final idx = file.headers.indexOf(k);
          return (idx == -1 || idx >= r.length) ? '' : r[idx];
        }
        // Header key names in the real export include parenthetical
        // qualifiers like "(if viewed)" — look those up by substring so
        // minor drift doesn't break the lookup.
        String byPrefix(String prefix) {
          for (var k = 0; k < file.headers.length; k++) {
            if (file.headers[k].startsWith(prefix)) {
              return k < r.length ? r[k] : '';
            }
          }
          return '';
        }

        final title = f('Content Title');
        final desc = f('Content Description');
        final type = f('Content Type');
        final watched = byPrefix('Content Last Watched');
        final completed = byPrefix('Content Completed');
        return ListTile(
          leading: Icon(type == 'VIDEO' ? Icons.play_circle_outline : Icons.school_outlined),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => openLinkedInLearning(title),
          trailing: SizedBox(
            width: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (completed.isNotEmpty)
                        Text('✓ $completed',
                            style: Theme.of(context).textTheme.labelSmall)
                      else if (watched.isNotEmpty)
                        Text(watched,
                            style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Find on LinkedIn Learning',
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => openLinkedInLearning(title),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ArticlesTab extends StatefulWidget {
  const _ArticlesTab({required this.archive});
  final LinkedInArchive archive;

  @override
  State<_ArticlesTab> createState() => _ArticlesTabState();
}

class _ArticlesTabState extends State<_ArticlesTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = widget.archive.files.entries
        .where((e) =>
            e.key.startsWith('Articles/') &&
            e.key.toLowerCase().endsWith('.html'))
        .map((e) {
      final filename = e.key.split('/').last;
      return _Article(
        path: e.key,
        filename: filename,
        title: _titleFromFilename(filename),
        date: _dateFromFilename(filename),
        sizeBytes: e.value.rawBytes?.length ?? 0,
        file: e.value,
      );
    }).toList()
      ..sort((a, b) =>
          (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

    if (all.isEmpty) {
      return const Center(child: Text('No published articles.'));
    }

    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? all
        : all
            .where((a) =>
                a.filename.toLowerCase().contains(q) ||
                a.title.toLowerCase().contains(q))
            .toList();

    final totalBytes = all.fold<int>(0, (s, a) => s + a.sizeBytes);

    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search articles',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              q.isEmpty
                  ? '${all.length} articles · ${_humanSize(totalBytes)} total'
                  : '${filtered.length} of ${all.length} articles',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          // ListView.builder already virtualizes — only the visible rows
          // materialize, so 500+ articles stay responsive. Each article's
          // HTML body is only decoded when you open it, not on scroll.
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final a = filtered[i];
              final subtitleParts = <String>[
                if (a.date != null) DateFormat.yMMMd().format(a.date!),
                _humanSize(a.sizeBytes),
              ];
              return ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  subtitleParts.join(' · '),
                  style: theme.textTheme.labelSmall,
                ),
                onTap: () => _openArticle(ctx, a.file),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Article {
  _Article({
    required this.path,
    required this.filename,
    required this.title,
    required this.date,
    required this.sizeBytes,
    required this.file,
  });
  final String path;
  final String filename;
  final String title;
  final DateTime? date;
  final int sizeBytes;
  final ParsedFile file;
}

/// LinkedIn articles are exported with filenames like
/// "2024-05-18_flutter-web-renderer-tradeoffs.html". Parse both pieces.
DateTime? _dateFromFilename(String filename) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(filename);
  if (m == null) return null;
  return DateTime.utc(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

String _titleFromFilename(String filename) {
  // Strip date prefix + .html suffix, convert dashes to spaces, Title Case.
  var s = filename;
  final dateMatch = RegExp(r'^\d{4}-\d{2}-\d{2}[_-]').firstMatch(s);
  if (dateMatch != null) s = s.substring(dateMatch.end);
  s = s.replaceAll(RegExp(r'\.html$', caseSensitive: false), '');
  s = s.replaceAll(RegExp('[-_]+'), ' ').trim();
  if (s.isEmpty) return filename;
  // Sentence-case: upper first letter.
  return s[0].toUpperCase() + s.substring(1);
}

String _humanSize(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

void _openArticle(BuildContext context, ParsedFile file) {
  final html = file.rawBytes == null
      ? '<html><body>Empty article.</body></html>'
      : utf8.decode(file.rawBytes!, allowMalformed: true);
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (ctx, controller) => _ArticleSheet(
        title: file.path.split('/').last,
        html: html,
        controller: controller,
      ),
    ),
  );
}

class _ArticleSheet extends StatelessWidget {
  const _ArticleSheet({
    required this.title,
    required this.html,
    required this.controller,
  });

  final String title;
  final String html;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(child: buildArticleFrame(html)),
      ],
    );
  }
}
