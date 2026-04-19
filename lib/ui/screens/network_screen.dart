import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/linkedin_links.dart';
import '../../models/archive.dart';
import '../../models/parsed_file.dart';
import '../../state/archive_controller.dart';
import '../widgets/avatar.dart';

/// Network tab: Connections, Invitations, Recommendations, Endorsements.
/// Each sub-tab is a virtualized filterable list.
class NetworkScreen extends ConsumerStatefulWidget {
  const NetworkScreen({super.key});

  @override
  ConsumerState<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends ConsumerState<NetworkScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

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
            isScrollable: true,
            tabs: const [
              Tab(text: 'Connections'),
              Tab(text: 'Invitations'),
              Tab(text: 'Recommendations'),
              Tab(text: 'Endorsements'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _ConnectionsTab(archive: archive),
              _InvitationsTab(archive: archive),
              _RecommendationsTab(archive: archive),
              _EndorsementsTab(archive: archive),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _SearchableList extends StatefulWidget {
  const _SearchableList({
    required this.hint,
    required this.itemCount,
    required this.rowBuilder,
    required this.matches,
    required this.totalLabel,
  });

  final String hint;
  final int itemCount;
  final Widget Function(BuildContext, int) rowBuilder;
  final bool Function(int index, String query) matches;
  final String Function(int shown, int total) totalLabel;

  @override
  State<_SearchableList> createState() => _SearchableListState();
}

class _SearchableListState extends State<_SearchableList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = <int>[];
    final q = _query.toLowerCase();
    for (var i = 0; i < widget.itemCount; i++) {
      if (q.isEmpty || widget.matches(i, q)) filtered.add(i);
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: widget.hint,
              border: const OutlineInputBorder(),
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
              widget.totalLabel(filtered.length, widget.itemCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => widget.rowBuilder(ctx, filtered[i]),
          ),
        ),
      ],
    );
  }
}

String _fmt(int n) => NumberFormat.decimalPattern().format(n);

// ---------------------------------------------------------------------------
// Connections tab

