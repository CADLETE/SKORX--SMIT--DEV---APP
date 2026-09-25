import '../core/score_state.dart';
import '../core/scoring_engine.dart';

/// Table tennis: every rally scores; service changes every two points, and
/// every point once both sides reach one short of the target (10-10 in a game
/// to 11). Sides alternate serving first from game to game.
class TableTennisScoringEngine extends PointsScoringEngine {
  const TableTennisScoringEngine();

  @override
  ServeState openingServe(MatchSetup setup, Side firstServer) => ServeState(firstServer);

  @override
  Side firstServerOfNextGame({required Side previousFirstServer, required Side previousGameWinner}) =>
      previousFirstServer.opponent;

  @override
  RallyOutcome resolveRally(MatchSetup setup, ScoreState state, Side rallyWinner) {
    final game = state.currentGame.plus(rallyWinner);
    final played = game.a + game.b;
    final deuceFrom = 2 * (setup.rules.pointsToWin - 1);
    final turns = played < deuceFrom ? played ~/ 2 : (deuceFrom ~/ 2) + (played - deuceFrom);
    final server = turns.isEven ? state.firstServerOfGame : state.firstServerOfGame.opponent;
    return RallyOutcome(scored: true, serve: ServeState(server));
  }
}
