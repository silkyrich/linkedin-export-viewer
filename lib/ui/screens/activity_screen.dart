import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/linkedin_links.dart';
import '../../models/archive.dart';
import '../../state/archive_controller.dart';
import '../widgets/empty_state.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

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
              Tab(text: 'Engagement'),
              Tab(text: 'Company Follows'),
              Tab(text: 'Events'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _EngagementTab(archive: archive),
              _CompanyFollowsTab(archive: archive),
              _EventsTab(archive: archive),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Engagement: Reactions + Shares + Comments + Votes + Saves — unified view
// of every "thing you did" across LinkedIn's Complete-archive social files.
// Each row deep-links back to the original post/comment/article on LinkedIn.

enum _EngagementKind { reaction, share, comment, vote, save }

extension _EngagementKindMeta on _EngagementKind {
  IconData get icon => switch (this) {
        _EngagementKind.reaction => Icons.favorite_border,
        _EngagementKind.share => Icons.share_outlined,
        _EngagementKind.comment => Icons.chat_bubble_outline,
        _EngagementKind.vote => Icons.how_to_vote_outlined,
        _EngagementKind.save => Icons.bookmark_border,
      };

  String get label => switch (this) {
        _EngagementKind.reaction => 'Like',
        _EngagementKind.share => 'Share',
        _EngagementKind.comment => 'Comment',
        _EngagementKind.vote => 'Poll vote',
        _EngagementKind.save => 'Save',
      };
}

class _EngagementRow {
  _EngagementRow({
    required this.kind,
    required this.date,
    required this.title,
    required this.body,
    required this.url,
  });
  final _EngagementKind kind;
  final DateTime? date;
  final String title; // short: reaction type / poll option / share visibility
  final String body; // longer: comment text / share commentary / saved-article title
  final String url;
}

class _EngagementTab extends StatefulWidget {
  const _EngagementTab({required this.archive});
  final LinkedInArchive archive;

  @override
  State<_EngagementTab> createState() => _EngagementTabState();
}

class _EngagementTabState extends State<_EngagementTab> {
  final Set<_EngagementKind> _selected = {..._EngagementKind.values};

  @override
  Widget build(BuildContext context) {
    final rows = _collect(widget.archive);
    if (rows.isEmpty) {
      return const EmptyState(
        message: 'No engagement data in this archive.',
        icon: Icons.bolt_outlined,
        hint:
            'Reactions, shares, comments, poll votes, and saves live in '
            'LinkedIn\'s "complete" export (the larger archive that takes '
            'up to 24 hours). The fast archive doesn\'t include them.',
      );
    }
    final filtered = rows.where((r) => _selected.contains(r.kind)).toList();
    final counts = <_EngagementKind, int>{};
    for (final r in rows) {
      counts[r.kind] = (counts[r.kind] ?? 0) + 1;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in _EngagementKind.values)
                FilterChip(
                  label: Text('${k.label}s  ·  ${counts[k] ?? 0}'),
                  avatar: Icon(k.icon, size: 16),
                  selected: _selected.contains(k),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selected.add(k);
                    } else {
                      _selected.remove(k);
                    }
                  }),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${filtered.length} of ${rows.length} rows',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => _EngagementTile(row: filtered[i]),
          ),
        ),
      ],
    );
  }
}

List<_EngagementRow> _collect(LinkedInArchive a) {
  final out = <_EngagementRow>[];

  String at(List<String> r, int i) =>
      (i < 0 || i >= r.length) ? '' : r[i];

  // Reactions: Date, Type, Link
  final reactions = a.file('Reactions.csv');
  if (reactions != null) {
    final d = reactions.headers.indexOf('Date');
    final t = reactions.headers.indexOf('Type');
    final l = reactions.headers.indexOf('Link');
    for (final r in reactions.rows) {
      out.add(_EngagementRow(
        kind: _EngagementKind.reaction,
        date: _parseTimestamp(at(r, d)),
        title: _prettyReaction(at(r, t)),
        body: '',
        url: at(r, l),
      ));
    }
  }

  // Shares: Date, ShareLink, ShareCommentary, SharedUrl, MediaUrl
  // (Visibility column also exists in some exports; tolerate both shapes.)
  final shares = a.file('Shares.csv');
  if (shares != null) {
    final d = shares.headers.indexOf('Date');
    final link = shares.headers.indexOf('ShareLink');
    final vis = shares.headers.indexOf('Visibility');
    final text = shares.headers.indexOf('ShareCommentary');
    for (final r in shares.rows) {
      out.add(_EngagementRow(
        kind: _EngagementKind.share,
        date: _parseTimestamp(at(r, d)),
        title: at(r, vis).isEmpty ? 'Share' : _prettyVisibility(at(r, vis)),
        body: at(r, text),
        url: at(r, link),
      ));
    }
  }

  // Comments: Date, Link, Message
  final comments = a.file('Comments.csv');
  if (comments != null) {
    final d = comments.headers.indexOf('Date');
    final link = comments.headers.indexOf('Link');
    final msg = comments.headers.indexOf('Message');
    for (final r in comments.rows) {
      out.add(_EngagementRow(
        kind: _EngagementKind.comment,
        date: _parseTimestamp(at(r, d)),
        title: '',
        body: at(r, msg),
        url: at(r, link),
      ));
    }
  }

  // Votes: Date, Link, OptionText
  final votes = a.file('Votes.csv');
  if (votes != null) {
    final d = votes.headers.indexOf('Date');
    final link = votes.headers.indexOf('Link');
    final opt = votes.headers.indexOf('OptionText');
    for (final r in votes.rows) {
      out.add(_EngagementRow(
        kind: _EngagementKind.vote,
        date: _parseTimestamp(at(r, d)),
        title: at(r, opt),
        body: '',
        url: at(r, link),
      ));
    }
  }

  // Saved articles: Saved At, Link, Name (also handle "saved_items.csv")
  final saved = a.file('saved_articles.csv') ?? a.file('saved_items.csv');
  if (saved != null) {
    final d = saved.headers.contains('Saved At')
        ? saved.headers.indexOf('Saved At')
        : saved.headers.indexOf('Date');
    final link = saved.headers.indexOf('Link');
    final name = saved.headers.indexOf('Name');
    for (final r in saved.rows) {
      out.add(_EngagementRow(
        kind: _EngagementKind.save,
        date: _parseTimestamp(at(r, d)),
        title: '',
        body: at(r, name),
        url: at(r, link),
      ));
    }
  }

  // Most recent first.
  out.sort((a, b) {
    final ad = a.date ?? DateTime(0);
    final bd = b.date ?? DateTime(0);
    return bd.compareTo(ad);
  });
  return out;
}

