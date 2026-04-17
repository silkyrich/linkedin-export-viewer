import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/archive.dart';
import '../models/entities/message.dart';
import 'archive_controller.dart';

/// Pre-computed, date-sorted index over the archive's messages for the
/// timeline graph. Runs once on archive load; everything downstream
/// (window aggregation, animation) consumes this.
@immutable
class FlowIndex {
  const FlowIndex({
    required this.meName,
    required this.meProfileUrl,
    required this.events,
    required this.contacts,
    required this.minDate,
    required this.maxDate,
  });

  final String meName;
  final String meProfileUrl;

  /// Flat, date-ascending list of edges from me to a contact (or vice versa).
  /// A single message to N people becomes N events.
  final List<FlowEvent> events;

  /// Every contact the user has exchanged messages with, keyed by canonical id.
  final Map<String, FlowContact> contacts;

  final DateTime minDate;
  final DateTime maxDate;

  bool get isEmpty => events.isEmpty;

  /// Binary-search the first event index with `date >= threshold`.
  int indexAtOrAfter(DateTime threshold) {
    var lo = 0;
    var hi = events.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (events[mid].date.isBefore(threshold)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}

@immutable
class FlowEvent {
  const FlowEvent({
    required this.date,
    required this.contactKey,
    required this.outgoing,
  });
  final DateTime date;
  final String contactKey;
  final bool outgoing;
}

class FlowContact {
  FlowContact({
    required this.key,
    required this.name,
    this.totalOutgoing = 0,
    this.totalIncoming = 0,
    this.firstOutgoing,
    this.firstIncoming,
  });

  final String key;
  final String name;
  int totalOutgoing;
  int totalIncoming;
  DateTime? firstOutgoing;
  DateTime? firstIncoming;

  int get total => totalOutgoing + totalIncoming;

  /// True when the earliest message between us came from them, or when
  /// we've only ever received from them.
  bool get theyApproached {
    if (firstIncoming == null) return false;
    if (firstOutgoing == null) return true;
    return firstIncoming!.isBefore(firstOutgoing!);
  }

  /// True when the earliest message between us was sent by us.
  bool get iApproached {
    if (firstOutgoing == null) return false;
    if (firstIncoming == null) return true;
    return firstOutgoing!.isBefore(firstIncoming!);
  }

  /// Both sides ever exchanged messages.
  bool get responded => totalOutgoing > 0 && totalIncoming > 0;

  /// Only one side ever sent — either a cold-DM you never replied to, or
  /// outreach from you that got no response.
  bool get noResponse => !responded;
}

final flowIndexProvider = Provider<FlowIndex?>((ref) {
  final archive = ref.watch(archiveControllerProvider).valueOrNull;
  if (archive == null) return null;
  return _buildFlowIndex(archive);
});

FlowIndex _buildFlowIndex(LinkedInArchive archive) {
  final me = _detectMe(archive);
  final events = <FlowEvent>[];
  final contacts = <String, FlowContact>{};

  for (final m in archive.messages) {
    final date = m.date;
    if (date == null) continue;
    final outgoing = _isFromMe(m, me);

    if (outgoing) {
      final recipientKeys = _splitRecipients(m);
      for (final key in recipientKeys) {
        if (key.id == me.url || key.id == me.name) continue;
        final c = contacts.putIfAbsent(
          key.id,
          () => FlowContact(key: key.id, name: key.name),
        );
        c.totalOutgoing++;
        if (c.firstOutgoing == null || date.isBefore(c.firstOutgoing!)) {
          c.firstOutgoing = date;
        }
        events.add(FlowEvent(date: date, contactKey: key.id, outgoing: true));
      }
    } else {
      final key = _senderKey(m);
      if (key.id == me.url || key.id == me.name) continue;
      final c = contacts.putIfAbsent(
        key.id,
        () => FlowContact(key: key.id, name: key.name),
      );
      c.totalIncoming++;
      if (c.firstIncoming == null || date.isBefore(c.firstIncoming!)) {
        c.firstIncoming = date;
      }
      events.add(FlowEvent(date: date, contactKey: key.id, outgoing: false));
    }
  }

  events.sort((a, b) => a.date.compareTo(b.date));

  final minDate = events.isEmpty ? DateTime.utc(2000) : events.first.date;
  final maxDate = events.isEmpty ? DateTime.utc(2000) : events.last.date;

  return FlowIndex(
    meName: me.name,
    meProfileUrl: me.url,
    events: events,
    contacts: contacts,
    minDate: minDate,
    maxDate: maxDate,
  );
}

class _Me {
  _Me(this.name, this.url);
  final String name;
  final String url;
}

_Me _detectMe(LinkedInArchive archive) {
  final profile = archive.file('Profile.csv');
  String name = '';
  if (profile != null && profile.rows.isNotEmpty) {
    final row = profile.rows.first;
    final firstIdx = profile.headers.indexOf('First Name');
    final lastIdx = profile.headers.indexOf('Last Name');
    final first = (firstIdx >= 0 && firstIdx < row.length) ? row[firstIdx] : '';
    final last = (lastIdx >= 0 && lastIdx < row.length) ? row[lastIdx] : '';
    name = '$first $last'.trim();
  }
  // Find the most common senderProfileUrl when FROM matches our name — that's our URL.
  final urlVotes = <String, int>{};
  for (final m in archive.messages) {
    if (m.from == name && m.senderProfileUrl.isNotEmpty) {
      urlVotes[m.senderProfileUrl] = (urlVotes[m.senderProfileUrl] ?? 0) + 1;
    }
  }
  String url = '';
  var best = 0;
  urlVotes.forEach((k, v) {
    if (v > best) {
      best = v;
      url = k;
    }
  });
  return _Me(name, url);
}

bool _isFromMe(Message m, _Me me) {
  if (me.url.isNotEmpty && m.senderProfileUrl == me.url) return true;
  if (me.name.isNotEmpty && m.from == me.name) return true;
  return false;
}

class _ContactKey {
  const _ContactKey(this.id, this.name);
  final String id;
  final String name;
}

_ContactKey _senderKey(Message m) {
  if (m.senderProfileUrl.isNotEmpty) {
    return _ContactKey('url:${m.senderProfileUrl}', m.from);
  }
  return _ContactKey('name:${m.from}', m.from);
}

/// Recipients of an outgoing message. For 1-on-1, one entry. For group
/// conversations the URL list is space-separated and the name list is
/// comma-separated; we zip them positionally.
List<_ContactKey> _splitRecipients(Message m) {
  final urls = m.recipientProfileUrls
      .split(RegExp(r'\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final names = m.to
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (urls.isEmpty) {
    // Fall back to names only.
    return [for (final n in names) _ContactKey('name:$n', n)];
  }

  return [
    for (var i = 0; i < urls.length; i++)
      _ContactKey(
        'url:${urls[i]}',
        i < names.length ? names[i] : urls[i],
      ),
  ];
}
