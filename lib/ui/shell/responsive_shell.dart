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

const _destinations = <ShellDestination>[
  ShellDestination(
    label: 'Messages',
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    route: '/messages',
  ),
  // Subsequent phases will slot Me, Network, Career etc. in here.
];

/// Adaptive navigation chrome:
///   * < 600 wide → bottom NavigationBar
///   * 600–1024  → NavigationRail alongside the content
///   * > 1024    → extended NavigationRail (label-visible)
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _destinations
        .indexWhere((d) => location.startsWith(d.route))
        .clamp(0, _destinations.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w < 600) {
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const PrivacyBanner(),
                  Expanded(child: child),
                ],
              ),
            ),
            bottomNavigationBar: _destinations.length < 2
                ? null
                : NavigationBar(
                    selectedIndex: selectedIndex,
                    destinations: [
                      for (final d in _destinations)
                        NavigationDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: d.label,
                        ),
                    ],
                    onDestinationSelected: (i) => context.go(_destinations[i].route),
                  ),
          );
        }

        if (_destinations.length < 2) {
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const PrivacyBanner(),
                  Expanded(child: child),
                ],
              ),
            ),
          );
        }
        final extended = w > 1024;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  extended: extended,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (i) => context.go(_destinations[i].route),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
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
      },
    );
  }
}
