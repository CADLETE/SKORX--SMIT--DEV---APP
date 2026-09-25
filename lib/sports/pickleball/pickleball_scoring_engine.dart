import '../core/match_rules.dart';
import '../core/score_state.dart';
import '../core/scoring_engine.dart';

/// Pickleball, rally or traditional side-out scoring, singles or doubles.
///
/// Side-out doubles follows the rule the existing SkorX app scores by: the
/// side serving first in a game starts on its second server ("0-0-2"), each
/// later service turn uses server 1 then server 2, and only the serving side
/// scores.
class PickleballScoringEngine extends PointsScoringEngine {
  const PickleballScoringEngine();

  @override
  ServeState openingServe(MatchSetup setup, Side firstServer) =>
      _usesServerNumbers(setup) ? ServeState(firstServer, 2) : ServeState(firstServer);

  /// Sides alternate serving first from game to game.
  @override
  Side firstServerOfNextGame({required Side previousFirstServer, required Side previousGameWinner}) =>
      previousFirstServer.opponent;

  @override
  RallyOutcome resolveRally(MatchSetup setup, ScoreState state, Side rallyWinner) {
    if (setup.rules.scoring == ScoringSystem.rally) {
      return RallyOutcome(scored: true, serve: ServeState(rallyWinner));
    }

    final serve = state.serve;
    if (rallyWinner == serve.side) return RallyOutcome(scored: true, serve: serve);

    if (_usesServerNumbers(setup) && serve.serverNumber == 1) {
      return RallyOutcome(scored: false, serve: ServeState(serve.side, 2));
    }
    return RallyOutcome(
      scored: false,
      serve: _usesServerNumbers(setup) ? ServeState(serve.side.opponent, 1) : ServeState(serve.side.opponent),
    );
  }

  @override
  String scoreCall(MatchSetup setup, ScoreState state) {
    final base = super.scoreCall(setup, state);
    final number = state.serve.serverNumber;
    return number == null ? base : '$base-$number';
  }

  bool _usesServerNumbers(MatchSetup setup) => setup.rules.scoring == ScoringSystem.sideOut && setup.isDoubles;
}
