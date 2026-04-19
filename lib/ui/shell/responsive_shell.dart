import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

/// All 9 categories. On mobile the first 4 live in the bottom NavigationBar
/// with a 'More' tab opening a bottom sheet of the rest.
const destinations = <ShellDestination>[
  ShellDestination(label: 'Me', icon: Icons.person_outline, selectedIcon: Icons.person, route: '/me'),
  ShellDestination(label: 'Network', icon: Icons.people_outline, selectedIcon: Icons.people, route: '/network'),
  ShellDestination(label: 'Messages', icon: Icons.chat_bubble_outline, selectedIcon: Icons.chat_bubble, route: '/messages'),
  ShellDestination(label: 'Career', icon: Icons.work_outline, selectedIcon: Icons.work, route: '/career'),
  ShellDestination(label: 'Learning', icon: Icons.school_outlined, selectedIcon: Icons.school, route: '/learning'),
  ShellDestination(label: 'Skills', icon: Icons.workspace_premium_outlined, selectedIcon: Icons.workspace_premium, route: '/skills'),
  ShellDestination(label: 'Content', icon: Icons.edit_note_outlined, selectedIcon: Icons.edit_note, route: '/content'),
  ShellDestination(label: 'Activity', icon: Icons.bolt_outlined, selectedIcon: Icons.bolt, route: '/activity'),
  ShellDestination(label: 'Account', icon: Icons.manage_accounts_outlined, selectedIcon: Icons.manage_accounts, route: '/account'),
  ShellDestination(label: 'Advisor', icon: Icons.assistant_outlined, selectedIcon: Icons.assistant, route: '/advisor'),
];

const _mobilePrimary = 4; // first 4 get tabs, rest live under "More"

class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w < 600) return _MobileShell(child: child);
        return _DesktopShell(extended: w > 1024, child: child);
      },
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final primary = destinations.take(_mobilePrimary).toList();
    final overflow = destinations.skip(_mobilePrimary).toList();
    final primaryIndex = primary.indexWhere((d) => location.startsWith(d.route));
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
  const _DesktopShell({required this.child, required this.extended});

  final Widget child;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selected = destinations
        .indexWhere((d) => location.startsWith(d.route))
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
