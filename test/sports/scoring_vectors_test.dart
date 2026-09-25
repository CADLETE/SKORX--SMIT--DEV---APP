import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skorx/sports/core/match_rules.dart';
import 'package:skorx/sports/core/score_state.dart';
import 'package:skorx/sports/core/scoring_engine.dart';
import 'package:skorx/sports/sport_registry.dart';

/// Expands ["ab*2", "a"] into rally winners a, b, a, b, a.
List<Side> expandRallies(List<dynamic> segments) {
  final winners = <Side>[];
  for (final segment in segments.cast<String>()) {
    final parts = segment.split('*');
    final times = parts.length == 2 ? int.parse(parts[1]) : 1;
    for (var i = 0; i < times; i++) {
      winners.addAll(parts[0].split('').map((c) => Side.values.byName(c)));
    }
  }
  return winners;
}

String serveLabel(ServeState serve) => '${serve.side.name}${serve.serverNumber ?? ''}';

void main() {
  final file = File('test/fixtures/scoring_vectors.json');
  final cases = (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)['cases'] as List<dynamic>;

  for (final raw in cases.cast<Map<String, dynamic>>()) {
    test(raw['name'], () {
      final sport = SportRegistry.standard.of(raw['sport'] as String)!;
      final setup = MatchSetup(
        rules: MatchRules.parse(raw['rules']).rules!,
        playersPerSide: raw['playersPerSide'] as int,
        firstServer: Side.values.byName(raw['firstServer'] as String),
      );

      var state = sport.engine.start(setup);
      final allEvents = <ScoringEvent>[];

      for (final checkpoint in (raw['checkpoints'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        for (final winner in expandRallies(checkpoint['rallies'] as List<dynamic>)) {
          state = sport.engine.rally(setup, state, winner);
          allEvents.add(RallyWon(winner));
        }
        final at = 'after ${allEvents.length} rallies';

        if (checkpoint['games'] != null) {
          expect(state.games.map((g) => g.toString()).toList(), checkpoint['games'], reason: at);
        }
        if (checkpoint['serve'] != null) expect(serveLabel(state.serve), checkpoint['serve'], reason: at);
        if (checkpoint['call'] != null) expect(sport.engine.scoreCall(setup, state), checkpoint['call'], reason: at);
        if (checkpoint['gamesWon'] != null) {
          expect([state.gamesWonA, state.gamesWonB], checkpoint['gamesWon'], reason: at);
        }
        expect(state.winner?.name, checkpoint['winner'], reason: at);

        // Replaying the same events from scratch must land on the same state.
        final replayed = sport.engine.replay(setup, allEvents);
        expect(replayed.games, state.games, reason: '$at (replay)');
        expect(replayed.serve, state.serve, reason: '$at (replay)');
      }
    });
  }
}
