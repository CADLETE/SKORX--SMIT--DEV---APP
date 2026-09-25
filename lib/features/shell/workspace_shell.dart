import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../workspace/workspace_switcher.dart';

class ShellDestination {
  const ShellDestination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Room at the bottom of scrolling pages so content clears the floating
/// navigation bar.
const floatingNavClearance = 120.0;

/// The frame of one workspace: switcher chip on top, the workspace's own
/// bottom navigation below. Each workspace builds its own shell, so no
/// workspace ever shows another's tabs.
class WorkspaceShell extends ConsumerWidget {
  const WorkspaceShell({
    super.key,
    required this.child,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    this.fullBleedTabs = const {},
  });

  /// A shell whose tabs each keep their own navigation stack.
  factory WorkspaceShell.stateful({
    required StatefulNavigationShell navigationShell,
    required List<ShellDestination> destinations,
    Set<int> fullBleedTabs = const {},
  }) =>
      WorkspaceShell(
        destinations: destinations,
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        fullBleedTabs: fullBleedTabs,
        child: navigationShell,
      );

  final Widget child;
  final List<ShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// Tabs that draw their own header (Player Home), so the shell's top bar
  /// is hidden there.
  final Set<int> fullBleedTabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final offline = auth is SignedIn && auth.fromCache;
    final fullBleed = fullBleedTabs.contains(currentIndex);

    return Scaffold(
      // Content scrolls underneath the floating navigation bar.
      extendBody: true,
      appBar: fullBleed
          ? null
          : AppBar(
              toolbarHeight: 64,
              titleSpacing: SkorxSpace.lg,
              title: const Align(alignment: Alignment.centerLeft, child: WorkspaceChip()),
              actions: const [
                Padding(padding: EdgeInsets.only(right: SkorxSpace.lg), child: SkorxLogo(height: 30)),
              ],
            ),
      body: Column(
        children: [
          if (offline) SafeArea(bottom: false, child: const OfflineBanner()),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: _FloatingNav(destinations: destinations, currentIndex: currentIndex, onSelect: onSelect),
    );
  }
}

/// A floating, frosted navigation bar with a glowing active tab.
class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.destinations, required this.currentIndex, required this.onSelect});

  final List<ShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(SkorxSpace.md, 0, SkorxSpace.md, SkorxSpace.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SkorxRadius.xl),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SkorxRadius.xl),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(SkorxRadius.xl),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: NavigationBar(
                height: 66,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                selectedIndex: currentIndex,
                onDestinationSelected: onSelect,
                destinations: [
                  for (final d in destinations)
                    NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrollable page body with the standard gutters.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(SkorxSpace.lg, SkorxSpace.sm, SkorxSpace.lg, floatingNavClearance),
        children: children,
      );
}
