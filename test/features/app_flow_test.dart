import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skorx/app/app.dart';
import 'package:skorx/features/auth/data/auth_repository.dart';
import 'package:skorx/features/workspace/workspace_switcher.dart';

import '../support/fakes.dart';

Future<void> pumpApp(WidgetTester tester, FakeAuthRepository repo) async {
  useReducedMotion(tester);
  await tester.pumpWidget(ProviderScope(overrides: appOverrides(repo), child: const SkorxApp()));
  await tester.pumpAndSettle();
}

Finder navLabel(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// Opens the switcher and picks [title], waiting out the short
/// "Switching to" transition, which holds no animation for settle to see.
Future<void> switchWorkspaceTo(WidgetTester tester, String title) async {
  // Player Home has its own header: the avatar opens the switcher there.
  final avatar = find.byKey(const Key('homeAvatar'));
  await tester.tap(avatar.evaluate().isNotEmpty ? avatar : find.byType(WorkspaceChip));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title).last);
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

void main() {
  setUp(useInMemoryPreferences);

  testWidgets('a new player signs in with mobile and code, sets up a profile, and lands on Player home',
      (tester) async {
    final repo = FakeAuthRepository();
    await pumpApp(tester, repo);

    expect(find.text('Sign in with your mobile'), findsOneWidget);
    final continueButton = find.byKey(const Key('signInPrimary'));
    await tester.enterText(find.byKey(const Key('mobileField')), '12345');
    await tester.pump();
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull, reason: 'invalid number cannot continue');

    await tester.enterText(find.byKey(const Key('mobileField')), '9586545430');
    await tester.pump();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(repo.sentTo, ['9586545430']);
    expect(find.text('Enter the code'), findsOneWidget);
    expect(find.text('Resend in 30s'), findsOneWidget);

    // A wrong code shows the server's message and clears the field.
    await tester.enterText(find.byKey(const Key('codeField')), '000000');
    await tester.pumpAndSettle();
    expect(find.text('That code is not right. 4 tries left.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('codeField')), '123456');
    await tester.pumpAndSettle();
    expect(find.text('Set up your profile'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('nameField')), 'Smit Ramani');
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveProfile')));
    await tester.pumpAndSettle();

    expect(repo.savedProfile?.name, 'Smit Ramani');
    expect(find.text('SMIT'), findsOneWidget, reason: 'Home greets the player by first name');
    for (final tab in ['Home', 'My Paddle', 'Tournaments', 'Matches', 'Profile']) {
      expect(navLabel(tab), findsOneWidget, reason: tab);
    }
    // Stop the resend timer from the sign-in screen outliving the test.
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('one account moves Player -> Organizer -> Referee -> Player, keeping its place in each',
      (tester) async {
    final repo = FakeAuthRepository(
      stored: RestoredUser(
        user(memberships: [
          membership('org1', 'CADLETE Pickleball', 'owner', {'managePayments', 'editTournament', 'manageSettings'}),
          membership('org2', 'XYZ Sports', 'referee', {'scoreAssignedMatch'}),
        ]),
        fromCache: false,
      ),
    );
    await pumpApp(tester, repo);

    // Player workspace: player tabs only, no organizer tools.
    expect(navLabel('My Paddle'), findsOneWidget);
    expect(navLabel('Schedule'), findsNothing);
    await tester.tap(navLabel('My Paddle'));
    await tester.pumpAndSettle();

    Future<void> switchTo(String title) => switchWorkspaceTo(tester, title);

    await switchTo('CADLETE Pickleball');
    for (final tab in ['Dashboard', 'Tournaments', 'Matches', 'Schedule', 'More']) {
      expect(navLabel(tab), findsOneWidget, reason: tab);
    }
    expect(navLabel('My Paddle'), findsNothing, reason: 'player tabs are gone in Organizer');
    await tester.tap(navLabel('Schedule'));
    await tester.pumpAndSettle();

    await switchTo('Referee');
    for (final tab in ['Current', 'Upcoming', 'Completed', 'Profile']) {
      expect(navLabel(tab), findsOneWidget, reason: tab);
    }
    expect(navLabel('Dashboard'), findsNothing, reason: 'referees never see organizer navigation');

    await switchTo('Player');
    expect(find.text('Performance'.toUpperCase()), findsOneWidget, reason: 'back on My Paddle where the player left');

    await switchTo('CADLETE Pickleball');
    expect(find.text('Nothing scheduled'), findsOneWidget, reason: 'back on Schedule in the organization');
  });

  testWidgets('organizer "More" shows only the tools the role allows', (tester) async {
    final repo = FakeAuthRepository(
      stored: RestoredUser(
        user(memberships: [membership('org1', 'CADLETE Pickleball', 'check_in_staff', {'manageCheckIn'})]),
        fromCache: false,
      ),
    );
    await pumpApp(tester, repo);
    await switchWorkspaceTo(tester, 'CADLETE Pickleball');
    await tester.tap(navLabel('More'));
    await tester.pumpAndSettle();

    expect(find.text('Check-in'), findsOneWidget);
    expect(find.text('Payments'), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('a plain player has no workspace switcher to open', (tester) async {
    await pumpApp(tester, FakeAuthRepository(stored: RestoredUser(user(), fromCache: false)));
    expect(find.bySemanticsLabel(RegExp('Switch workspace')), findsNothing);
    // On Home the avatar opens the profile instead of a switcher.
    await tester.tap(find.byKey(const Key('homeAvatar')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
    // Other tabs show the workspace chip, with nothing to switch to.
    expect(find.bySemanticsLabel('Workspace: Player'), findsOneWidget);
  });

  testWidgets('starting offline opens the app from the saved account with an offline notice', (tester) async {
    await pumpApp(tester, FakeAuthRepository(stored: RestoredUser(user(), fromCache: true)));
    expect(find.text('Offline. Showing what was saved on this phone.'), findsOneWidget);
    expect(navLabel('Home'), findsOneWidget);
  });

  testWidgets('signing out returns to sign-in', (tester) async {
    final repo = FakeAuthRepository(stored: RestoredUser(user(), fromCache: false));
    await pumpApp(tester, repo);
    await tester.tap(navLabel('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(repo.signedOut, isTrue);
    expect(find.text('Sign in with your mobile'), findsOneWidget);
  });
}
