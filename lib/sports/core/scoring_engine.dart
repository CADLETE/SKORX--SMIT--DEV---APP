import 'match_rules.dart';
import 'score_state.dart';

/// Fixed facts about a match that the engine needs alongside its rules.
class MatchSetup {
  const MatchSetup({required this.rules, required this.playersPerSide, required this.firstServer});

  final MatchRules rules;

  /// 1 for singles, 2 for doubles.
  final int playersPerSide;
  final Side firstServer;

  bool get isDoubles => playersPerSide == 2;
}

/// Turns rally results into a score. Screens never apply scoring rules
/// themselves: they report who won each rally and render the state.
///
/// Scoring is a pure fold over the rallies, so undo is "replay without the
/// last rally" and an offline device and the server can always agree on the
/// score from the same event list.
abstract class ScoringEngine {
  const ScoringEngine();

  ScoreState start(MatchSetup setup);

  /// The state after one more rally won by [rallyWinner].
  /// Throws [StateError] once the match is over.
  ScoreState rally(MatchSetup setup, ScoreState state, Side rallyWinner);

  /// How an official would call the score, e.g. "4-2-1" in pickleball doubles.
  String scoreCall(MatchSetup setup, ScoreState state) {
    final serving = state.currentGame.of(state.serve.side);
    final receiving = state.currentGame.of(state.serve.side.opponent);
    return '$serving-$receiving';
  }

  /// The official overrides who is serving (the "Change service" action).
  /// The score is untouched.
  ScoreState correctServe(ScoreState state, ServeState serve) {
    if (state.isOver) throw StateError('The match is over.');
    return state.copyWith(serve: serve);
  }

  ScoreState apply(MatchSetup setup, ScoreState state, ScoringEvent event) => switch (event) {
        RallyWon(:final side) => rally(setup, state, side),
        ServeCorrected(:final serve) => correctServe(state, serve),
      };

  ScoreState replay(MatchSetup setup, Iterable<ScoringEvent> events) =>
      events.fold(start(setup), (state, event) => apply(setup, state, event));
}

/// What an official records. The score is always derived from these.
sealed class ScoringEvent {
  const ScoringEvent();
}

class RallyWon extends ScoringEvent {
  const RallyWon(this.side);

  final Side side;
}

class ServeCorrected extends ScoringEvent {
  const ServeCorrected(this.serve);

  final ServeState serve;
}

/// Whether the winner of a rally scores, and who serves next.
class RallyOutcome {
  const RallyOutcome({required this.scored, required this.serve});

  final bool scored;
  final ServeState serve;
}

/// Shared game and match bookkeeping for sports played as best of N games to
/// a points target. Subclasses only decide who scores and who serves.
abstract class PointsScoringEngine extends ScoringEngine {
  const PointsScoringEngine();

  /// Serve at the start of a game that [firstServer] serves first.
  ServeState openingServe(MatchSetup setup, Side firstServer);

  /// Who serves first in the next game.
  Side firstServerOfNextGame({required Side previousFirstServer, required Side previousGameWinner});

  RallyOutcome resolveRally(MatchSetup setup, ScoreState state, Side rallyWinner);

  @override
  ScoreState start(MatchSetup setup) => ScoreState(
        games: const [GameScore.zero],
        serve: openingServe(setup, setup.firstServer),
        firstServerOfGame: setup.firstServer,
      );

  @override
  ScoreState rally(MatchSetup setup, ScoreState state, Side rallyWinner) {
    if (state.isOver) throw StateError('The match is over.');

    final outcome = resolveRally(setup, state, rallyWinner);
    final game = outcome.scored ? state.currentGame.plus(rallyWinner) : state.currentGame;
    final played = [...state.games.take(state.games.length - 1), game];
    final gameWinner = gameWinnerOf(game, setup.rules);

    if (gameWinner == null) {
      return state.copyWith(games: played, serve: outcome.serve, rallies: state.rallies + 1);
    }

    final gamesWonA = state.gamesWonA + (gameWinner == Side.a ? 1 : 0);
    final gamesWonB = state.gamesWonB + (gameWinner == Side.b ? 1 : 0);
    final needed = setup.rules.gamesToWin;

    if (gamesWonA >= needed || gamesWonB >= needed) {
      return state.copyWith(
        games: played,
        serve: outcome.serve,
        gamesWonA: gamesWonA,
        gamesWonB: gamesWonB,
        winner: gameWinner,
        rallies: state.rallies + 1,
      );
    }

    final nextFirstServer = firstServerOfNextGame(
      previousFirstServer: state.firstServerOfGame,
      previousGameWinner: gameWinner,
    );
    return state.copyWith(
      games: [...played, GameScore.zero],
      serve: openingServe(setup, nextFirstServer),
      firstServerOfGame: nextFirstServer,
      gamesWonA: gamesWonA,
      gamesWonB: gamesWonB,
      rallies: state.rallies + 1,
    );
  }
}

/// The side that has won [game], or null while it is still going. Same rule
/// as the server's `isGameComplete`, including the point cap.
Side? gameWinnerOf(GameScore game, MatchRules rules) {
  final leader = game.a > game.b ? Side.a : Side.b;
  final high = game.a > game.b ? game.a : game.b;
  final diff = (game.a - game.b).abs();
  final cap = rules.pointCap;
  if (cap != null && high >= cap && diff >= 1) return leader;
  if (high < rules.pointsToWin) return null;
  return diff >= (rules.winByTwo ? 2 : 1) ? leader : null;
}
