import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../sports/core/score_state.dart';
import '../../auth/auth_controller.dart';
import '../../casual_match/local_match.dart';
import '../../casual_match/scoring_controller.dart';
import '../../workspace/workspace_controller.dart';
import '../../workspace/workspace_switcher.dart';
import 'court_painter.dart';

String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// Player home: a sports app, not an admin panel. One big, obvious thing to
/// do (play), what is live, and how the player is doing.
class PlayerHomePage extends ConsumerStatefulWidget {
  const PlayerHomePage({super.key});

  @override
  ConsumerState<PlayerHomePage> createState() => _PlayerHomePageState();
}

class _PlayerHomePageState extends ConsumerState<PlayerHomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _entrance.value = 1;
    } else if (!_entrance.isAnimating && _entrance.value == 0) {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Widget _reveal(int index, Widget child) => _Reveal(controller: _entrance, index: index, child: child);

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(scoringControllerProvider);
    final now = DateTime.now();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        SkorxSpace.lg,
        MediaQuery.paddingOf(context).top + SkorxSpace.md,
        SkorxSpace.lg,
        120,
      ),
      children: [
        _reveal(0, const _HomeHeader()),
        const SizedBox(height: SkorxSpace.xl),
        _reveal(1, active == null ? const _PlayHero() : _LiveMatchHero(match: active)),
        const SizedBox(height: SkorxSpace.xl),
        _reveal(2, _SectionTitle('Your season', trailing: 'PICKLEBALL · ${_months[now.month - 1].toUpperCase()}')),
        _reveal(
          3,
          const Row(
            children: [
              Expanded(child: _StatTile(value: '0', label: 'Matches', icon: Icons.sports_tennis_rounded)),
              SizedBox(width: SkorxSpace.md),
              Expanded(child: _StatTile(value: '-', label: 'Win rate', icon: Icons.trending_up_rounded)),
              SizedBox(width: SkorxSpace.md),
              Expanded(child: _StatTile(value: '0', label: 'Streak', icon: Icons.local_fire_department_rounded)),
            ],
          ),
        ),
        const SizedBox(height: SkorxSpace.xl),
        _reveal(4, const _SectionTitle('Jump in')),
        _reveal(
          5,
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  label: 'Tournaments',
                  icon: Icons.emoji_events_rounded,
                  colors: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
                  onTap: () => context.go('/player/tournaments'),
                ),
              ),
              const SizedBox(width: SkorxSpace.md),
              Expanded(
                child: _ActionTile(
                  label: 'My stats',
                  icon: Icons.insights_rounded,
                  colors: const [Color(0xFF22D3EE), Color(0xFF3B82F6)],
                  onTap: () => context.go('/player/paddle'),
                ),
              ),
              const SizedBox(width: SkorxSpace.md),
              Expanded(
                child: _ActionTile(
                  label: 'History',
                  icon: Icons.history_rounded,
                  colors: const [Color(0xFFA3E635), Color(0xFF10B981)],
                  onTap: () => context.go('/player/matches'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SkorxSpace.xl),
        _reveal(6, const _SectionTitle('Live now', live: true)),
        _reveal(
          7,
          const _FeatureEmpty(
            icon: Icons.sensors_rounded,
            pulse: true,
            title: 'No live matches right now',
            message: 'When your friends or tournaments you follow go live, scores land here in real time.',
          ),
        ),
        const SizedBox(height: SkorxSpace.xl),
        _reveal(8, const _SectionTitle('Recent results')),
        _reveal(
          9,
          _FeatureEmpty(
            icon: Icons.scoreboard_rounded,
            title: 'Your first result is one match away',
            message: 'Every game you score builds your record, your streak and your rivalries.',
            action: active == null
                ? TextButton.icon(
                    onPressed: () => context.go('/player/match/new'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Start a match'),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Fades and slides a section in, one after another.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.controller, required this.index, required this.child});

  final AnimationController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.07).clamp(0.0, 0.6);
    final curve = CurvedAnimation(parent: controller, curve: Interval(start, start + 0.4, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(curve),
        child: child,
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final workspaces = ref.watch(workspaceControllerProvider);
    final colors = context.skorx.colors;
    final name = user?.firstName ?? '';
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final canSwitch = workspaces.available.length > 1;

    return Row(
      children: [
        Semantics(
          button: true,
          label: canSwitch ? 'Switch workspace' : 'Profile',
          excludeSemantics: true,
          child: GestureDetector(
            key: const Key('homeAvatar'),
            onTap: () => canSwitch ? showWorkspaceSwitcher(context) : context.go('/player/profile'),
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [Color(0xFF4DD8F0), Color(0xFFC7EA3A), Color(0xFF3BA0F0), Color(0xFF4DD8F0)]),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: colors.surfaceElevated,
                child: Text(initial, style: SkorxType.headline(26, color: colors.text)),
              ),
            ),
          ),
        ),
        const SizedBox(width: SkorxSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greetingFor(DateTime.now()).toUpperCase(), style: SkorxType.label(color: colors.textMuted, size: 12)),
              const SizedBox(height: 2),
              Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SkorxType.headline(34, color: colors.text),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: SkorxSpace.md, vertical: SkorxSpace.sm),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(SkorxRadius.xl),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlowingBall(size: 14, color: colors.lime),
              const SizedBox(width: SkorxSpace.sm),
              Text('PICKLEBALL', style: SkorxType.label(color: colors.text, size: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The main thing to do: play. A neon court, a floating ball and one big
/// glowing button, with one-tap shortcuts for the usual match types.
class _PlayHero extends StatefulWidget {
  const _PlayHero();

  @override
  State<_PlayHero> createState() => _PlayHeroState();
}

class _PlayHeroState extends State<_PlayHero> with SingleTickerProviderStateMixin {
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(SkorxRadius.xl),
      child: Container(
        height: 330,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1830), Color(0xFF0D2E57), Color(0xFF1466B8)],
            stops: [0, 0.55, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: NeonCourtPainter(
                  lineColor: colors.lime.withValues(alpha: 0.75),
                  kitchenColor: colors.lime.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Light sweep from the top right, like stadium lights.
            Positioned(
              right: -80,
              top: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [colors.cyan.withValues(alpha: 0.35), Colors.transparent]),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _float,
              builder: (context, child) => Positioned(
                right: 46,
                top: 58 - 10 * Curves.easeInOut.transform(_float.value),
                child: child!,
              ),
              child: GlowingBall(size: 34, color: colors.lime),
            ),
            Padding(
              padding: const EdgeInsets.all(SkorxSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('READY TO', style: SkorxType.headline(46, color: Colors.white)),
                  Text('PLAY?', style: SkorxType.headline(58, color: colors.lime)),
                  const SizedBox(height: SkorxSpace.sm),
                  Text(
                    'Score every rally. Own every stat.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14),
                  ),
                  const Spacer(),
                  _GlowButton(
                    key: const Key('startMatchCta'),
                    label: 'START MATCH',
                    icon: Icons.bolt_rounded,
                    onPressed: () => context.go('/player/match/new'),
                  ),
                  const SizedBox(height: SkorxSpace.md),
                  Row(
                    children: [
                      for (final (id, label) in const [('singles', 'SINGLES'), ('doubles', 'DOUBLES'), ('mixed_doubles', 'MIXED')])
                        Padding(
                          padding: const EdgeInsets.only(right: SkorxSpace.sm),
                          child: _GlassChip(label: label, onTap: () => context.go('/player/match/new?type=$id')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A match in progress takes over the hero: a broadcast-style scoreboard.
class _LiveMatchHero extends StatelessWidget {
  const _LiveMatchHero({required this.match});

  final LocalMatch match;

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    final score = match.score;
    final call = match.sport.engine.scoreCall(match.setup, score);

    Widget teamRow(Side side) {
      final serving = !score.isOver && score.serve.side == side;
      return Row(
        children: [
          SizedBox(
            width: 20,
            child: serving ? GlowingBall(size: 12, color: colors.lime) : null,
          ),
          Expanded(
            child: Text(
              match.label(side).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SkorxType.headline(22, color: Colors.white, weight: FontWeight.w800),
            ),
          ),
          for (final game in score.games.take(score.games.length - 1))
            Padding(
              padding: const EdgeInsets.only(left: SkorxSpace.sm),
              child: Text('${game.of(side)}', style: SkorxType.score(20, color: Colors.white.withValues(alpha: 0.55))),
            ),
          const SizedBox(width: SkorxSpace.md),
          Text('${score.currentGame.of(side)}', style: SkorxType.score(56, color: serving ? colors.lime : Colors.white)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(SkorxSpace.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SkorxRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0B14), Color(0xFF0D1B33)],
        ),
        border: Border.all(color: colors.live.withValues(alpha: 0.55)),
        boxShadow: [BoxShadow(color: colors.live.withValues(alpha: 0.25), blurRadius: 28)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LiveBadge(),
              const SizedBox(width: SkorxSpace.md),
              Expanded(
                child: Text(
                  '${match.sport.gameLabel.toUpperCase()} ${score.gameNumber} · ${match.sport.name.toUpperCase()}',
                  style: SkorxType.label(color: Colors.white.withValues(alpha: 0.7), size: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: SkorxSpace.md, vertical: SkorxSpace.xs),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(SkorxRadius.xl),
                ),
                child: Text(call, style: SkorxType.score(18, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: SkorxSpace.lg),
          teamRow(Side.a),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: SkorxSpace.xl),
          teamRow(Side.b),
          const SizedBox(height: SkorxSpace.xl),
          _GlowButton(
            key: const Key('startMatchCta'),
            label: 'RESUME MATCH',
            icon: Icons.play_arrow_rounded,
            onPressed: () => context.go('/player/match'),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = context.skorx.colors.live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SkorxSpace.sm, vertical: 3),
      decoration: BoxDecoration(color: live, borderRadius: BorderRadius.circular(SkorxRadius.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
            child: const Icon(Icons.circle, size: 8, color: Colors.white),
          ),
          const SizedBox(width: 5),
          Text('LIVE', style: SkorxType.label(color: Colors.white, size: 12)),
        ],
      ),
    );
  }
}

/// Neon lime button with a soft glow; the one primary action on screen.
class _GlowButton extends StatelessWidget {
  const _GlowButton({super.key, required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final lime = context.skorx.colors.lime;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: _Pressable(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: lime,
            borderRadius: BorderRadius.circular(SkorxRadius.xl),
            boxShadow: [BoxShadow(color: lime.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 6))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF0B1C33)),
              const SizedBox(width: SkorxSpace.sm),
              Text(label, style: SkorxType.headline(24, color: const Color(0xFF0B1C33), weight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Start a $label match',
      excludeSemantics: true,
      child: _Pressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: SkorxSpace.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(SkorxRadius.xl),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Text(label, style: SkorxType.label(color: Colors.white, size: 13)),
        ),
      ),
    );
  }
}

/// Shrinks slightly under the finger, so taps feel physical.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(scale: _down ? 0.96 : 1, duration: const Duration(milliseconds: 110), child: widget.child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing, this.live = false});

  final String title;
  final String? trailing;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: SkorxSpace.md),
      child: Row(
        children: [
          if (live) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors.live,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: colors.live.withValues(alpha: 0.7), blurRadius: 8)],
              ),
            ),
            const SizedBox(width: SkorxSpace.sm),
          ],
          Text(title.toUpperCase(), style: SkorxType.headline(24, color: colors.text, weight: FontWeight.w800)),
          const Spacer(),
          if (trailing != null) Text(trailing!, style: SkorxType.label(color: colors.textMuted, size: 11)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(SkorxSpace.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SkorxRadius.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.surfaceElevated, colors.surface],
          ),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: colors.cyan),
            const SizedBox(height: SkorxSpace.md),
            Text(value, style: SkorxType.score(38, color: colors.text)),
            const SizedBox(height: 2),
            Text(label.toUpperCase(), style: SkorxType.label(color: colors.textMuted, size: 11)),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.label, required this.icon, required this.colors, required this.onTap});

  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.skorx.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: _Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: SkorxSpace.lg, horizontal: SkorxSpace.sm),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(SkorxRadius.lg),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SkorxRadius.md),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                  boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))],
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: SkorxSpace.sm),
              Text(label.toUpperCase(), style: SkorxType.label(color: theme.text, size: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// An empty section that still looks designed, with a hint of what comes.
class _FeatureEmpty extends StatefulWidget {
  const _FeatureEmpty({required this.icon, required this.title, required this.message, this.pulse = false, this.action});

  final IconData icon;
  final String title;
  final String message;
  final bool pulse;
  final Widget? action;

  @override
  State<_FeatureEmpty> createState() => _FeatureEmptyState();
}

class _FeatureEmptyState extends State<_FeatureEmpty> with SingleTickerProviderStateMixin {
  late final AnimationController _radar = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.pulse && !MediaQuery.of(context).disableAnimations && !_radar.isAnimating) _radar.repeat();
  }

  @override
  void dispose() {
    _radar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SkorxSpace.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkorxRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.pulse)
                  AnimatedBuilder(
                    animation: _radar,
                    builder: (_, _) => Container(
                      width: 26 + 26 * _radar.value,
                      height: 26 + 26 * _radar.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.cyan.withValues(alpha: (1 - _radar.value) * 0.6), width: 2),
                      ),
                    ),
                  ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: colors.surfaceInteractive, shape: BoxShape.circle),
                  child: Icon(widget.icon, color: colors.cyan, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(width: SkorxSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: SkorxSpace.xs),
                Text(widget.message, style: TextStyle(color: colors.textMuted, height: 1.35)),
                if (widget.action != null) ...[const SizedBox(height: SkorxSpace.sm), widget.action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
