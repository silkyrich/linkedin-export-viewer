import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/linkedin_links.dart';
import '../../models/archive.dart';
import '../../models/entities/message.dart';
import '../../state/archive_controller.dart';
import '../widgets/empty_state.dart';

/// Global search across the archive. Scans messages, connections,
/// recommendations, endorsements, positions, and jobs for a substring match.
///
/// Intentionally simple: no tokenization, no fuzzy matching, no ranking
/// beyond "recent messages first". The viewer's on-device, so speed is the
/// bigger design constraint than recall polish.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _perCategoryCap = 50;
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      setState(() => _query = raw.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final archive = ref.watch(archiveControllerProvider).valueOrNull;
    if (archive == null) {
      return const EmptyState(message: 'No archive loaded.');
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search everything',
              border: const OutlineInputBorder(),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                    ),
            ),
          ),
        ),
        if (_query.isEmpty)
          const Expanded(
            child: EmptyState(
              icon: Icons.search,
              message: 'Start typing to search',
              hint: 'Messages, connections, recommendations, endorsements, '
                  'positions, and jobs.',
            ),
          )
        else
          Expanded(
            child: _ResultsList(
              archive: archive,
              query: _query,
              perCategoryCap: _perCategoryCap,
            ),
          ),
      ],
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.archive,
    required this.query,
    required this.perCategoryCap,
  });

  final LinkedInArchive archive;
  final String query;
  final int perCategoryCap;

  @override
  Widget build(BuildContext context) {
    final groups = <_ResultGroup>[];

    // Messages
    final msgHits = <Message>[];
    for (final m in archive.messages) {
      if (msgHits.length >= perCategoryCap) break;
      final hay = '${m.from}\n${m.to}\n${m.subject}\n${m.content}'.toLowerCase();
      if (hay.contains(query)) msgHits.add(m);
    }
    if (msgHits.isNotEmpty) {
      final hitCount = _totalMatchesInMessages(archive, query);
      groups.add(_ResultGroup(
        label: 'Messages',
        icon: Icons.chat_bubble_outline,
        route: '/messages',
        total: hitCount,
        children: [
          for (final m in msgHits) _MessageHit(message: m, query: query),
        ],
      ));
    }

    groups.addAll(_csvGroups(context));

    if (groups.isEmpty) {
      return const EmptyState(
        message: 'No matches',
        icon: Icons.search_off_outlined,
      );
    }

    return ListView(
      children: [
        for (final g in groups) g.build(context),
      ],
    );
  }

  int _totalMatchesInMessages(LinkedInArchive archive, String q) {
    var n = 0;
    for (final m in archive.messages) {
      final hay = '${m.from}\n${m.to}\n${m.subject}\n${m.content}'.toLowerCase();
      if (hay.contains(q)) n++;
    }
    return n;
  }

  Iterable<_ResultGroup> _csvGroups(BuildContext context) sync* {
    const sources = <_CsvSource>[
      _CsvSource(
        path: 'Connections.csv',
        label: 'Connections',
        icon: Icons.person_outline,
        route: '/network',
        linkKind: _LinkKind.profile,
        nameHeaders: ['First Name', 'Last Name'],
        urlHeader: 'URL',
      ),
      _CsvSource(
        path: 'Recommendations_Received.csv',
        label: 'Recommendations received',
        icon: Icons.star_outline,
        route: '/network',
        linkKind: _LinkKind.profile,
        nameHeaders: ['First Name', 'Last Name'],
      ),
      _CsvSource(
        path: 'Recommendations_Given.csv',
        label: 'Recommendations given',
        icon: Icons.star_border,
        route: '/network',
        linkKind: _LinkKind.profile,
        nameHeaders: ['First Name', 'Last Name'],
      ),
      _CsvSource(
        path: 'Endorsement_Received_Info.csv',
        label: 'Endorsements received',
        icon: Icons.thumb_up_outlined,
        route: '/network',
        linkKind: _LinkKind.profile,
        nameHeaders: ['Endorser First Name', 'Endorser Last Name'],
        urlHeader: 'Endorser Public Url',
      ),
      _CsvSource(
        path: 'Endorsement_Given_Info.csv',
        label: 'Endorsements given',
        icon: Icons.thumb_up_alt_outlined,
        route: '/network',
        linkKind: _LinkKind.profile,
        nameHeaders: ['Endorsee First Name', 'Endorsee Last Name'],
        urlHeader: 'Endorsee Public Url',
      ),
      _CsvSource(
        path: 'Invitations.csv',
        label: 'Invitations',
        icon: Icons.how_to_reg_outlined,
        route: '/network',
        linkKind: _LinkKind.profile,
        nameHeaders: ['From'],
        urlHeader: 'inviterProfileUrl',
      ),
      _CsvSource(
        path: 'Positions.csv',
        label: 'Positions',
        icon: Icons.work_outline,
        route: '/career',
        linkKind: _LinkKind.company,
        nameHeaders: ['Company Name'],
      ),
      _CsvSource(
        path: 'Jobs/Job Applications.csv',
        label: 'Job applications',
        icon: Icons.assignment_outlined,
        route: '/career',
        linkKind: _LinkKind.jobUrl,
        urlHeader: 'Job Url',
        nameHeaders: ['Job Title'],
      ),
      _CsvSource(
        path: 'Jobs/Saved Jobs.csv',
        label: 'Saved jobs',
        icon: Icons.bookmark_outline,
        route: '/career',
        linkKind: _LinkKind.jobUrl,
        urlHeader: 'Job Url',
        nameHeaders: ['Job Title'],
      ),
      _CsvSource(
        path: 'Skills.csv',
        label: 'Skills',
        icon: Icons.workspace_premium_outlined,
        route: '/skills',
        linkKind: _LinkKind.none,
      ),
      _CsvSource(
        path: 'Learning.csv',
        label: 'Learning',
        icon: Icons.school_outlined,
        route: '/learning',
        linkKind: _LinkKind.learning,
        nameHeaders: ['Content Title'],
      ),
      _CsvSource(
        path: 'Publications.csv',
        label: 'Publications',
        icon: Icons.article_outlined,
        route: '/content',
        linkKind: _LinkKind.none,
      ),
      _CsvSource(
        path: 'Projects.csv',
        label: 'Projects',
        icon: Icons.folder_outlined,
        route: '/content',
        linkKind: _LinkKind.none,
      ),
      _CsvSource(
        path: 'Company Follows.csv',
        label: 'Company follows',
        icon: Icons.domain,
        route: '/activity',
        linkKind: _LinkKind.company,
        nameHeaders: ['Organization'],
      ),
    ];

    for (final s in sources) {
      final file = archive.file(s.path);
      if (file == null) continue;
      final hits = <_CsvHit>[];
      var total = 0;
      for (final row in file.rows) {
        final match = _rowMatch(row, query);
        if (match == null) continue;
        total++;
        if (hits.length < perCategoryCap) {
          hits.add(_CsvHit(
            row: row,
            headers: file.headers,
            matchedCell: match,
            source: s,
          ));
        }
      }
      if (total == 0) continue;
      yield _ResultGroup(
        label: s.label,
        icon: s.icon,
        route: s.route,
        total: total,
        children: [
          for (final h in hits) _CsvHitTile(hit: h, query: query),
        ],
      );
    }
  }

  String? _rowMatch(List<String> row, String q) {
    for (final cell in row) {
      if (cell.toLowerCase().contains(q)) return cell;
    }
    return null;
  }
}

