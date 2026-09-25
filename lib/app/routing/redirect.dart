import '../../features/auth/auth_controller.dart';
import '../../features/workspace/workspace.dart';
import '../../features/workspace/workspace_controller.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const profileSetup = '/profile-setup';
}

/// Where the router should send the user instead of [location], or null to
/// stay. Pure, so every rule is unit-tested without widgets.
String? redirectFor({required AuthState auth, required WorkspaceState workspaces, required String location}) {
  String? goTo(String target) => target == location ? null : target;

  switch (auth) {
    case AuthRestoring():
      return goTo(Routes.splash);
    case SignedOut():
      return goTo(Routes.login);
    case SignedIn(:final user):
      if (!user.profileComplete) return goTo(Routes.profileSetup);
      if (!workspaces.ready) return goTo(Routes.splash);

      final entry = workspaces.entryLocation(workspaces.current);
      if (location == Routes.splash || location == Routes.login || location == Routes.profileSetup || location == '/') {
        return entry;
      }
      // A link into a workspace the user does not have (an organization
      // they left, a referee screen without the role) lands on Player home.
      // The server refuses the data regardless.
      if (workspaces.ownerOf(location) == null) return const PlayerWorkspace().homeLocation;
      return null;
  }
}
