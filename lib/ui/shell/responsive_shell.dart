import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/archive_controller.dart';
import 'privacy_banner.dart';

class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

/// Destination list. The /me route takes the archive owner's first name
/// as its label (falls back to "You" if we can't derive one).
List<ShellDestination> _destinationsFor(String meLabel) {
  return [
    ShellDestination(label: meLabel, icon: Icons.person_outline, selectedIcon: Icons.person, route: '/me'),
    const ShellDestination(label: 'Insights', icon: Icons.insights_outlined, selectedIcon: Icons.insights, route: '/insights'),
    const ShellDestination(label: 'Network', icon: Icons.people_outline, selectedIcon: Icons.people, route: '/network'),
    const ShellDestination(label: 'Messages', icon: Icons.chat_bubble_outline, selectedIcon: Icons.chat_bubble, route: '/messages'),
    const ShellDestination(label: 'Career', icon: Icons.work_outline, selectedIcon: Icons.work, route: '/career'),
    const ShellDestination(label: 'Learning', icon: Icons.school_outlined, selectedIcon: Icons.school, route: '/learning'),
    const ShellDestination(label: 'Skills', icon: Icons.workspace_premium_outlined, selectedIcon: Icons.workspace_premium, route: '/skills'),
    const ShellDestination(label: 'Content', icon: Icons.edit_note_outlined, selectedIcon: Icons.edit_note, route: '/content'),
    const ShellDestination(label: 'Activity', icon: Icons.bolt_outlined, selectedIcon: Icons.bolt, route: '/activity'),
    const ShellDestination(label: 'Account', icon: Icons.manage_accounts_outlined, selectedIcon: Icons.manage_accounts, route: '/account'),
    const ShellDestination(label: 'Advisor', icon: Icons.assistant_outlined, selectedIcon: Icons.assistant, route: '/advisor'),
  ];
}

/// Derive a short label for the /me tab from Profile.csv first name.
String _meLabel(WidgetRef ref) {
  final archive = ref.watch(archiveControllerProvider).valueOrNull;
  if (archive == null) return 'You';
  final profile = archive.file('Profile.csv');
  if (profile == null || profile.rows.isEmpty) return 'You';
  final headers = profile.headers;
  final row = profile.rows.first;
  final firstIdx = headers.indexOf('First Name');
  if (firstIdx < 0 || firstIdx >= row.length) return 'You';
  final first = row[firstIdx].trim();
  if (first.isEmpty) return 'You';
  // Keep it short for the bottom nav — no more than 10 chars.
  return first.length > 10 ? '${first.substring(0, 9)}…' : first;
}

const _mobilePrimary = 4; // first 4 get tabs, rest live under "More"

class ResponsiveShell extends ConsumerWidget {
  const ResponsiveShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = _destinationsFor(_meLabel(ref));
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w < 600) {
          return _MobileShell(destinations: destinations, child: child);
        }
        return _DesktopShell(
          extended: w > 1024,
          destinations: destinations,
          child: child,
        );
      },
    );
  }
}

/// True when [location] is the route itself or one of its subpaths
/// (e.g. /career matches /career/2, but /me does NOT match /messages).
bool _routeMatches(String location, String route) {
  if (location == route) return true;
  return location.startsWith('$route/') || location.startsWith('$route?');
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.child, required this.destinations});

  final Widget child;
  final List<ShellDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final primary = destinations.take(_mobilePrimary).toList();
    final overflow = destinations.skip(_mobilePrimary).toList();
    final primaryIndex =
        primary.indexWhere((d) => _routeMatches(location, d.route));
    final selected = primaryIndex == -1 ? _mobilePrimary : primaryIndex;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PrivacyBanner(),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        destinations: [
          for (final d in primary)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
        onDestinationSelected: (i) {
          if (i < primary.length) {
            context.go(primary[i].route);
          } else {
            _showMore(context, overflow);
          }
        },
      ),
    );
  }

  void _showMore(BuildContext context, List<ShellDestination> overflow) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in overflow)
              ListTile(
                leading: Icon(d.icon),
                title: Text(d.label),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go(d.route);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.child,
    required this.extended,
    required this.destinations,
  });

  final Widget child;
  final bool extended;
  final List<ShellDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selected = destinations
        .indexWhere((d) => _routeMatches(location, d.route))
        .clamp(0, destinations.length - 1);
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            SingleChildScrollView(
              child: IntrinsicHeight(
                child: NavigationRail(
                  extended: extended,
                  selectedIndex: selected,
                  onDestinationSelected: (i) => context.go(destinations[i].route),
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  const PrivacyBanner(),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
