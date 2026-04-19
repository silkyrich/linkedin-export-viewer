import 'dart:math';

import 'package:flutter/material.dart';

import '../../state/flow_index.dart';

/// A single contact resolved to its layout position, ready to paint.
class FlowNode {
  FlowNode({
    required this.contact,
    required this.position,
    required this.angle,
    required this.radius,
    required this.windowOutgoing,
    required this.windowIncoming,
  });

  final FlowContact contact;
  final Offset position;
  final double angle;
  final double radius;
  final int windowOutgoing;
  final int windowIncoming;

  int get windowTotal => windowOutgoing + windowIncoming;
}

class FlowGraphData {
  FlowGraphData({
    required this.meName,
    required this.meCenter,
    required this.nodes,
  });

  final String meName;
  final Offset meCenter;
  final List<FlowNode> nodes;
}

/// Radial layout:
///   - Me at the center.
///   - Top-N contacts (by window activity; or by lifetime total when the
///     window has zero messages for everyone) laid out around a ring.
///   - Edge thickness scales with log(windowTotal + 1).
///   - Hue biased red for mostly-outgoing, blue for mostly-incoming.
class FlowPainter extends CustomPainter {
  FlowPainter({
    required this.data,
    required this.selectedKey,
    required this.theme,
    this.pulsePhase = 0,
  });

  final FlowGraphData data;
  final String? selectedKey;
  final ColorScheme theme;

  /// 0..1 — when > 0, active-in-window nodes get an animated halo.
  final double pulsePhase;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = theme.surface;
    canvas.drawRect(Offset.zero & size, bg);

    // Edges first so nodes overlay them. Gradient-stroked from the
    // incoming colour at "me" to the outgoing colour at the contact.
    for (final node in data.nodes) {
      if (node.windowTotal == 0) continue;
      final thickness = (log(node.windowTotal + 1) * 1.8).clamp(1.5, 16.0);
      final outRatio = node.windowOutgoing / node.windowTotal;
      final meSide = Color.lerp(theme.tertiary, theme.primary, outRatio)!;
      final otherSide = Color.lerp(theme.primary, theme.tertiary, outRatio)!;
      final dim = selectedKey != null && selectedKey != node.contact.key;
      final alpha = dim ? 0.12 : 0.6;
      final shader = LinearGradient(
        colors: [
          meSide.withValues(alpha: alpha),
          otherSide.withValues(alpha: alpha),
        ],
      ).createShader(Rect.fromPoints(data.meCenter, node.position));
      final paint = Paint()
        ..shader = shader
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(data.meCenter, node.position, paint);
    }

    // Me node
    final meRadius = 24.0;
    final mePaint = Paint()..color = theme.primary;
    canvas.drawCircle(data.meCenter, meRadius, mePaint);
    final meLabel = TextPainter(
      text: TextSpan(
        text: _initials(data.meName),
        style: TextStyle(
          color: theme.onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    meLabel.paint(
      canvas,
      data.meCenter - Offset(meLabel.width / 2, meLabel.height / 2),
    );

    // Pulse halo on active-in-window contacts — a quiet heartbeat so
    // you can tell which nodes are "live" during playback. Phase 0..1
    // comes from the AnimationController in FlowsScreen.
    if (pulsePhase > 0) {
      for (final node in data.nodes) {
        if (node.windowTotal == 0) continue;
        if (selectedKey != null && selectedKey != node.contact.key) continue;
        final t = pulsePhase;
        final haloR = node.radius + 4 + t * 14;
        final haloAlpha = (1 - t) * 0.35;
        final haloPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = theme.primary.withValues(alpha: haloAlpha);
        canvas.drawCircle(node.position, haloR, haloPaint);
      }
    }

    // Contact nodes
    for (final node in data.nodes) {
      final isSelected = selectedKey == node.contact.key;
      final activeInWindow = node.windowTotal > 0;
      final dimmed = selectedKey != null && !isSelected;
      final fill = activeInWindow
          ? Color.lerp(
              theme.tertiaryContainer,
              theme.primaryContainer,
              node.windowOutgoing / max(node.windowTotal, 1),
            )!
          : theme.surfaceContainerHigh;
      final fillPaint = Paint()
        ..color = dimmed ? fill.withValues(alpha: 0.3) : fill;
      canvas.drawCircle(node.position, node.radius, fillPaint);
      if (isSelected) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = theme.primary;
        canvas.drawCircle(node.position, node.radius + 3, ring);
      }

      if (node.radius < 6 && !isSelected) continue;
      final label = TextPainter(
        text: TextSpan(
          text: _initials(node.contact.name),
          style: TextStyle(
            color: activeInWindow
                ? theme.onPrimaryContainer
                : theme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: node.radius > 12 ? 12 : 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        node.position - Offset(label.width / 2, label.height / 2),
      );
    }

    // Tooltip for selected node
    final selected = data.nodes.where((n) => n.contact.key == selectedKey).firstOrNull;
    if (selected != null) {
      _paintTooltip(canvas, size, selected);
    }
  }

  void _paintTooltip(Canvas canvas, Size size, FlowNode node) {
    final txt = TextPainter(
      text: TextSpan(
        style: TextStyle(color: theme.onInverseSurface, fontSize: 12),
        children: [
          TextSpan(
            text: '${node.contact.name}\n',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: 'Window: ${node.windowOutgoing} sent · ${node.windowIncoming} received\n'
                'Lifetime: ${node.contact.totalOutgoing} sent · ${node.contact.totalIncoming} received',
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      maxLines: 4,
    )..layout(maxWidth: size.width - 32);

    final pad = const EdgeInsets.symmetric(horizontal: 10, vertical: 8);
    final rect = Rect.fromLTWH(
      16,
      16,
      txt.width + pad.horizontal,
      txt.height + pad.vertical,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = theme.inverseSurface);
    txt.paint(canvas, rect.topLeft + Offset(pad.left, pad.top));
  }

  @override
  bool shouldRepaint(covariant FlowPainter old) {
    return old.data != data ||
        old.selectedKey != selectedKey ||
        old.theme != theme ||
        old.pulsePhase != pulsePhase;
  }

  /// Hit-test against contact nodes. Returns the key of the top-most node
  /// under [local], or null.
  String? nodeAt(Offset local) {
    // Iterate in reverse so foreground nodes win.
    for (var i = data.nodes.length - 1; i >= 0; i--) {
      final n = data.nodes[i];
      if ((n.position - local).distance <= n.radius + 2) {
        return n.contact.key;
      }
    }
    return null;
  }
}

String _initials(String name) {
  final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
