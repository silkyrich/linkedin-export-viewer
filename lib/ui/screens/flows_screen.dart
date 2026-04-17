import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/flow_index.dart';
import '../widgets/flow_painter.dart';

/// Animated message-flow timeline.
///
/// A radial graph with "me" at the center and your top message partners
/// around the ring. A time slider + window size chips control which slice
/// of the archive is active; the edge thickness for each contact reflects
/// how many messages you exchanged with them inside the window.
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
        _Window.all => 'All time',
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

class _FlowsScreenState extends ConsumerState<FlowsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _playController;
  _Window _window = _Window.month;
  double _position = 1.0; // 0..1 along the archive's full date span
  String? _selectedKey;
  double _speed = 1.0; // multiplier; 1.0 = 2 weeks of data per real second
  bool _playing = false;

  static const _maxNodes = 60;

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

    final span = index.maxDate.difference(index.minDate);
    final windowEnd = _dateAtPosition(index, _position);
    final windowStart = _window.duration == null
        ? index.minDate
        : windowEnd.subtract(_window.duration!);

    return LayoutBuilder(
      builder: (context, constraints) {
        final graphData = _layout(index, windowStart, windowEnd, constraints.biggest);
        final stats = _windowStats(index, windowStart, windowEnd);

        return Column(
          children: [
            _Header(
              start: windowStart,
              end: windowEnd,
              totalMessages: stats.messageCount,
              uniqueContacts: stats.uniqueContacts,
              fullSpan: span,
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
    DateTime windowStart,
    DateTime windowEnd,
    Size size,
  ) {
    // Count events per contact inside the window.
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

    // Rank contacts: prefer those active in the window, fall back to
    // lifetime total so the layout doesn't collapse on quiet windows.
    final contacts = index.contacts.values.toList();
    contacts.sort((a, b) {
      final aw = (windowOut[a.key] ?? 0) + (windowIn[a.key] ?? 0);
      final bw = (windowOut[b.key] ?? 0) + (windowIn[b.key] ?? 0);
      if (aw != bw) return bw.compareTo(aw);
      return b.total.compareTo(a.total);
    });
    final top = contacts.take(_maxNodes).toList();

    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = max(60.0, min(size.width, size.height) * 0.42);
    final maxLifetime = top.isEmpty
        ? 1
        : top.map((c) => c.total).reduce(max).clamp(1, 1 << 30);

    final nodes = <FlowNode>[];
    for (var i = 0; i < top.length; i++) {
      final c = top[i];
      final angle = (i / top.length) * 2 * pi - pi / 2;
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

  _WindowStats _windowStats(FlowIndex index, DateTime start, DateTime end) {
    final startIdx = index.indexAtOrAfter(start);
    final endIdx = index.indexAtOrAfter(end);
    final unique = <String>{};
    for (var i = startIdx; i < endIdx; i++) {
      unique.add(index.events[i].contactKey);
    }
    return _WindowStats(
      messageCount: endIdx - startIdx,
      uniqueContacts: unique.length,
    );
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
    required this.totalMessages,
    required this.uniqueContacts,
    required this.fullSpan,
  });

  final DateTime start;
  final DateTime end;
  final int totalMessages;
  final int uniqueContacts;
  final Duration fullSpan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_dateFmt.format(start)}  →  ${_dateFmt.format(end)}',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  '$totalMessages messages · $uniqueContacts contacts in window',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
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
    required this.playing,
    required this.onTogglePlay,
    required this.speed,
    required this.onSpeed,
  });

  final double position;
  final ValueChanged<double> onPosition;
  final _Window window;
  final ValueChanged<_Window> onWindow;
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
        ],
      ),
    );
  }
}
