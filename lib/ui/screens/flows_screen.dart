import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/flow_index.dart';
import '../widgets/flow_painter.dart';

/// Animated message-flow timeline.
///
/// Radial graph: "me" at the center, your top message partners on a ring.
/// Contact angles are **locked by lifetime rank** so the same person
/// sits in the same spot regardless of the window — that way scrubbing
/// the slider only changes edge thickness and node shading, not layout.
class FlowsScreen extends ConsumerStatefulWidget {
  const FlowsScreen({super.key});

  @override
  ConsumerState<FlowsScreen> createState() => _FlowsScreenState();
}

enum _Window { day, week, month, quarter, year, all }

extension on _Window {
  String get label => switch (this) {
        _Window.day => 'Day',
        _Window.week => 'Week',
        _Window.month => 'Month',
        _Window.quarter => 'Quarter',
        _Window.year => 'Year',
        _Window.all => 'All',
      };

  Duration? get duration => switch (this) {
        _Window.day => const Duration(days: 1),
        _Window.week => const Duration(days: 7),
        _Window.month => const Duration(days: 30),
        _Window.quarter => const Duration(days: 90),
        _Window.year => const Duration(days: 365),
        _Window.all => null,
      };
}

enum _Filter { all, theyApproached, iApproached, responded, noResponse }

extension on _Filter {
  String get label => switch (this) {
        _Filter.all => 'All',
        _Filter.theyApproached => 'They approached',
        _Filter.iApproached => 'I approached',
        _Filter.responded => 'Responded',
        _Filter.noResponse => 'No response',
      };

  bool matches(FlowContact c) => switch (this) {
        _Filter.all => true,
        _Filter.theyApproached => c.theyApproached,
        _Filter.iApproached => c.iApproached,
        _Filter.responded => c.responded,
        _Filter.noResponse => c.noResponse,
      };
}

