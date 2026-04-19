import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/linkedin_links.dart';
import '../../models/archive.dart';
import '../../models/entities/message.dart';
import '../../state/archive_controller.dart';
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

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final archive = ref.watch(archiveControllerProvider).valueOrNull;
    if (archive == null) {
      return const Center(child: Text('No archive loaded.'));
    }

    final conversations = _buildConversations(archive, _query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search messages',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _query.isEmpty
                  ? '${_fmt(archive.messageCount)} messages across ${_fmt(archive.conversationCount)} conversations'
                  : '${conversations.length} matching conversations',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, i) => _ConversationTile(
              entry: conversations[i],
              archive: archive,
            ),
          ),
        ),
      ],
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

List<_ConversationEntry> _buildConversations(
  LinkedInArchive archive,
  String query,
) {
  final entries = <_ConversationEntry>[];
  for (final entry in archive.messagesByConversation.entries) {
    final indices = entry.value;
    if (indices.isEmpty) continue;
    final msgs = [for (final i in indices) archive.messages[i]];
    msgs.sort((a, b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));
    final last = msgs.last;

    if (query.isNotEmpty) {
      final haystack = msgs
          .map((m) => '${m.from} ${m.to} ${m.subject} ${m.content}')
          .join('\n')
          .toLowerCase();
      if (!haystack.contains(query)) continue;
    }

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
  const _ConversationTile({required this.entry, required this.archive});

  final _ConversationEntry entry;
  final LinkedInArchive archive;

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
      onTap: () => _showThread(context, archive, entry.conversationId),
    );
  }
}

void _showThread(BuildContext context, LinkedInArchive archive, String conversationId) {
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
      ),
    ),
  );
}

class _ThreadView extends StatelessWidget {
  const _ThreadView({required this.controller, required this.messages});
  final ScrollController controller;
  final List<Message> messages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (ctx, i) {
        final m = messages[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    m.from,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  if (m.senderProfileUrl.isNotEmpty || m.from.isNotEmpty)
                    IconButton(
                      iconSize: 16,
                      padding: const EdgeInsets.only(left: 6),
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
                  const Spacer(),
                  Text(
                    m.date == null ? '' : _dateFmt.format(m.date!),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              if (m.subject.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(m.subject, style: Theme.of(context).textTheme.labelMedium),
              ],
              const SizedBox(height: 4),
              Text(m.content),
            ],
          ),
        );
      },
    );
  }
}

String _fmt(int n) => NumberFormat.decimalPattern().format(n);
