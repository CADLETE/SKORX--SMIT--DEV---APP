/// The two sides of a match. Matches the API's `MatchSideKey`.
enum Side {
  a,
  b;

  Side get opponent => this == Side.a ? Side.b : Side.a;
}

/// Points in one game.
class GameScore {
  const GameScore(this.a, this.b);

  static const zero = GameScore(0, 0);

  final int a;
  final int b;

  int of(Side side) => side == Side.a ? a : b;

  GameScore plus(Side side) => side == Side.a ? GameScore(a + 1, b) : GameScore(a, b + 1);

  @override
  bool operator ==(Object other) => other is GameScore && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);

  @override
  String toString() => '$a-$b';
}

/// Who is serving. [serverNumber] is 1 or 2 in doubles side-out scoring and
/// null everywhere else.
class ServeState {
  const ServeState(this.side, [this.serverNumber]);

  final Side side;
  final int? serverNumber;

  @override
  bool operator ==(Object other) => other is ServeState && other.side == side && other.serverNumber == serverNumber;

  @override
  int get hashCode => Object.hash(side, serverNumber);

  @override
  String toString() => serverNumber == null ? 'serve ${side.name}' : 'serve ${side.name}$serverNumber';
}

/// Everything a scoreboard needs, derived purely from the rallies played.
/// Immutable: engines return a new state for every rally.
class ScoreState {
  const ScoreState({
    required this.games,
    required this.serve,
    required this.firstServerOfGame,
    this.gamesWonA = 0,
    this.gamesWonB = 0,
    this.winner,
    this.rallies = 0,
  });

  /// Every game so far. The last entry is the game in progress, or the
  /// final game once the match is over.
  final List<GameScore> games;
  final ServeState serve;

  /// Who served first in the current game; decides the next game's first server.
  final Side firstServerOfGame;
  final int gamesWonA;
  final int gamesWonB;
  final Side? winner;
  final int rallies;

  GameScore get currentGame => games.last;
  int get gameNumber => games.length;
  bool get isOver => winner != null;

  int gamesWon(Side side) => side == Side.a ? gamesWonA : gamesWonB;

  ScoreState copyWith({
    List<GameScore>? games,
    ServeState? serve,
    Side? firstServerOfGame,
    int? gamesWonA,
    int? gamesWonB,
    Side? winner,
    int? rallies,
  }) =>
      ScoreState(
        games: games ?? this.games,
        serve: serve ?? this.serve,
        firstServerOfGame: firstServerOfGame ?? this.firstServerOfGame,
        gamesWonA: gamesWonA ?? this.gamesWonA,
        gamesWonB: gamesWonB ?? this.gamesWonB,
        winner: winner ?? this.winner,
        rallies: rallies ?? this.rallies,
      );
}