enum _LinkKind { profile, company, jobUrl, school, learning, none }

class _CsvSource {
  const _CsvSource({
    required this.path,
    required this.label,
    required this.icon,
    required this.route,
    required this.linkKind,
    this.nameHeaders = const [],
    this.urlHeader,
  });
  final String path;
  final String label;
  final IconData icon;
  final String route;
  final _LinkKind linkKind;

  /// CSV headers that combine into a person/company/school name.
  final List<String> nameHeaders;

  /// CSV header holding a URL (profile or job). null when only name available.
  final String? urlHeader;
}

void _launchHit(
  _LinkKind kind,
  String? url,
  String? name,
) {
  switch (kind) {
    case _LinkKind.profile:
      openLinkedInProfile(url: url, name: name);
    case _LinkKind.company:
      if (name != null) openLinkedInCompany(name);
    case _LinkKind.jobUrl:
      if (url != null) openLinkedInJob(url);
    case _LinkKind.school:
      if (name != null) openLinkedInSchool(name);
    case _LinkKind.learning:
      if (name != null) openLinkedInLearning(name);
    case _LinkKind.none:
      break;
  }
}

class _ResultGroup {
  _ResultGroup({
    required this.label,
    required this.icon,
    required this.route,
    required this.total,
    required this.children,
  });

