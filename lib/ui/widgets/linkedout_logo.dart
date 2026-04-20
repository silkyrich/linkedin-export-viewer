import 'package:flutter/material.dart';

/// Parody LinkedIn wordmark for LinkedOut!. Rounded square in the familiar
/// LinkedIn blue with a white "out↗" instead of "in". The italic stem and
/// the upward-right arrow are the joke; everything else is earnest.
class LinkedOutLogo extends StatelessWidget {
  const LinkedOutLogo({
    this.size = 28,
    this.showExclamation = false,
    super.key,
  });

  /// Edge length of the rounded-square badge. The "out" text scales with it.
  final double size;

  /// When true, a tiny "!" floats next to the arrow — useful at larger
  /// sizes (landing hero). Off by default for compact icon use.
  final bool showExclamation;

  static const _linkedInBlue = Color(0xFF0A66C2);

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.22;
    return Tooltip(
      message: 'LinkedOut!',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _linkedInBlue,
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: size * 0.08),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'out',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -4),
                child: const Icon(
                  Icons.arrow_outward,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              if (showExclamation)
                const Text(
                  '!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
