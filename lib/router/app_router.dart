import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/archive_controller.dart';
import '../ui/screens/about_screen.dart';
import '../ui/screens/account_screen.dart';
import '../ui/screens/activity_screen.dart';
import '../ui/screens/career_screen.dart';
import '../ui/screens/content_screen.dart';
import '../ui/screens/flows_screen.dart';
import '../ui/screens/landing_screen.dart';
import '../ui/screens/learning_screen.dart';
import '../ui/screens/loading_screen.dart';
import '../ui/screens/me_screen.dart';
import '../ui/screens/messages_screen.dart';
import '../ui/screens/network_screen.dart';
import '../ui/screens/raw_file_screen.dart';
import '../ui/screens/search_screen.dart';
import '../ui/screens/skills_education_screen.dart';
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
      // Let / and /about render with no archive.
      if (!isLoading && !hasArchive && loc != '/' && loc != '/about') {
        return '/';
      }
      if (hasArchive && (loc == '/' || loc == '/loading')) return '/me';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (c, s) => const LandingScreen()),
      GoRoute(path: '/loading', builder: (c, s) => const LoadingScreen()),
      GoRoute(
        path: '/about',
        builder: (c, s) {
          final hasArchive =
              ref.read(archiveControllerProvider).valueOrNull != null;
          return Scaffold(
            appBar: AppBar(
              title: const Text('About'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => c.go(hasArchive ? '/me' : '/'),
              ),
            ),
            body: const AboutScreen(),
          );
        },
      ),
      ShellRoute(
        builder: (c, s, child) => ResponsiveShell(child: child),
        routes: [
          GoRoute(path: '/me', builder: (c, s) => const MeScreen()),
          GoRoute(path: '/network', builder: (c, s) => const NetworkScreen()),
          GoRoute(path: '/messages', builder: (c, s) => const MessagesScreen()),
          GoRoute(path: '/flow', builder: (c, s) => const FlowsScreen()),
          GoRoute(path: '/career', builder: (c, s) => const CareerScreen()),
          GoRoute(path: '/learning', builder: (c, s) => const LearningScreen()),
          GoRoute(path: '/skills', builder: (c, s) => const SkillsEducationScreen()),
          GoRoute(path: '/content', builder: (c, s) => const ContentScreen()),
          GoRoute(path: '/activity', builder: (c, s) => const ActivityScreen()),
          GoRoute(path: '/account', builder: (c, s) => const AccountScreen()),
          GoRoute(path: '/search', builder: (c, s) => const SearchScreen()),
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
