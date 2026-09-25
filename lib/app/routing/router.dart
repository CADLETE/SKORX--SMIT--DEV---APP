import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_page.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/ui/profile_setup_screen.dart';
import '../../features/auth/ui/sign_in_screen.dart';
import '../../features/casual_match/ui/create_match_screen.dart';
import '../../features/casual_match/ui/scoring_screen.dart';
import '../../features/organizer/organizer_pages.dart';
import '../../features/player/home/player_home_page.dart';
import '../../features/player/player_pages.dart';
import '../../features/referee/referee_pages.dart';
import '../../features/shell/workspace_shell.dart';
import '../../features/workspace/workspace_controller.dart';
import '../../shared/widgets.dart';
import 'redirect.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects when sign-in or the set of workspaces changes, not on
  // every recorded location.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.listen(workspaceControllerProvider, (previous, next) {
    if (previous?.ready != next.ready || previous?.available != next.available) refresh.value++;
  });

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      auth: ref.read(authControllerProvider),
      workspaces: ref.read(workspaceControllerProvider),
      location: state.uri.path,
    ),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.profileSetup, builder: (_, _) => const ProfileSetupScreen()),
      // Full-screen, outside the tab bar, but still in the Player workspace.
      GoRoute(
        path: '/player/match/new',
        builder: (_, state) => CreateMatchScreen(initialCategoryId: state.uri.queryParameters['type']),
      ),
      GoRoute(path: '/player/match', builder: (_, _) => const ScoringScreen()),
      _shell(playerDestinations, [
        _tab('/player/home', const PlayerHomePage()),
        _tab('/player/paddle', const MyPaddlePage()),
        _tab('/player/tournaments', const PlayerTournamentsPage()),
        _tab('/player/matches', const PlayerMatchesPage()),
        _tab('/player/profile', const AccountPage()),
      ], fullBleedTabs: const {0}),
      // Organizer tabs live under /org/:orgId, and go_router's tab branches
      // cannot start on a parameterized path, so this shell works out the
      // selected tab from the location instead.
      ShellRoute(
        builder: (context, state, child) {
          final orgId = state.pathParameters['orgId']!;
          final tab = state.uri.pathSegments.length > 2 ? state.uri.pathSegments[2] : organizerTabs.first;
          return WorkspaceShell(
            destinations: organizerDestinations,
            currentIndex: organizerTabs.indexOf(tab).clamp(0, organizerTabs.length - 1),
            onSelect: (index) => GoRouter.of(context).go('/org/$orgId/${organizerTabs[index]}'),
            child: child,
          );
        },
        routes: [
          _tab('/org/:orgId/dashboard', const OrganizerDashboardPage()),
          _tab('/org/:orgId/tournaments', const OrganizerTournamentsPage()),
          _tab('/org/:orgId/matches', const OrganizerMatchesPage()),
          _tab('/org/:orgId/schedule', const OrganizerSchedulePage()),
          GoRoute(
            path: '/org/:orgId/more',
            pageBuilder: (_, state) =>
                NoTransitionPage(child: OrganizerMorePage(organizationId: state.pathParameters['orgId']!)),
          ),
        ],
      ),
      _shell(refereeDestinations, [
        _tab('/referee/current', const RefereeListPage.current()),
        _tab('/referee/upcoming', const RefereeListPage.upcoming()),
        _tab('/referee/completed', const RefereeListPage.completed()),
        _tab('/referee/profile', const AccountPage()),
      ]),
    ],
  );

  // Remember where the user is, per workspace. Deferred so the provider is
  // never written while widgets are building.
  void record() {
    final location = router.routerDelegate.currentConfiguration.uri.path;
    scheduleMicrotask(() => ref.read(workspaceControllerProvider.notifier).recordLocation(location));
  }

  router.routerDelegate.addListener(record);
  ref.onDispose(() {
    router.routerDelegate.removeListener(record);
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Path segment of each organizer tab, in navigation order.
const organizerTabs = ['dashboard', 'tournaments', 'matches', 'schedule', 'more'];

GoRoute _tab(String path, Widget page) => GoRoute(path: path, pageBuilder: (_, _) => NoTransitionPage(child: page));

/// One workspace's navigation shell. Each tab keeps its own stack.
StatefulShellRoute _shell(List<ShellDestination> destinations, List<GoRoute> tabs, {Set<int> fullBleedTabs = const {}}) =>
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) => WorkspaceShell.stateful(
        navigationShell: navigationShell,
        destinations: destinations,
        fullBleedTabs: fullBleedTabs,
      ),
      branches: [for (final tab in tabs) StatefulShellBranch(routes: [tab])],
    );

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkorxLogo(height: 72),
              SizedBox(height: 24),
              SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            ],
          ),
        ),
      );
}
