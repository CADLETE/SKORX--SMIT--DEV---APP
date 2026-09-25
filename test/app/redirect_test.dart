import 'package:flutter_test/flutter_test.dart';
import 'package:skorx/app/routing/redirect.dart';
import 'package:skorx/features/auth/auth_controller.dart';
import 'package:skorx/features/workspace/workspace.dart';
import 'package:skorx/features/workspace/workspace_controller.dart';

import '../support/fakes.dart';

void main() {
  final organizer = user(memberships: [membership('org1', 'CADLETE Pickleball', 'owner')]);
  final available = workspacesFor(organizer);

  WorkspaceState ready({String current = 'player', Map<String, String> locations = const {}}) => WorkspaceState(
        available: available,
        current: available.firstWhere((w) => w.key == current),
        lastLocations: locations,
        ready: true,
      );

  String? go(AuthState auth, String location, [WorkspaceState? workspaces]) =>
      redirectFor(auth: auth, workspaces: workspaces ?? ready(), location: location);

  test('waits on the splash screen while the session is restored', () {
    expect(go(const AuthRestoring(), '/player/home'), Routes.splash);
    expect(go(const AuthRestoring(), Routes.splash), isNull);
  });

  test('sends a signed-out user to sign-in from anywhere', () {
    expect(go(const SignedOut(), '/org/org1/dashboard'), Routes.login);
    expect(go(const SignedOut(), Routes.login), isNull);
  });

  test('asks a new player for their profile before anything else', () {
    final fresh = SignedIn(user(name: '', profileComplete: false));
    expect(go(fresh, '/player/home'), Routes.profileSetup);
    expect(go(fresh, Routes.profileSetup), isNull);
  });

  test('holds on the splash screen until the saved workspace is known', () {
    expect(go(SignedIn(organizer), Routes.login, WorkspaceState.initial), Routes.splash);
  });

  test('opens the current workspace where the user left it', () {
    expect(go(SignedIn(organizer), Routes.splash), '/player/home');
    expect(
      go(SignedIn(organizer), Routes.login, ready(current: 'org:org1', locations: {'org:org1': '/org/org1/schedule'})),
      '/org/org1/schedule',
    );
  });

  test('lets the user move within workspaces they have', () {
    expect(go(SignedIn(organizer), '/org/org1/matches'), isNull);
    expect(go(SignedIn(organizer), '/player/paddle'), isNull);
  });

  test('sends links into workspaces the user does not have to Player home', () {
    expect(go(SignedIn(organizer), '/org/someone-else/dashboard'), '/player/home');
    expect(go(SignedIn(organizer), '/referee/current'), '/player/home');
  });
}