class _FlowsScreenState extends ConsumerState<FlowsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _playController;
  _Window _window = _Window.month;
  _Filter _filter = _Filter.all;
  double _position = 1.0; // 0..1 along the archive's full date span
  int _nodeCount = 30;
  String? _selectedKey;
  double _speed = 1.0;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _playController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addListener(_onTick);
  }

  @override
  void dispose() {
    _playController
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  void _onTick() {
    if (!_playing) return;
    setState(() {
      _position = _playController.value;
      if (_position >= 1.0) {
        _playing = false;
        _playController.stop();
      }
    });
  }

  void _togglePlay() {
    setState(() {
      if (_playing) {
        _playing = false;
        _playController.stop();
      } else {
        _playing = true;
        _playController
          ..duration = Duration(milliseconds: (30000 / _speed).round())
          ..forward(from: _position >= 1.0 ? 0.0 : _position);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(flowIndexProvider);
    final theme = Theme.of(context);

    if (index == null) {
      return const Center(child: Text('No archive loaded.'));
    }
    if (index.isEmpty) {
      return const Center(child: Text('No dated messages to graph.'));
    }

    final windowEnd = _dateAtPosition(index, _position);
    final windowStart = _window.duration == null
        ? index.minDate
        : windowEnd.subtract(_window.duration!);

    // Rank contacts *once* by lifetime total and cache; positions are
    // derived from this rank so the wheel doesn't reshuffle per window.
    final ranked = index.contacts.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final visible = ranked.where(_filter.matches).take(_nodeCount).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final graphData = _layout(index, visible, ranked, windowStart, windowEnd, constraints.biggest);
        final stats = _windowStats(index, windowStart, windowEnd, _filter);

        return Column(
          children: [
            _Header(
              start: windowStart,
              end: windowEnd,
              messageCount: stats.messageCount,
              uniqueContacts: stats.uniqueContacts,
              filter: _filter,
            ),
            Expanded(
              child: GestureDetector(
                onTapUp: (details) {
                  final painter = FlowPainter(
                    data: graphData,
                    selectedKey: _selectedKey,
                    theme: theme.colorScheme,
                  );
                  final hit = painter.nodeAt(details.localPosition);
                  setState(() => _selectedKey = hit);
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: FlowPainter(
                    data: graphData,
                    selectedKey: _selectedKey,
                    theme: theme.colorScheme,
                  ),
                ),
              ),
            ),
            _Controls(
              position: _position,
              onPosition: (p) => setState(() {
                _position = p;
                if (_playing) {
                  _playing = false;
                  _playController.stop();
                }
              }),
              window: _window,
              onWindow: (w) => setState(() => _window = w),
              filter: _filter,
              onFilter: (f) => setState(() => _filter = f),
              nodeCount: _nodeCount,
              onNodeCount: (n) => setState(() => _nodeCount = n),
              visibleCount: visible.length,
              filteredTotal: ranked.where(_filter.matches).length,
              playing: _playing,
              onTogglePlay: _togglePlay,
              speed: _speed,
              onSpeed: (s) {
                setState(() {
                  _speed = s;
                  if (_playing) {
                    _playController
                      ..duration = Duration(milliseconds: (30000 / s).round())
                      ..forward(from: _position);
                  }
                });
              },
            ),
          ],
        );
      },
    );
  }

  DateTime _dateAtPosition(FlowIndex index, double t) {
    final span = index.maxDate.difference(index.minDate);
    return index.minDate.add(Duration(microseconds: (span.inMicroseconds * t).round()));
  }

  FlowGraphData _layout(
    FlowIndex index,
    List<FlowContact> visible,
    List<FlowContact> ranked,
    DateTime windowStart,
    DateTime windowEnd,
    Size size,
  ) {
    // Window-scoped counts per contact.
    final startIdx = index.indexAtOrAfter(windowStart);
    final endIdx = index.indexAtOrAfter(windowEnd);
    final windowOut = <String, int>{};
    final windowIn = <String, int>{};
    for (var i = startIdx; i < endIdx; i++) {
      final e = index.events[i];
      if (e.outgoing) {
        windowOut[e.contactKey] = (windowOut[e.contactKey] ?? 0) + 1;
      } else {
        windowIn[e.contactKey] = (windowIn[e.contactKey] ?? 0) + 1;
      }
    }

    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = max(60.0, min(size.width, size.height) * 0.42);
    final maxLifetime = ranked.isEmpty
        ? 1
        : ranked.first.total.clamp(1, 1 << 30);

    // Map each contact to its **lifetime rank** so angle is stable.
    final rankByKey = <String, int>{};
    for (var i = 0; i < ranked.length; i++) {
      rankByKey[ranked[i].key] = i;
    }
    final slots = min(ranked.length, 60); // ring can hold up to 60 angles

    final nodes = <FlowNode>[];
    for (final c in visible) {
      final rank = rankByKey[c.key] ?? 0;
      if (rank >= slots) continue;
      final angle = (rank / slots) * 2 * pi - pi / 2;
      final position = center + Offset(cos(angle), sin(angle)) * ringRadius;
      final baseRadius = 6 + log(c.total + 1) / log(maxLifetime + 1) * 14;
      nodes.add(FlowNode(
        contact: c,
        position: position,
        angle: angle,
        radius: baseRadius,
        windowOutgoing: windowOut[c.key] ?? 0,
        windowIncoming: windowIn[c.key] ?? 0,
      ));
    }

    return FlowGraphData(
      meName: index.meName,
      meCenter: center,
      nodes: nodes,
    );
  }

  _WindowStats _windowStats(FlowIndex index, DateTime start, DateTime end, _Filter filter) {
    final startIdx = index.indexAtOrAfter(start);
    final endIdx = index.indexAtOrAfter(end);
    final unique = <String>{};
    var count = 0;
    for (var i = startIdx; i < endIdx; i++) {
      final e = index.events[i];
      final contact = index.contacts[e.contactKey];
      if (contact == null) continue;
      if (!filter.matches(contact)) continue;
      unique.add(e.contactKey);
      count++;
    }
    return _WindowStats(messageCount: count, uniqueContacts: unique.length);
  }
}

class _WindowStats {
  const _WindowStats({required this.messageCount, required this.uniqueContacts});
  final int messageCount;
  final int uniqueContacts;
}

// ---------------------------------------------------------------------------

final _dateFmt = DateFormat.yMMMd();

class _Header extends StatelessWidget {
  const _Header({
    required this.start,
    required this.end,
    required this.messageCount,
    required this.uniqueContacts,
    required this.filter,
  });

  final DateTime start;
  final DateTime end;
  final int messageCount;
  final int uniqueContacts;
  final _Filter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_dateFmt.format(start)}  →  ${_dateFmt.format(end)}',
            style: theme.textTheme.titleSmall,
          ),
          Text(
            '$messageCount messages · $uniqueContacts contacts'
            '${filter == _Filter.all ? '' : ' · filter: ${filter.label}'}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.position,
    required this.onPosition,
    required this.window,
    required this.onWindow,
    required this.filter,
    required this.onFilter,
    required this.nodeCount,
    required this.onNodeCount,
    required this.visibleCount,
    required this.filteredTotal,
    required this.playing,
    required this.onTogglePlay,
    required this.speed,
    required this.onSpeed,
  });

  final double position;
  final ValueChanged<double> onPosition;
  final _Window window;
  final ValueChanged<_Window> onWindow;
  final _Filter filter;
  final ValueChanged<_Filter> onFilter;
  final int nodeCount;
  final ValueChanged<int> onNodeCount;
  final int visibleCount;
  final int filteredTotal;
  final bool playing;
  final VoidCallback onTogglePlay;
  final double speed;
  final ValueChanged<double> onSpeed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: onTogglePlay,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                tooltip: playing ? 'Pause' : 'Play',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: position.clamp(0.0, 1.0),
                  onChanged: onPosition,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              SegmentedButton<_Filter>(
                segments: [
                  for (final f in _Filter.values)
                    ButtonSegment(value: f, label: Text(f.label)),
                ],
                selected: {filter},
                showSelectedIcon: false,
                onSelectionChanged: (s) => onFilter(s.first),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              SegmentedButton<_Window>(
                segments: [
                  for (final w in _Window.values)
                    ButtonSegment(value: w, label: Text(w.label)),
                ],
                selected: {window},
                showSelectedIcon: false,
                onSelectionChanged: (s) => onWindow(s.first),
              ),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0.5, label: Text('0.5×')),
                  ButtonSegment(value: 1.0, label: Text('1×')),
                  ButtonSegment(value: 2.0, label: Text('2×')),
                  ButtonSegment(value: 5.0, label: Text('5×')),
                ],
                selected: {speed},
                showSelectedIcon: false,
                onSelectionChanged: (s) => onSpeed(s.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Nodes: $visibleCount of $filteredTotal',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: nodeCount.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11,
                  label: '$nodeCount',
                  onChanged: (v) => onNodeCount(v.round()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
