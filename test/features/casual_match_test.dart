import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skorx/app/app.dart';
import 'package:skorx/features/auth/data/auth_repository.dart';
import 'package:skorx/features/casual_match/scoring_controller.dart';
import 'package:skorx/features/casual_match/ui/scoring_screen.dart';
import 'package:skorx/sports/core/match_rules.dart';
import 'package:skorx/sports/core/score_state.dart';

import '../support/fakes.dart';

final pageScroll = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
const pickleballDefault = MatchRules(pointsToWin: 11, winByTwo: true, bestOf: 3, scoring: ScoringSystem.sideOut);
const shortRules = MatchRules(pointsToWin: 2, winByTwo: false, bestOf: 3, scoring: ScoringSystem.sideOut);

NewMatch doubles({MatchRules rules = shortRules}) => NewMatch(
      sportId: 'pickleball',
      categoryId: 'doubles',
      sideA: const ['Smit Ramani', 'Kamal Parmar'],
      sideB: const ['Anand Varsada', 'Hardik Suthar'],
      rules: rules,
      firstServer: Side.a,
    );

void main() {
  setUp(() {
    useInMemoryPreferences();
    // wakelock_plus talks to the platform; there is none in tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle', (_) async {
      return const StandardMessageCodec().encodeMessage(<Object?>[]);
    });
  });

  group('ScoringController', () {
    Future<ProviderContainer> container() async {
      final c = ProviderContainer(overrides: appOverrides(FakeAuthRepository()));
      addTearDown(c.dispose);
      c.listen(scoringControllerProvider, (_, _) {});
      await c.read(scoringControllerProvider.notifier).ready;
      return c;
    }

    test('scores through the engine and ends the match on a majority of games', () async {
      final c = await container();
      final scoring = c.read(scoringControllerProvider.notifier);
      await scoring.start(doubles());
      // Game 1: A serves and wins 2-0. Game 2: B serves first, so A's first
      // rally only wins the serve back, then A wins 2-0.
      for (var i = 0; i < 5; i++) {
        await scoring.rallyWonBy(Side.a);
      }
      final match = c.read(scoringControllerProvider)!;
      expect(match.score.games, const [GameScore(2, 0), GameScore(2, 0)]);
      expect(match.score.winner, Side.a);
      expect(match.finishedAt, isNotNull);
    });

    test('ignores taps after the match is over', () async {
      final c = await container();
      final scoring = c.read(scoringControllerProvider.notifier);
      await scoring.start(doubles(rules: const MatchRules(pointsToWin: 1, winByTwo: false, bestOf: 1)));
      await scoring.rallyWonBy(Side.b);
      final events = c.read(scoringControllerProvider)!.events.length;
      await scoring.rallyWonBy(Side.a);
      expect(c.read(scoringControllerProvider)!.events, hasLength(events));
    });

    test('undo takes back the winning point and reopens the match', () async {
      final c = await container();
      final scoring = c.read(scoringControllerProvider.notifier);
      await scoring.start(doubles(rules: const MatchRules(pointsToWin: 1, winByTwo: false, bestOf: 1)));
      await scoring.rallyWonBy(Side.b);
      await scoring.undo();
      final match = c.read(scoringControllerProvider)!;
      expect(match.finishedAt, isNull);
      expect(match.score.isOver, isFalse);
    });

    test('survives the app being killed mid-match', () async {
      final first = await container();
      await first.read(scoringControllerProvider.notifier).start(doubles());
      await first.read(scoringControllerProvider.notifier).rallyWonBy(Side.a);
      await first.read(scoringControllerProvider.notifier).rallyWonBy(Side.b);
      final before = first.read(scoringControllerProvider)!;

      final relaunched = await container();
      final after = relaunched.read(scoringControllerProvider)!;
      expect(after.id, before.id);
      expect(after.events.map((e) => e.id), before.events.map((e) => e.id));
      expect(after.score.currentGame, before.score.currentGame);
      expect(after.score.serve, before.score.serve);
    });

    test('closing a finished match clears it from the phone', () async {
      final c = await container();
      await c.read(scoringControllerProvider.notifier).start(doubles());
      await c.read(scoringControllerProvider.notifier).close();
      final relaunched = await container();
      expect(relaunched.read(scoringControllerProvider), isNull);
    });
  });

  group('screens', () {
    late DateTime clock;

    /// Time between taps as the tap guard sees it. One second unless a test
    /// sets it shorter.
    late Duration tapGap;

    Future<void> pumpSignedIn(WidgetTester tester) async {
      useReducedMotion(tester);
      clock = DateTime(2026, 9, 25, 18);
      tapGap = const Duration(seconds: 1);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...appOverrides(FakeAuthRepository(stored: RestoredUser(user(), fromCache: false))),
          scoringClockProvider.overrideWithValue(() => clock = clock.add(tapGap)),
        ],
        child: const SkorxApp(),
      ));
      await tester.pumpAndSettle();
    }

    String points(WidgetTester tester, Side side) =>
        (tester.widget<Text>(find.byKey(Key('points-${side.name}')))).data!;
    String call(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('scoreCall'))).data!;

    testWidgets('home -> new doubles match -> scoring with the old app\'s POINT / SIDE OUT buttons', (tester) async {
      await pumpSignedIn(tester);
      await tester.tap(find.byKey(const Key('startMatchCta')));
      await tester.pumpAndSettle();

      expect(find.text('New match'), findsOneWidget);
      // "You" is prefilled from the account.
      expect(find.widgetWithText(TextField, 'Smit Ramani'), findsOneWidget);
      final start = find.byKey(const Key('startMatch'));
      await tester.scrollUntilVisible(start, 200, scrollable: pageScroll);
      expect(tester.widget<FilledButton>(start).onPressed, isNull, reason: 'names are missing');

      await tester.scrollUntilVisible(find.byKey(const Key('playerA2')), -200, scrollable: pageScroll);
      await tester.enterText(find.byKey(const Key('playerA2')), 'Kamal Parmar');
      await tester.enterText(find.byKey(const Key('playerB1')), 'Anand Varsada');
      await tester.enterText(find.byKey(const Key('playerB2')), 'Hardik Suthar');
      await tester.pump();
      await tester.scrollUntilVisible(start, 200, scrollable: pageScroll);
      await tester.tap(start);
      await tester.pumpAndSettle();

      // Pickleball doubles, side-out: the first server starts as server 2.
      expect(call(tester), '0-0-2');
      expect(find.text('POINT'), findsOneWidget);
      expect(find.text('SIDE OUT'), findsOneWidget);

      await tester.tap(find.byKey(const Key('side-a')));
      await tester.pumpAndSettle();
      expect(points(tester, Side.a), '1');
      expect(call(tester), '1-0-2');

      await tester.tap(find.byKey(const Key('side-b')));
      await tester.pumpAndSettle();
      expect(points(tester, Side.a), '1', reason: 'a side out is not a point');
      expect(call(tester), '0-1-1');
      expect(find.text('2ND SERVER'), findsOneWidget, reason: 'side A would only pass serve to the 2nd server');

      await tester.tap(find.byKey(const Key('undo')));
      await tester.pumpAndSettle();
      expect(call(tester), '1-0-2');
    });

    testWidgets('a double tap within the guard counts once', (tester) async {
      await pumpSignedIn(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(SkorxApp)));
      await container.read(scoringControllerProvider.notifier).start(doubles(rules: pickleballDefault));
      await tester.pump();
      expect(find.text('RESUME MATCH'), findsOneWidget);
      await tester.tap(find.byKey(const Key('startMatchCta')));
      await tester.pumpAndSettle();

      tapGap = const Duration(milliseconds: 100);
      await tester.tap(find.byKey(const Key('side-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('side-a')));
      await tester.pumpAndSettle();
      expect(points(tester, Side.a), '1', reason: 'the second tap came 100 ms after the first');

      tapGap = const Duration(milliseconds: 500);
      await tester.tap(find.byKey(const Key('side-a')));
      await tester.pumpAndSettle();
      expect(points(tester, Side.a), '2', reason: 'a deliberate tap half a second later counts');
    });
  });
}
