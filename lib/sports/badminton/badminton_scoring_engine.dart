import '../core/score_state.dart';
import '../core/scoring_engine.dart';

/// Badminton: rally scoring, the rally winner serves, and the winner of a
/// game serves first in the next one. The 30-point cap comes from the rules.
class BadmintonScoringEngine extends PointsScoringEngine {
  const BadmintonScoringEngine();

  @override
  ServeState openingServe(MatchSetup setup, Side firstServer) => ServeState(firstServer);

  @override
  Side firstServerOfNextGame({required Side previousFirstServer, required Side previousGameWinner}) =>
      previousGameWinner;

  @override
  RallyOutcome resolveRally(MatchSetup setup, ScoreState state, Side rallyWinner) =>
      RallyOutcome(scored: true, serve: ServeState(rallyWinner));
}
