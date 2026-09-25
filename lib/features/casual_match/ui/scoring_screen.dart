import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../sports/core/match_rules.dart';
import '../../../sports/core/score_state.dart';
import '../local_match.dart';
import '../scoring_controller.dart';

/// The clock behind the double-tap guard; tests replace it.
final scoringClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// What a tap on [side]'s half does right now, in the old app's words.
String rallyActionLabel(LocalMatch match, ScoreState score, Side side) {
  if (match.rules.scoring == ScoringSystem.rally || side == score.serve.side) return 'POINT';
  if (score.serve.serverNumber == 1) return '2ND SERVER';
  return 'SIDE OUT';
}

/// Live scoring for a casual match. Each half of the screen is one big
/// button: "this side won the rally". The engine decides whether that is a
/// point or a change of serve.
class ScoringScreen extends ConsumerStatefulWidget {
  const ScoringScreen({super.key});

  /// Taps closer together than this are treated as one accidental double tap.
  static const tapGuard = Duration(milliseconds: 400);

  @override
  ConsumerState<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends ConsumerState<ScoringScreen> {
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    // The screen stays on while scoring; a dark phone mid-rally loses points.
    WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  Future<void> _rally(Side side) async {
    final now = ref.read(scoringClockProvider)();
    if (now.difference(_lastTap) < ScoringScreen.tapGuard) return;
    _lastTap = now;
    HapticFeedback.mediumImpact();
    await ref.read(scoringControllerProvider.notifier).rallyWonBy(side);
  }

  Future<void> _undo() async {
    HapticFeedback.lightImpact();
    await ref.read(scoringControllerProvider.notifier).undo();
  }

  Future<void> _changeService(LocalMatch match, ScoreState score) async {
    final options = <ServeState>[
      for (final side in Side.values)
        if (score.serve.serverNumber == null)
          ServeState(side)
        else ...[ServeState(side, 1), ServeState(side, 2)],
    ];
    final chosen = await showModalBottomSheet<ServeState>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: SkorxSpace.sm),
              child: Text('Who is serving?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            for (final option in options)
              ListTile(
                title: Text(match.label(option.side)),
                subtitle: option.serverNumber == null ? null : Text('Server ${option.serverNumber}'),
                trailing: option == score.serve ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && chosen != score.serve) {
      await ref.read(scoringControllerProvider.notifier).correctServe(chosen);
    }
  }

  Future<void> _finish() async {
    await ref.read(scoringControllerProvider.notifier).close();
    if (mounted) context.go('/player/home');
  }

  @override
  Widget build(BuildContext context) {
    final match = ref.watch(scoringControllerProvider);
    if (match == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No match in progress.')),
      );
    }
    final score = match.score;
    final colors = context.skorx.colors;
    final sport = match.sport;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to home. The match stays saved.',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/player/home'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              score.isOver ? 'Final' : '${sport.gameLabel} ${score.gameNumber}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(match.rules.describe(), style: TextStyle(fontSize: 12, color: colors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('undo'),
            tooltip: 'Undo last point',
            onPressed: match.events.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'serve') _changeService(match, score);
            },
            itemBuilder: (_) => [
              if (!score.isOver) const PopupMenuItem(value: 'serve', child: Text('Change service')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _SidePanel(match: match, score: score, side: Side.a, onTap: _rally)),
            _CenterStrip(match: match, score: score),
            Expanded(child: _SidePanel(match: match, score: score, side: Side.b, onTap: _rally)),
            if (score.isOver) _ResultBar(match: match, score: score, onDone: _finish),
          ],
        ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.match, required this.score, required this.side, required this.onTap});

  final LocalMatch match;
  final ScoreState score;
  final Side side;
  final ValueChanged<Side> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    final serving = score.serve.side == side;
    final points = score.currentGame.of(side);
    final action = rallyActionLabel(match, score, side);
    final won = score.winner == side;
    final base = side == Side.a ? colors.navy : const Color(0xFF123A66);

    return Semantics(
      button: !score.isOver,
      label: '${match.label(side)}, $points, ${score.gamesWon(side)} games'
          '${serving ? ', serving${score.serve.serverNumber == null ? '' : ' server ${score.serve.serverNumber}'}' : ''}'
          '${score.isOver ? '' : '. Tap for $action'}',
      excludeSemantics: true,
      child: Material(
        color: won ? colors.success.withValues(alpha: 0.25) : base,
        child: InkWell(
          key: Key('side-${side.name}'),
          onTap: score.isOver ? null : () => onTap(side),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SkorxSpace.xl, vertical: SkorxSpace.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final name in match.names(side))
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      const SizedBox(height: SkorxSpace.sm),
                      if (serving && !score.isOver)
                        Row(
                          children: [
                            Icon(Icons.sports_tennis_rounded, size: 18, color: colors.lime),
                            const SizedBox(width: 6),
                            Text(
                              score.serve.serverNumber == null ? 'Serving' : 'Server ${score.serve.serverNumber}',
                              style: TextStyle(color: colors.lime, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      if (won)
                        const Text('WINNER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      child: Text(
                        '$points',
                        key: Key('points-${side.name}'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 96,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (!score.isOver)
                      Text(
                        action,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterStrip extends StatelessWidget {
  const _CenterStrip({required this.match, required this.score});

  final LocalMatch match;
  final ScoreState score;

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    final finished = score.isOver ? score.games : score.games.sublist(0, score.games.length - 1);
    return Container(
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: SkorxSpace.lg, vertical: SkorxSpace.sm),
      child: Row(
        children: [
          if (!score.isOver)
            Semantics(
              label: 'Score call ${match.sport.engine.scoreCall(match.setup, score)}',
              excludeSemantics: true,
              child: Text(
                match.sport.engine.scoreCall(match.setup, score),
                key: const Key('scoreCall'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
          const Spacer(),
          for (final game in finished)
            Padding(
              padding: const EdgeInsets.only(left: SkorxSpace.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: SkorxSpace.md, vertical: SkorxSpace.xs),
                decoration: BoxDecoration(
                  color: colors.surfaceInteractive,
                  borderRadius: BorderRadius.circular(SkorxRadius.xl),
                ),
                child: Text('$game', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultBar extends StatelessWidget {
  const _ResultBar({required this.match, required this.score, required this.onDone});

  final LocalMatch match;
  final ScoreState score;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final winner = score.winner!;
    final colors = context.skorx.colors;
    final result = '${score.gamesWon(winner)}-${score.gamesWon(winner.opponent)}';
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.all(SkorxSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              '${match.label(winner)} won $result',
              key: const Key('result'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: colors.limeText),
            ),
          ),
          const SizedBox(height: SkorxSpace.md),
          FilledButton(key: const Key('done'), onPressed: onDone, child: const Text('Done')),
        ],
      ),
    );
  }
}
