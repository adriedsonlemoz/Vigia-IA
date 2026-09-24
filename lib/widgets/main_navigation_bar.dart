import 'package:flutter/material.dart';

import '../core/adaptive_layout.dart';

const _mainDestinations = <({IconData icon, IconData selectedIcon, String label})>[
  (icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Início'),
  (icon: Icons.history_outlined, selectedIcon: Icons.history_rounded, label: 'Histórico'),
  (icon: Icons.videocam_outlined, selectedIcon: Icons.videocam_rounded, label: 'Ao vivo'),
  (icon: Icons.video_library_outlined, selectedIcon: Icons.video_library_rounded, label: 'Câmeras'),
  (icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: 'Ajustes'),
];

class MainNavigationBar extends StatelessWidget {
  const MainNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        for (final destination in _mainDestinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    );
  }
}

class MainNavigationRail extends StatelessWidget {
  const MainNavigationRail({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.selected,
      minWidth: 70,
      groupAlignment: -0.65,
      destinations: [
        for (final destination in _mainDestinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}

/// Shared shell for the five primary destinations.
///
/// Portrait phones keep the bottom NavigationBar. Landscape phones and tablets
/// move navigation to a compact left rail so the limited vertical space is not
/// consumed by a permanent bottom bar.
class AdaptiveMainScaffold extends StatelessWidget {
  const AdaptiveMainScaffold({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.body,
    this.appBar,
    this.backgroundColor,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final useRail = AdaptiveLayout.useNavigationRail(context);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      bottomNavigationBar: useRail
          ? null
          : MainNavigationBar(
              currentIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
            ),
      body: useRail
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafeArea(
                  top: false,
                  right: false,
                  child: MainNavigationRail(
                    currentIndex: currentIndex,
                    onDestinationSelected: onDestinationSelected,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
                ),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }
}
