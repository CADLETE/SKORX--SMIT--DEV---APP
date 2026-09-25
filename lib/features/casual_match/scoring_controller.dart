import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../sports/core/match_rules.dart';
import '../../sports/core/score_state.dart';
import '../../sports/core/scoring_engine.dart';
import '../auth/auth_controller.dart';
import 'local_match.dart';

/// What a player chose on the create-match screen.
class NewMatch {
  const NewMatch({
    required this.sportId,
    required this.categoryId,
    required this.sideA,
    required this.sideB,
    required this.rules,
    required this.firstServer,
    this.locationName,
  });

  final String sportId;
  final String categoryId;
  final List<String> sideA;
  final List<String> sideB;
  final MatchRules rules;
  final Side firstServer;
  final String? locationName;
}

final scoringControllerProvider = NotifierProvider<ScoringController, LocalMatch?>(ScoringController.new);

/// The casual match being scored on this phone, if any. Every change is
/// written to the phone before the screen updates, so closing the app, a
/// crash or a flat battery never loses a point.
class ScoringController extends Notifier<LocalMatch?> {
  static const _storageKey = 'skorx.activeMatch';
  static const _uuid = Uuid();

  /// Resolves once the saved match (if any) has been read.
  late final Future<void> ready;

  @override
  LocalMatch? build() {
    ready = _restore();
    return null;
  }

  Future<void> _restore() async {
    final raw = await ref.read(preferencesProvider).getString(_storageKey);
    if (raw == null) return;
    try {
      state = LocalMatch.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A saved match this version cannot read is dropped rather than
      // blocking the app. It stays in storage until the next match replaces it.
    }
  }

  Future<void> start(NewMatch match) async {
    await _save(LocalMatch(
      id: _uuid.v4(),
      sportId: match.sportId,
      categoryId: match.categoryId,
      sideA: match.sideA,
      sideB: match.sideB,
      rules: match.rules,
      firstServer: match.firstServer,
      locationName: match.locationName,
      startedAt: DateTime.now(),
    ));
  }

  /// Records that [side] won the rally. Ignored once the match is over, so a
  /// late double tap cannot add a point to a finished match.
  Future<void> rallyWonBy(Side side) => _record(RallyWon(side));

  Future<void> correctServe(ServeState serve) => _record(ServeCorrected(serve));

  Future<void> _record(ScoringEvent event) async {
    final match = state;
    if (match == null || match.finishedAt != null || match.score.isOver) return;
    final events = [...match.events, RecordedEvent(id: _uuid.v4(), event: event, recordedAt: DateTime.now())];
    final next = match.copyWith(events: events);
    await _save(next.score.isOver ? next.copyWith(finishedAt: DateTime.now()) : next);
  }

  /// Takes back the last recorded action, including the point that ended the
  /// match (until the result is closed).
  Future<void> undo() async {
    final match = state;
    if (match == null || match.events.isEmpty) return;
    final events = match.events.sublist(0, match.events.length - 1);
    await _save(match.copyWith(events: events, reopen: true));
  }

  /// Closes the finished match so a new one can start.
  Future<void> close() async {
    await ref.read(preferencesProvider).remove(_storageKey);
    state = null;
  }

  Future<void> _save(LocalMatch match) async {
    await ref.read(preferencesProvider).setString(_storageKey, jsonEncode(match.toJson()));
    state = match;
  }
}
