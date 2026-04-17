import 'package:flutter/foundation.dart';

/// A single LinkedIn message record pulled out of messages.csv.
///
/// Schema columns (from the real LinkedIn export):
///   CONVERSATION ID, CONVERSATION TITLE, FROM, SENDER PROFILE URL, TO,
///   RECIPIENT PROFILE URLS, DATE, SUBJECT, CONTENT, FOLDER, ATTACHMENTS,
///   IS MESSAGE DRAFT.
@immutable
class Message {
  const Message({
    required this.conversationId,
    required this.conversationTitle,
    required this.from,
    required this.senderProfileUrl,
    required this.to,
    required this.recipientProfileUrls,
    required this.date,
    required this.subject,
    required this.content,
    required this.folder,
    required this.attachments,
    required this.isDraft,
  });

  final String conversationId;
  final String conversationTitle;
  final String from;
  final String senderProfileUrl;
  final String to;
  final String recipientProfileUrls;
  final DateTime? date;
  final String subject;
  final String content;
  final String folder;
  final String attachments;
  final bool isDraft;

  /// Parse a row from messages.csv. Returns null if the row is too short
  /// to be a valid message (e.g. a stray trailing blank line).
  static Message? fromCsvRow(List<String> row) {
    if (row.length < 12) return null;
    return Message(
      conversationId: row[0],
      conversationTitle: row[1],
      from: row[2],
      senderProfileUrl: row[3],
      to: row[4],
      recipientProfileUrls: row[5],
      date: _parseDate(row[6]),
      subject: row[7],
      content: row[8],
      folder: row[9],
      attachments: row[10],
      isDraft: row[11].toLowerCase() == 'true',
    );
  }
}

/// LinkedIn timestamps look like `2024-03-14 09:41:53 UTC`.
DateTime? _parseDate(String raw) {
  if (raw.isEmpty) return null;
  final trimmed = raw.trim().replaceAll(' UTC', 'Z').replaceFirst(' ', 'T');
  return DateTime.tryParse(trimmed);
}
