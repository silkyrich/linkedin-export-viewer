import 'package:flutter/foundation.dart';

import 'entities/message.dart';
import 'parsed_file.dart';

/// In-memory representation of a parsed LinkedIn export.
///
/// Parsing happens once, on upload. Every screen reads from this structure —
/// no re-parsing, no network, no server. Stays in the browser tab.
@immutable
class LinkedInArchive {
  const LinkedInArchive({
    required this.files,
    required this.messages,
    required this.messagesByConversation,
  });

  /// Every file in the zip, keyed by its path (e.g. `Profile.csv`, `Jobs/Saved Jobs.csv`).
  final Map<String, ParsedFile> files;

  /// Decoded messages. Kept as a flat list so the virtualized viewer can index by int.
  final List<Message> messages;

  /// Conversation id -> indices into [messages] for that conversation.
  /// Enables O(1) lookup when scrolling to a specific thread.
  final Map<String, List<int>> messagesByConversation;

  ParsedFile? file(String path) => files[path];

  /// Quick summary for the privacy banner ("12,345 messages, 2,020 connections, ...").
  int get messageCount => messages.length;

  int get connectionCount {
    final connections = files['Connections.csv'];
    if (connections == null) return 0;
    return connections.rows.length;
  }

  int get conversationCount => messagesByConversation.length;
}
