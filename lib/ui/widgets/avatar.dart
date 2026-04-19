import 'package:flutter/material.dart';

/// Deterministic colored avatar. Same name always gets the same hue, so
/// Ada Lovelace is always the same blue wherever she appears in the app.
///
/// We don't pull LinkedIn images (CORS-blocked + privacy-hostile) and we
/// don't use Gravatar (leaks contact email hashes to a third party). This
/// gives the UI a lot more visual personality than the default grey
/// CircleAvatar at zero privacy cost.
class Avatar extends StatelessWidget {
  const Avatar({
    required this.name,
    this.size = 40,
    this.isSelf = false,
    super.key,
  });

  final String name;
  final double size;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isSelf) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: Text(
          _initials(name),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: size * 0.38,
          ),
        ),
      );
    }

    final baseHue = _stableHue(name);
    final brightness = theme.brightness;
    // Pastel in light mode, deeper saturation in dark mode so it still pops.
    final bg = HSLColor.fromAHSL(
      1,
      baseHue,
      brightness == Brightness.light ? 0.55 : 0.45,
      brightness == Brightness.light ? 0.78 : 0.32,
    ).toColor();
    final fg = HSLColor.fromAHSL(
      1,
      baseHue,
      0.7,
      brightness == Brightness.light ? 0.22 : 0.92,
    ).toColor();

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: bg,
      foregroundColor: fg,
      child: Text(
        _initials(name),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

/// FNV-1a 32-bit hash of the lowercased, whitespace-normalized name,
/// mapped to 0..360.
double _stableHue(String name) {
  final s = name.trim().toLowerCase();
  if (s.isEmpty) return 0;
  var h = 2166136261;
  for (final code in s.codeUnits) {
    h ^= code;
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  return (h % 360).toDouble();
}

String _initials(String name) {
  final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }
  return (parts.first.characters.first + parts[1].characters.first).toUpperCase();
}
