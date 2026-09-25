import '../../sports/core/match_rules.dart';
import '../../sports/core/score_state.dart';
import '../../sports/core/scoring_engine.dart';
import '../../sports/core/sport_definition.dart';
import '../../sports/sport_registry.dart';

/// One thing the official did, with the ids the API needs to accept it
/// exactly once when it syncs.
class RecordedEvent {
  const RecordedEvent({required this.id, required this.event, required this.recordedAt});

  final String id;
  final ScoringEvent event;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': recordedAt.toIso8601String(),
        ...switch (event) {
          RallyWon(:final side) => {'kind': 'rally', 'side': side.name},
          ServeCorrected(:final serve) => {'kind': 'serve', 'side': serve.side.name, 'serverNumber': serve.serverNumber},
        },
      };

  factory RecordedEvent.fromJson(Map<String, dynamic> json) {
    final side = Side.values.byName(json['side'] as String);
    return RecordedEvent(
      id: json['id'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      event: json['kind'] == 'serve' ? ServeCorrected(ServeState(side, json['serverNumber'] as int?)) : RallyWon(side),
    );
  }
}

/// A casual match being scored on this phone. The score is never stored: it
/// is always replayed from [events] through the sport's engine.
class LocalMatch {
  const LocalMatch({
    required this.id,
    required this.sportId,
    required this.categoryId,
    required this.sideA,
    required this.sideB,
    required this.rules,
    required this.firstServer,
    required this.startedAt,
    this.events = const [],
    this.finishedAt,
    this.locationName,
  });

  final String id;
  final String sportId;
  final String categoryId;

  /// Player names per side, in court order.
  final List<String> sideA;
  final List<String> sideB;
  final MatchRules rules;
  final Side firstServer;
  final DateTime startedAt;
  final List<RecordedEvent> events;
  final DateTime? finishedAt;
  final String? locationName;

  SportDefinition get sport => SportRegistry.standard.of(sportId)!;

  MatchSetup get setup => MatchSetup(rules: rules, playersPerSide: sideA.length, firstServer: firstServer);

  ScoreState get score => sport.engine.replay(setup, events.map((e) => e.event));

  List<String> names(Side side) => side == Side.a ? sideA : sideB;

  String label(Side side) => names(side).join(' / ');

  /// [reopen] clears [finishedAt], for undoing the match-winning point.
  LocalMatch copyWith({List<RecordedEvent>? events, DateTime? finishedAt, bool reopen = false}) => LocalMatch(
        id: id,
        sportId: sportId,
        categoryId: categoryId,
        sideA: sideA,
        sideB: sideB,
        rules: rules,
        firstServer: firstServer,
        startedAt: startedAt,
        events: events ?? this.events,
        finishedAt: reopen ? null : finishedAt ?? this.finishedAt,
        locationName: locationName,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sportId': sportId,
        'categoryId': categoryId,
        'sideA': sideA,
        'sideB': sideB,
        'rules': rules.toJson(),
        'firstServer': firstServer.name,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'locationName': locationName,
        'events': events.map((e) => e.toJson()).toList(),
      };

  factory LocalMatch.fromJson(Map<String, dynamic> json) => LocalMatch(
        id: json['id'] as String,
        sportId: json['sportId'] as String,
        categoryId: json['categoryId'] as String,
        sideA: (json['sideA'] as List<dynamic>).cast<String>(),
        sideB: (json['sideB'] as List<dynamic>).cast<String>(),
        rules: MatchRules.parse(json['rules']).rules!,
        firstServer: Side.values.byName(json['firstServer'] as String),
        startedAt: DateTime.parse(json['startedAt'] as String),
        finishedAt: json['finishedAt'] == null ? null : DateTime.parse(json['finishedAt'] as String),
        locationName: json['locationName'] as String?,
        events: (json['events'] as List<dynamic>).cast<Map<String, dynamic>>().map(RecordedEvent.fromJson).toList(),
      );
}
