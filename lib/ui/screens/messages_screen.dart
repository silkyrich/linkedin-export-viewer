import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/linkedin_links.dart';
import '../../models/archive.dart';
import '../../models/entities/message.dart';
import '../../state/archive_controller.dart';
import '../../state/flow_index.dart';
import '../widgets/avatar.dart';

/// Browses the decoded messages.csv.
///
/// Groups by conversation, sorts conversations by most recent message, and
/// renders with a virtualized [ListView.builder] so 20k+ messages don't
/// materialize all at once.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

enum _DirFilter { all, sent, received, unanswered }

extension on _DirFilter {
  String get label => switch (this) {
        _DirFilter.all => 'All',
        _DirFilter.sent => 'Sent',
        _DirFilter.received => 'Received',
        _DirFilter.unanswered => 'No reply',
      };
}

enum _Period { all, month, quarter, year, custom }

extension on _Period {
  String get label => switch (this) {
        _Period.all => 'All time',
        _Period.month => '30 days',
        _Period.quarter => '90 days',
        _Period.year => 'Year',
        _Period.custom => 'Custom',
      };
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  String _query = '';
  _DirFilter _dir = _DirFilter.all;
  _Period _period = _Period.all;
  RangeValues? _customRange; // in millisSinceEpoch
  bool _filtersExpanded = false;