class _ConnectionsTab extends StatelessWidget {
  const _ConnectionsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Connections.csv');
    if (file == null) return _empty('No Connections.csv in this archive.');
    return _SearchableList(
      hint: 'Search connections',
      itemCount: file.rows.length,
      totalLabel: (shown, total) => total == shown
          ? '${_fmt(total)} connections'
          : '${_fmt(shown)} of ${_fmt(total)} connections',
      matches: (i, q) {
        final r = file.rows[i];
        for (final cell in r) {
          if (cell.toLowerCase().contains(q)) return true;
        }
        return false;
      },
      rowBuilder: (ctx, i) => _ConnectionRow(file: file, row: file.rows[i]),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({required this.file, required this.row});
  final ParsedFile file;
  final List<String> row;

  @override
  Widget build(BuildContext context) {
    final headers = file.headers;
    String field(String key) {
      final idx = headers.indexOf(key);
      return (idx == -1 || idx >= row.length) ? '' : row[idx];
    }

    final first = field('First Name');
    final last = field('Last Name');
    final company = field('Company');
    final position = field('Position');
    final connectedOn = field('Connected On');
    final url = field('URL');
    final name = '$first $last'.trim();
    return ListTile(
      leading: Avatar(name: name),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [position, company].where((s) => s.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: SizedBox(
        width: 150,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                connectedOn,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            if (url.isNotEmpty || name.isNotEmpty)
              IconButton(
                tooltip: url.isNotEmpty ? 'Open on LinkedIn' : 'Search on LinkedIn',
                icon: const Icon(Icons.open_in_new, size: 18),
                onPressed: () =>
                    openLinkedInProfile(url: url, name: name),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invitations

class _InvitationsTab extends StatelessWidget {
  const _InvitationsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  Widget build(BuildContext context) {
    final file = archive.file('Invitations.csv');
    if (file == null) return _empty('No Invitations.csv in this archive.');
    return _SearchableList(
      hint: 'Search invitations',
      itemCount: file.rows.length,
      totalLabel: (s, t) =>
          t == s ? '${_fmt(t)} invitations' : '${_fmt(s)} of ${_fmt(t)} invitations',
      matches: (i, q) =>
          file.rows[i].any((c) => c.toLowerCase().contains(q)),
      rowBuilder: (ctx, i) {
        final r = file.rows[i];
        String field(String k) {
          final idx = file.headers.indexOf(k);
          return (idx == -1 || idx >= r.length) ? '' : r[idx];
        }

        final dir = field('Direction');
        final isIn = dir.toUpperCase() == 'INCOMING';
        final from = field('From');
        final to = field('To');
        final msg = field('Message');
        final sentAt = field('Sent At');
        final otherUrl = isIn ? field('inviterProfileUrl') : field('inviteeProfileUrl');
        final otherName = isIn ? from : to;
        return ListTile(
          leading: Icon(isIn ? Icons.call_received : Icons.call_made),
          title: Text(isIn ? 'From $from' : 'To $to',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(msg.isEmpty ? '(no message)' : msg,
              maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    sentAt,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                if (otherUrl.isNotEmpty || otherName.isNotEmpty)
                  IconButton(
                    tooltip: otherUrl.isNotEmpty
                        ? 'Open on LinkedIn'
                        : 'Search on LinkedIn',
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => openLinkedInProfile(
                      url: otherUrl,
                      name: otherName,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Recommendations

class _RecommendationsTab extends StatefulWidget {
  const _RecommendationsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  State<_RecommendationsTab> createState() => _RecommendationsTabState();
}

class _RecommendationsTabState extends State<_RecommendationsTab> {
  bool _given = false;

  @override
  Widget build(BuildContext context) {
    final path =
        _given ? 'Recommendations_Given.csv' : 'Recommendations_Received.csv';
    final file = widget.archive.file(path);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Received')),
              ButtonSegment(value: true, label: Text('Given')),
            ],
            selected: {_given},
            onSelectionChanged: (s) => setState(() => _given = s.first),
          ),
        ),
        Expanded(
          child: file == null
              ? _empty('No $path in this archive.')
              : _SearchableList(
                  hint: 'Search recommendations',
                  itemCount: file.rows.length,
                  totalLabel: (s, t) =>
                      '${_fmt(s)} ${_given ? 'given' : 'received'}',
                  matches: (i, q) =>
                      file.rows[i].any((c) => c.toLowerCase().contains(q)),
                  rowBuilder: (ctx, i) {
                    final r = file.rows[i];
                    String field(String k) {
                      final idx = file.headers.indexOf(k);
                      return (idx == -1 || idx >= r.length) ? '' : r[idx];
                    }

                    final first = field('First Name');
                    final last = field('Last Name');
                    final company = field('Company');
                    final title = field('Job Title');
                    final text = field('Text');
                    final name = '$first $last'.trim();
                    return ExpansionTile(
                      leading: Avatar(name: name),
                      title: Text(name),
                      subtitle: Text(
                        [title, company].where((s) => s.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'Search on LinkedIn',
                        icon: const Icon(Icons.open_in_new, size: 18),
                        onPressed: () => openLinkedInProfile(name: name),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(text),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Endorsements

class _EndorsementsTab extends StatefulWidget {
  const _EndorsementsTab({required this.archive});
  final LinkedInArchive archive;

  @override
  State<_EndorsementsTab> createState() => _EndorsementsTabState();
}

class _EndorsementsTabState extends State<_EndorsementsTab> {
  bool _given = false;

  @override
  Widget build(BuildContext context) {
    final path = _given
        ? 'Endorsement_Given_Info.csv'
        : 'Endorsement_Received_Info.csv';
    final file = widget.archive.file(path);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Received')),
              ButtonSegment(value: true, label: Text('Given')),
            ],
            selected: {_given},
            onSelectionChanged: (s) => setState(() => _given = s.first),
          ),
        ),
        Expanded(
          child: file == null
              ? _empty('No $path in this archive.')
              : _SearchableList(
                  hint: 'Search endorsements',
                  itemCount: file.rows.length,
                  totalLabel: (s, t) =>
                      '${_fmt(s)} ${_given ? 'given' : 'received'}',
                  matches: (i, q) =>
                      file.rows[i].any((c) => c.toLowerCase().contains(q)),
                  rowBuilder: (ctx, i) {
                    final r = file.rows[i];
                    String field(String k) {
                      final idx = file.headers.indexOf(k);
                      return (idx == -1 || idx >= r.length) ? '' : r[idx];
                    }

                    final firstKey =
                        _given ? 'Endorsee First Name' : 'Endorser First Name';
                    final lastKey =
                        _given ? 'Endorsee Last Name' : 'Endorser Last Name';
                    final urlKey =
                        _given ? 'Endorsee Public Url' : 'Endorser Public Url';
                    final name = '${field(firstKey)} ${field(lastKey)}'.trim();
                    final url = field(urlKey);
                    final skill = field('Skill Name');
                    final date = field('Endorsement Date');
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.thumb_up_outlined),
                      title: Text(skill),
                      subtitle: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: SizedBox(
                        width: 130,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                date,
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                            if (url.isNotEmpty || name.isNotEmpty)
                              IconButton(
                                tooltip: url.isNotEmpty
                                    ? 'Open on LinkedIn'
                                    : 'Search on LinkedIn',
                                icon: const Icon(Icons.open_in_new, size: 16),
                                onPressed: () => openLinkedInProfile(
                                  url: url,
                                  name: name,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

Widget _empty(String text) => Center(child: Text(text));
