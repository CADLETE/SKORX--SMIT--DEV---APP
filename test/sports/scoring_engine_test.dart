import 'package:flutter_test/flutter_test.dart';
import 'package:skorx/sports/core/match_rules.dart';
import 'package:skorx/sports/core/score_state.dart';
import 'package:skorx/sports/core/scoring_engine.dart';
import 'package:skorx/sports/sport_registry.dart';

void main() {
  final engine = pickleball.engine;
  const doubles = MatchSetup(
    rules: MatchRules(pointsToWin: 11, winByTwo: true, bestOf: 3, scoring: ScoringSystem.sideOut),
    playersPerSide: 2,
    firstServer: Side.a,
  );

  group('undo', () {
    test('is a replay without the last event, including serve changes', () {
      final events = [const RallyWon(Side.a), const RallyWon(Side.b), const RallyWon(Side.b)];
      final full = engine.replay(doubles, events);
      final undone = engine.replay(doubles, events.sublist(0, events.length - 1));

      expect(full.currentGame, const GameScore(1, 1));
      expect(undone.currentGame, const GameScore(1, 0));
      expect(undone.serve, const ServeState(Side.b, 1));
    });

    test('can step back over a finished game', () {
      const shortRules = MatchSetup(
        rules: MatchRules(pointsToWin: 2, winByTwo: false, bestOf: 3),
        playersPerSide: 1,
        firstServer: Side.a,
      );
      final events = List.filled(2, const RallyWon(Side.a));
      expect(engine.replay(shortRules, events).gameNumber, 2);

      final undone = engine.replay(shortRules, events.sublist(0, 1));
      expect(undone.gameNumber, 1);
      expect(undone.gamesWonA, 0);
      expect(undone.currentGame, const GameScore(1, 0));
    });
  });

  group('serve correction', () {
    test('changes who serves without touching the score', () {
      final events = <ScoringEvent>[const RallyWon(Side.a), const ServeCorrected(ServeState(Side.b, 1))];
      final state = engine.replay(doubles, events);
      expect(state.currentGame, const GameScore(1, 0));
      expect(state.serve, const ServeState(Side.b, 1));

      // The corrected server then plays on under the normal rules.
      final next = engine.rally(doubles, state, Side.a);
      expect(next.serve, const ServeState(Side.b, 2));
    });
  });

  group('match end', () {
    test('rejects rallies once the match is over', () {
      const oneGame = MatchSetup(
        rules: MatchRules(pointsToWin: 1, winByTwo: false, bestOf: 1),
        playersPerSide: 1,
        firstServer: Side.a,
      );
      final state = engine.rally(oneGame, engine.start(oneGame), Side.b);
      expect(state.winner, Side.b);
      expect(() => engine.rally(oneGame, state, Side.a), throwsStateError);
      expect(() => engine.correctServe(state, const ServeState(Side.a)), throwsStateError);
    });

    test('does not open another game after the deciding one', () {
      const bestOf3 = MatchSetup(
        rules: MatchRules(pointsToWin: 1, winByTwo: false, bestOf: 3),
        playersPerSide: 1,
        firstServer: Side.a,
      );
      final state = engine.replay(bestOf3, const [RallyWon(Side.a), RallyWon(Side.a)]);
      expect(state.games, const [GameScore(1, 0), GameScore(1, 0)]);
      expect(state.winner, Side.a);
    });
  });

  group('side-out scoring', () {
    test('a full side-out game can only be won on serve', () {
      const setup = MatchSetup(
        rules: MatchRules(pointsToWin: 11, winByTwo: true, bestOf: 1, scoring: ScoringSystem.sideOut),
        playersPerSide: 1,
        firstServer: Side.a,
      );
      var state = engine.start(setup);
      // Side b wins every rally: the first only wins the serve back.
      for (var i = 0; i < 12; i++) {
        state = engine.rally(setup, state, Side.b);
      }
      expect(state.currentGame, const GameScore(0, 11));
      expect(state.winner, Side.b);
      expect(state.rallies, 12);
    });
  });
}
