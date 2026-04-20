import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/archive.dart';
import 'archive_controller.dart';
import 'flow_index.dart';

/// What kinds of dated things show up in the activity heatmap. Deliberately
/// broader than FlowIndex — not just messages, but also everything the
/// heatmap can plausibly treat as "something you did on this day".
enum ActivityKind {
  message,
  like,
  comment,
  share,
  vote,
  save,
  application,
  endorsementGiven,
  endorsementReceived,
  invitation,
}

extension ActivityKindMeta on ActivityKind {
  String get label => switch (this) {
        ActivityKind.message => 'message',
        ActivityKind.like => 'like',
        ActivityKind.comment => 'comment',
        ActivityKind.share => 'share',
        ActivityKind.vote => 'poll vote',
        ActivityKind.save => 'save',
        ActivityKind.application => 'application',
        ActivityKind.endorsementGiven => 'endorsement given',
        ActivityKind.endorsementReceived => 'endorsement received',
        ActivityKind.invitation => 'invitation',
      };

  /// Plural form for tooltip labels: "3 messages" but "3 endorsements given".
  String plural(int n) {
    if (n == 1) return label;
    return switch (this) {
      ActivityKind.endorsementGiven => 'endorsements given',
      ActivityKind.endorsementReceived => 'endorsements received',
      _ => '${label}s',
    };
  }
}

/// Pre-computed per-day breakdown of activity, keyed by epoch day number
/// so the heatmap doesn't re-scan the whole archive on hover.
@immutable
class ActivityIndex {
  const ActivityIndex({
    required this.perDay,
    required this.minDate,
    required this.maxDate,
  });

  final Map<int, Map<ActivityKind, int>> perDay;
  final DateTime? minDate;
  final DateTime? maxDate;

  bool get isEmpty => perDay.isEmpty;

  int totalForDay(int epochDay) {
    final m = perDay[epochDay];
    if (m == null) return 0;
    var total = 0;
    for (final v in m.values) {
      total += v;
    }
    return total;
  }
}

final activityIndexProvider = Provider<ActivityIndex>((ref) {
  final archive = ref.watch(archiveControllerProvider).valueOrNull;
  if (archive == null) {
    return const ActivityIndex(perDay: {}, minDate: null, maxDate: null);
  }
  final flow = ref.watch(flowIndexProvider);
  return _build(archive, flow);
});

int _epochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

DateTime _dayFromEpoch(int epoch) =>
    DateTime.fromMillisecondsSinceEpoch(
      epoch * Duration.millisecondsPerDay,
      isUtc: true,
    );

ActivityIndex _build(LinkedInArchive archive, FlowIndex? flow) {
  final perDay = <int, Map<ActivityKind, int>>{};
  DateTime? minDate;
  DateTime? maxDate;

  void add(DateTime date, ActivityKind kind) {
    final day = _epochDay(date);
    final bucket = perDay.putIfAbsent(day, () => <ActivityKind, int>{});
    bucket[kind] = (bucket[kind] ?? 0) + 1;
    if (minDate == null || date.isBefore(minDate!)) minDate = date;
    if (maxDate == null || date.isAfter(maxDate!)) maxDate = date;
  }

  // Messages: use the flow index since it's already parsed.
  if (flow != null) {
    for (final e in flow.events) {
      add(e.date, ActivityKind.message);
    }
  }

  // Engagement files (present only when the complete archive is loaded).
  for (final triple in _simpleDateSources) {
    final (path, dateHeader, kind) = triple;
    final file = archive.file(path);
    if (file == null) continue;
    final idx = file.headers.indexOf(dateHeader);
    if (idx < 0) continue;
    for (final r in file.rows) {
      if (idx >= r.length) continue;
      final d = _parseFlexibleDate(r[idx]);
      if (d == null) continue;
      add(d, kind);
    }
  }

  // LinkedIn-date-format ones ("02 Jun 1833"): applications, endorsements,
  // invitations.
  for (final triple in _linkedinDateSources) {
    final (path, dateHeader, kind) = triple;
    final file = archive.file(path);
    if (file == null) continue;
    final idx = file.headers.indexOf(dateHeader);
    if (idx < 0) continue;
    for (final r in file.rows) {
      if (idx >= r.length) continue;
      final d = _parseLinkedInDate(r[idx]);
      if (d == null) continue;
      add(d, kind);
    }
  }

  return ActivityIndex(perDay: perDay, minDate: minDate, maxDate: maxDate);
}

const _simpleDateSources = <(String, String, ActivityKind)>[
  ('Reactions.csv', 'Date', ActivityKind.like),
  ('Comments.csv', 'Date', ActivityKind.comment),
  ('Shares.csv', 'Date', ActivityKind.share),
  ('Votes.csv', 'Date', ActivityKind.vote),
  ('saved_articles.csv', 'Saved At', ActivityKind.save),
];

const _linkedinDateSources = <(String, String, ActivityKind)>[
  ('Jobs/Job Applications.csv', 'Application Date', ActivityKind.application),
  ('Endorsement_Given_Info.csv', 'Endorsement Date', ActivityKind.endorsementGiven),
  ('Endorsement_Received_Info.csv', 'Endorsement Date', ActivityKind.endorsementReceived),
];

DateTime? _parseFlexibleDate(String s) {
  if (s.trim().isEmpty) return null;
  // LinkedIn uses "YYYY-MM-DD HH:MM:SS UTC" — convert to ISO.
  final cleaned = s.trim().replaceAll(' UTC', 'Z').replaceFirst(' ', 'T');
  return DateTime.tryParse(cleaned);
}

DateTime? _parseLinkedInDate(String s) {
  if (s.trim().isEmpty) return null;
  const months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };
  final parts = s.trim().split(RegExp(r'\s+'));
  if (parts.length == 3) {
    final d = int.tryParse(parts[0]);
    final m = months[parts[1]];
    final y = int.tryParse(parts[2]);
    if (d != null && m != null && y != null) return DateTime.utc(y, m, d);
  }
  return null;
}

// Public — tests can import these to verify epoch-day arithmetic.
@visibleForTesting
int epochDayForTests(DateTime d) => _epochDay(d);

@visibleForTesting
DateTime dayFromEpochForTests(int e) => _dayFromEpoch(e);