  @override
  Widget build(BuildContext context) {
    final archive = ref.watch(archiveControllerProvider).valueOrNull;
    if (archive == null) {
      return const Center(child: Text('No archive loaded.'));
    }
    final meName = ref.watch(flowIndexProvider)?.meName ?? '';

    final bounds = _periodBounds(archive);
    final conversations = _buildConversations(
      archive: archive,
      meName: meName,
      query: _query,
      dir: _dir,
      start: bounds.$1,
      end: bounds.$2,
    );

    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search messages',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                tooltip: _filtersExpanded ? 'Hide filters' : 'Show filters',
                icon: Icon(_filtersExpanded
                    ? Icons.expand_less
                    : Icons.tune),
                onPressed: () =>
                    setState(() => _filtersExpanded = !_filtersExpanded),
              ),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _filtersExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: _Filters(
            dir: _dir,
            onDir: (d) => setState(() => _dir = d),
            period: _period,
            onPeriod: (p) => setState(() {
              _period = p;
              if (p != _Period.custom) _customRange = null;
            }),
            archive: archive,
            customRange: _customRange,
            onCustomRange: (r) => setState(() => _customRange = r),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _summaryLine(archive, conversations.length, bounds.$1, bounds.$2),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (_hasActiveFilter())
                TextButton.icon(
                  onPressed: () => setState(() {
                    _dir = _DirFilter.all;
                    _period = _Period.all;
                    _customRange = null;
                    _query = '';
                  }),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                  label: const Text('Reset'),
                ),
            ],
          ),
        ),
        Expanded(
          child: conversations.isEmpty
              ? Center(
                  child: Text(
                    'No conversations match the current filters.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, i) => _ConversationTile(
                    entry: conversations[i],
                    archive: archive,
                    meName: meName,
                  ),
                ),
        ),
      ],
    );
  }

  bool _hasActiveFilter() =>
      _dir != _DirFilter.all ||
      _period != _Period.all ||
      _query.isNotEmpty ||
      _customRange != null;

  /// Returns (start, end) for the currently selected period, nullable
  /// when unbounded on that side.
  (DateTime?, DateTime?) _periodBounds(LinkedInArchive archive) {
    if (_period == _Period.all) return (null, null);
    if (_period == _Period.custom) {
      if (_customRange == null) return (null, null);
      return (
        DateTime.fromMillisecondsSinceEpoch(_customRange!.start.round()),
        DateTime.fromMillisecondsSinceEpoch(_customRange!.end.round()),
      );
    }
    // Anchor at the most recent message so old archives still show something.
    DateTime? latest;
    for (final m in archive.messages) {
      if (m.date == null) continue;
      if (latest == null || m.date!.isAfter(latest)) latest = m.date;
    }
    if (latest == null) return (null, null);
    final days = switch (_period) {
      _Period.month => 30,
      _Period.quarter => 90,
      _Period.year => 365,
      _ => 0,
    };
    return (latest.subtract(Duration(days: days)), latest);
  }

  String _summaryLine(
    LinkedInArchive archive,
    int convoCount,
    DateTime? start,
    DateTime? end,
  ) {
    if (!_hasActiveFilter()) {
      return '${_fmt(archive.messageCount)} messages · '
          '${_fmt(archive.conversationCount)} conversations';
    }
    final parts = <String>['$convoCount conversations'];
    if (_dir != _DirFilter.all) parts.add(_dir.label.toLowerCase());
    if (start != null && end != null) {
      parts.add(
        '${DateFormat.yMMMd().format(start)} → ${DateFormat.yMMMd().format(end)}',
      );
    }
    return parts.join(' · ');
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.dir,
    required this.onDir,
    required this.period,
    required this.onPeriod,
    required this.archive,
    required this.customRange,
    required this.onCustomRange,
  });

  final _DirFilter dir;
  final ValueChanged<_DirFilter> onDir;
  final _Period period;
  final ValueChanged<_Period> onPeriod;
  final LinkedInArchive archive;
  final RangeValues? customRange;
  final ValueChanged<RangeValues> onCustomRange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Direction', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          SegmentedButton<_DirFilter>(
            segments: [
              for (final d in _DirFilter.values)
                ButtonSegment(value: d, label: Text(d.label)),
            ],
            selected: {dir},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onDir(s.first),
          ),
          const SizedBox(height: 10),
          Text('Period', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          SegmentedButton<_Period>(
            segments: [
              for (final p in _Period.values)
                ButtonSegment(value: p, label: Text(p.label)),
            ],
            selected: {period},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onPeriod(s.first),
          ),
          if (period == _Period.custom) _buildCustomRange(context),
        ],
      ),
    );
  }

  Widget _buildCustomRange(BuildContext context) {
    DateTime? minD;
    DateTime? maxD;
    for (final m in archive.messages) {
      final d = m.date;
      if (d == null) continue;
      if (minD == null || d.isBefore(minD)) minD = d;
      if (maxD == null || d.isAfter(maxD)) maxD = d;
    }
    if (minD == null || maxD == null || minD == maxD) {
      return const SizedBox.shrink();
    }
    final range = customRange ??
        RangeValues(
          minD.millisecondsSinceEpoch.toDouble(),
          maxD.millisecondsSinceEpoch.toDouble(),
        );
    final startDate =
        DateTime.fromMillisecondsSinceEpoch(range.start.round());
    final endDate =
        DateTime.fromMillisecondsSinceEpoch(range.end.round());
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat.yMMMd().format(startDate)} → ${DateFormat.yMMMd().format(endDate)}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          RangeSlider(
            min: minD.millisecondsSinceEpoch.toDouble(),
            max: maxD.millisecondsSinceEpoch.toDouble(),
            values: range,
            onChanged: onCustomRange,
          ),
        ],
      ),
    );
  }
}

class _ConversationEntry {
  _ConversationEntry({
    required this.conversationId,
    required this.title,
    required this.lastMessage,
    required this.messageCount,
  });

  final String conversationId;
  final String title;
  final Message lastMessage;
  final int messageCount;
}

