import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/archive_controller.dart';
import '../ui/screens/landing_screen.dart';
import '../ui/screens/loading_screen.dart';
import '../ui/screens/me_screen.dart';
import '../ui/screens/messages_screen.dart';
import '../ui/screens/network_screen.dart';
import '../ui/screens/raw_file_screen.dart';
import '../ui/shell/responsive_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // go_router re-evaluates redirects whenever this listener fires.
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final archiveState = ref.read(archiveControllerProvider);
      final hasArchive = archiveState.valueOrNull != null;
      final isLoading = archiveState.isLoading;
      final loc = state.matchedLocation;

      if (isLoading && loc != '/loading') return '/loading';
      if (!isLoading && !hasArchive && loc != '/') return '/';
      if (hasArchive && (loc == '/' || loc == '/loading')) return '/me';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (c, s) => const LandingScreen()),
      GoRoute(path: '/loading', builder: (c, s) => const LoadingScreen()),
      ShellRoute(
        builder: (c, s, child) => ResponsiveShell(child: child),
        routes: [
          GoRoute(path: '/me', builder: (c, s) => const MeScreen()),
          GoRoute(path: '/network', builder: (c, s) => const NetworkScreen()),
          GoRoute(path: '/messages', builder: (c, s) => const MessagesScreen()),
          GoRoute(
            path: '/raw/:path(.*)',
            builder: (c, s) => RawFileScreen(
              path: Uri.decodeComponent(s.pathParameters['path'] ?? ''),
            ),
          ),
        ],
      ),
    ],
  );
});

/// Bridges a Riverpod [archiveControllerProvider] into a Listenable that
/// go_router can subscribe to for redirect re-evaluation.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _sub = _ref.listen<AsyncValue<Object?>>(
      archiveControllerProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<Object?>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