  final String label;
  final IconData icon;
  final String route;
  final int total;
  final List<Widget> children;

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label · ${NumberFormat.decimalPattern().format(total)}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(route),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
          ...children,
          const Divider(height: 1),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message hit tile

final _dateFmt = DateFormat.yMMMd();

class _MessageHit extends StatelessWidget {
  const _MessageHit({required this.message, required this.query});
  final Message message;
  final String query;

  @override
  Widget build(BuildContext context) {
    final snippet = _highlight(
      context,
      _firstLineMatching(message.content, query),
      query,
    );
    final hasContact = message.senderProfileUrl.isNotEmpty || message.from.isNotEmpty;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.chat_bubble_outline),
      title: Text(
        message.from.isEmpty ? message.to : message.from,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: snippet,
      trailing: SizedBox(
        width: 140,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                message.date == null ? '' : _dateFmt.format(message.date!),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            if (hasContact)
              IconButton(
                tooltip: 'Open sender on LinkedIn',
                icon: const Icon(Icons.open_in_new, size: 18),
                onPressed: () => openLinkedInProfile(
                  url: message.senderProfileUrl,
                  name: message.from,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CSV hit tile

class _CsvHit {
  const _CsvHit({
    required this.row,
    required this.headers,
    required this.matchedCell,
    required this.source,
  });
  final List<String> row;
  final List<String> headers;
  final String matchedCell;
  final _CsvSource source;

  String _byHeader(String key) {
    final idx = headers.indexOf(key);
    return (idx == -1 || idx >= row.length) ? '' : row[idx];
  }

  String? get linkName {
    final parts = source.nameHeaders.map(_byHeader).where((s) => s.isNotEmpty);
    final joined = parts.join(' ').trim();
    return joined.isEmpty ? null : joined;
  }

  String? get linkUrl {
    if (source.urlHeader == null) return null;
    final v = _byHeader(source.urlHeader!);
    return v.isEmpty ? null : v;
  }
}

class _CsvHitTile extends StatelessWidget {
  const _CsvHitTile({required this.hit, required this.query});
  final _CsvHit hit;
  final String query;

  @override
  Widget build(BuildContext context) {
    final title = hit.linkName ??
        (hit.row.isNotEmpty && hit.row.first.trim().isNotEmpty
            ? hit.row.first
            : hit.matchedCell);
    final canLink = hit.source.linkKind != _LinkKind.none &&
        (hit.linkUrl != null || hit.linkName != null);
    return ListTile(
      dense: true,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: _highlight(context, hit.matchedCell, query),
      trailing: canLink
          ? IconButton(
              tooltip: 'Open on LinkedIn',
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: () =>
                  _launchHit(hit.source.linkKind, hit.linkUrl, hit.linkName),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Highlight helper

Widget _highlight(BuildContext context, String haystack, String query) {
  if (query.isEmpty) {
    return Text(haystack, maxLines: 2, overflow: TextOverflow.ellipsis);
  }
  final lower = haystack.toLowerCase();
  final idx = lower.indexOf(query);
  if (idx < 0) {
    return Text(haystack, maxLines: 2, overflow: TextOverflow.ellipsis);
  }
  final before = haystack.substring(0, idx);
  final hit = haystack.substring(idx, idx + query.length);
  final after = haystack.substring(idx + query.length);
  final theme = Theme.of(context);
  return Text.rich(
    TextSpan(
      style: theme.textTheme.bodySmall,
      children: [
        TextSpan(text: before),
        TextSpan(
          text: hit,
          style: TextStyle(
            backgroundColor: theme.colorScheme.primaryContainer,
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(text: after),
      ],
    ),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}

String _firstLineMatching(String content, String query) {
  final q = query.toLowerCase();
  for (final line in content.split('\n')) {
    if (line.toLowerCase().contains(q)) return line.trim();
  }
  return content.split('\n').first.trim();
}
