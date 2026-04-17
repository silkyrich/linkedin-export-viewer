import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          trailing: SizedBox(
            width: 120,
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
        );
      },
    );
  }
}

class _ArticlesTab extends StatelessWidget {
  const _ArticlesTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final articles = archive.files.entries
        .where((e) => e.key.startsWith('Articles/') && e.key.toLowerCase().endsWith('.html'))
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    if (articles.isEmpty) {
      return const Center(child: Text('No published articles.'));
    }
    return ListView.builder(
      itemCount: articles.length,
      itemBuilder: (ctx, i) {
        final entry = articles[i];
        final filename = entry.key.split('/').last;
        return ListTile(
          leading: const Icon(Icons.article_outlined),
          title: Text(filename),
          onTap: () => _openArticle(ctx, entry.value),
        );
      },
    );
  }
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