List<_ConversationEntry> _buildConversations({
  required LinkedInArchive archive,
  required String meName,
  required String query,
  required _DirFilter dir,
  required DateTime? start,
  required DateTime? end,
}) {
  final entries = <_ConversationEntry>[];
  for (final entry in archive.messagesByConversation.entries) {
    final indices = entry.value;
    if (indices.isEmpty) continue;

    // Scope the conversation's messages to the selected date window first —
    // for most filters it's cheaper to slice the window than search the whole
    // thread twice.
    final msgsAll = [for (final i in indices) archive.messages[i]]
      ..sort((a, b) =>
          (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));
    final msgs = <Message>[];
    for (final m in msgsAll) {
      final d = m.date;
      if (start != null && d != null && d.isBefore(start)) continue;
      if (end != null && d != null && d.isAfter(end)) continue;
      msgs.add(m);
    }
    if (msgs.isEmpty) continue;

    // Direction filter. "Sent" means at least one outgoing message in-window,
    // "Received" the mirror, "No reply" means everything in-window came
    // from them and we never responded.
    final hasOutgoing = msgs.any((m) => m.from == meName);
    final hasIncoming = msgs.any((m) => m.from != meName && m.from.isNotEmpty);
    switch (dir) {
      case _DirFilter.all:
        break;
      case _DirFilter.sent:
        if (!hasOutgoing) continue;
      case _DirFilter.received:
        if (!hasIncoming) continue;
      case _DirFilter.unanswered:
        if (hasOutgoing || !hasIncoming) continue;
    }

    if (query.isNotEmpty) {
      final haystack = msgs
          .map((m) => '${m.from} ${m.to} ${m.subject} ${m.content}')
          .join('\n')
          .toLowerCase();
      if (!haystack.contains(query)) continue;
    }

    final last = msgs.last;
    entries.add(_ConversationEntry(
      conversationId: entry.key,
      title: last.conversationTitle.isNotEmpty
          ? last.conversationTitle
          : '${last.from} ↔ ${last.to}',
      lastMessage: last,
      messageCount: msgs.length,
    ));
  }
  entries.sort((a, b) {
    final ad = a.lastMessage.date ?? DateTime(0);
    final bd = b.lastMessage.date ?? DateTime(0);
    return bd.compareTo(ad);
  });
  return entries;
}

final _dateFmt = DateFormat.yMMMd();

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.entry,
    required this.archive,
    required this.meName,
  });

  final _ConversationEntry entry;
  final LinkedInArchive archive;
  final String meName;

  @override
  Widget build(BuildContext context) {
    final last = entry.lastMessage;
    final subtitle = last.content.split('\n').first;
    return ListTile(
      leading: Avatar(name: entry.title),
      title: Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            last.date == null ? '' : _dateFmt.format(last.date!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            '${entry.messageCount}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      onTap: () => _showThread(context, archive, entry.conversationId, meName),
    );
  }
}

void _showThread(BuildContext context, LinkedInArchive archive, String conversationId, String meName) {
  final indices = archive.messagesByConversation[conversationId] ?? [];
  final msgs = [for (final i in indices) archive.messages[i]]
    ..sort((a, b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      builder: (ctx, controller) => _ThreadView(
        controller: controller,
        messages: msgs,
        meName: meName,
      ),
    ),
  );
}

class _ThreadView extends StatelessWidget {
  const _ThreadView({
    required this.controller,
    required this.messages,
    required this.meName,
  });
  final ScrollController controller;
  final List<Message> messages;
  final String meName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (ctx, i) {
        final m = messages[i];
        final fromMe = meName.isNotEmpty && m.from == meName;
        return Align(
          alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: fromMe
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(fromMe ? 14 : 4),
                    bottomRight: Radius.circular(fromMe ? 4 : 14),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m.from,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (!fromMe && (m.senderProfileUrl.isNotEmpty || m.from.isNotEmpty))
                          IconButton(
                            iconSize: 14,
                            padding: const EdgeInsets.only(left: 4),
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            tooltip: m.senderProfileUrl.isNotEmpty
                                ? 'Open sender on LinkedIn'
                                : 'Search sender on LinkedIn',
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () => openLinkedInProfile(
                              url: m.senderProfileUrl,
                              name: m.from,
                            ),
                          ),
                      ],
                    ),
                    if (m.subject.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        m.subject,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    SelectableText(m.content),
                    const SizedBox(height: 4),
                    Text(
                      m.date == null ? '' : _dateFmt.format(m.date!),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _fmt(int n) => NumberFormat.decimalPattern().format(n);
