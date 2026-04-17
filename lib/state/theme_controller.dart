import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theme mode is session-only for now — simpler than plumbing IndexedDB
/// just for one bool, and the cache already re-hydrates the archive.
final themeModeProvider = NotifierProvider<_ThemeModeController, ThemeMode>(
  _ThemeModeController.new,
);

class _ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void toggle() {
    state = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
  }
}