DateTime? _parseTimestamp(String s) {
  if (s.trim().isEmpty) return null;
  // LinkedIn uses "YYYY-MM-DD HH:MM:SS UTC" — convert to ISO.
  final cleaned = s.trim().replaceAll(' UTC', 'Z').replaceFirst(' ', 'T');
  return DateTime.tryParse(cleaned);
}

String _prettyReaction(String t) {
  if (t.isEmpty) return 'Reaction';
  const map = {
    'LIKE': 'Like',
    'PRAISE': 'Celebrate',
    'EMPATHY': 'Support',
    'INTEREST': 'Insightful',
    'APPRECIATION': 'Love',
    'MAYBE': 'Funny',
  };
  return map[t] ?? '${t[0]}${t.substring(1).toLowerCase()}';
}

String _prettyVisibility(String v) {
  const map = {'PUBLIC': 'Public', 'CONNECTIONS': 'Connections'};
  return map[v] ?? v;
}

class _EngagementTile extends StatelessWidget {
  const _EngagementTile({required this.row});
  final _EngagementRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText = row.date == null
        ? ''
        : '${row.date!.year}-${row.date!.month.toString().padLeft(2, '0')}-${row.date!.day.toString().padLeft(2, '0')}';
    // Reactions live in [title] (Celebrate / Support / …); everything else
    // lives in [body]. Avoid "Like — Like" for a plain like.
    final displayTitle = row.kind == _EngagementKind.reaction
        ? (row.title.isEmpty ? row.kind.label : row.title)
        : (row.body.isEmpty
            ? '${row.kind.label}${row.title.isEmpty ? '' : ' — ${row.title}'}'
            : row.body);
    final subtitleParts = <String>[
      row.kind.label,
      if (row.title.isNotEmpty && row.title != row.kind.label) row.title,
      if (dateText.isNotEmpty) dateText,
    ];
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        child: Icon(row.kind.icon, size: 18),
      ),
      title: Text(
        displayTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitleParts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: row.url.isEmpty
          ? null
          : IconButton(
              tooltip: 'Open on LinkedIn',
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: () => openExternalUrl(row.url),
            ),
    );
  }
}

class _CompanyFollowsTab extends StatelessWidget {
  const _CompanyFollowsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Company Follows.csv');
    if (file == null || file.rows.isEmpty) {
      return const EmptyState(
        message: 'Not following any companies.',
        icon: Icons.domain,
      );
    }
    return ListView.builder(
      itemCount: file.rows.length,
      itemBuilder: (ctx, i) {
        final r = file.rows[i];
        String f(String k) {
          final idx = file.headers.indexOf(k);
          return (idx == -1 || idx >= r.length) ? '' : r[idx];
        }
        final org = f('Organization');
        return ListTile(
          leading: const Icon(Icons.domain),
          title: Text(org),
          trailing: SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    f('Followed On'),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                if (org.isNotEmpty)
                  IconButton(
                    tooltip: 'Find $org on LinkedIn',
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => openLinkedInCompany(org),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EventsTab extends StatelessWidget {
  const _EventsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Events.csv');
    if (file == null || file.rows.isEmpty) {
      return const EmptyState(message: 'No events.', icon: Icons.event_outlined);
    }
    return ListView.builder(
      itemCount: file.rows.length,
      itemBuilder: (ctx, i) {
        final r = file.rows[i];
        String f(String k) {
          final idx = file.headers.indexOf(k);
          return (idx == -1 || idx >= r.length) ? '' : r[idx];
        }
        final url = f('External Url');
        return ListTile(
          leading: const Icon(Icons.event_outlined),
          title: Text(f('Event Name')),
          subtitle: Text(f('Event Time')),
          trailing: SizedBox(
            width: 130,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    f('Status'),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                if (url.isNotEmpty)
                  IconButton(
                    tooltip: 'Open event link',
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => openExternalUrl(url),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
