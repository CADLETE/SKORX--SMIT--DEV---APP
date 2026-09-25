import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../shared/widgets.dart';
import '../../../sports/core/match_rules.dart';
import '../../../sports/core/score_state.dart';
import '../../../sports/core/sport_definition.dart';
import '../../../sports/sport_registry.dart';
import '../../auth/auth_controller.dart';
import '../scoring_controller.dart';

/// Sports a player can start a match in. Mirrors the API's `playable` flag
/// (only pickleball today); becomes `GET /sports` once the sport list syncs.
final playableSportsProvider = Provider<List<SportDefinition>>((ref) => [pickleball]);

/// A casual match in a few taps (spec sections 12-13): type, players, who
/// serves, start. Rules have sensible defaults and live under "Customize".
class CreateMatchScreen extends ConsumerStatefulWidget {
  const CreateMatchScreen({super.key, this.initialCategoryId});

  /// Match type chosen from a Home shortcut ("singles", "mixed_doubles"...).
  final String? initialCategoryId;

  @override
  ConsumerState<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends ConsumerState<CreateMatchScreen> {
  late SportDefinition _sport;
  late MatchCategory _category;
  late MatchRules _rules;
  Side _firstServer = Side.a;
  bool _starting = false;

  // Side A slot 1 is the signed-in player; the rest are typed names.
  late final TextEditingController _me;
  final _partner = TextEditingController();
  final _opponent1 = TextEditingController();
  final _opponent2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sport = ref.read(playableSportsProvider).first;
    _category = _sport.category(widget.initialCategoryId ?? 'doubles') ??
        _sport.category('doubles') ??
        _sport.categories.first;
    _rules = _sport.defaultRules;
    _me = TextEditingController(text: ref.read(currentUserProvider)?.name ?? '');
  }

  @override
  void dispose() {
    for (final c in [_me, _partner, _opponent1, _opponent2]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _doubles => _category.playersPerSide == 2;

  List<String> get _sideA => [_me.text.trim(), if (_doubles) _partner.text.trim()];
  List<String> get _sideB => [_opponent1.text.trim(), if (_doubles) _opponent2.text.trim()];

  bool get _ready => [..._sideA, ..._sideB].every((name) => name.isNotEmpty);

  void _selectSport(SportDefinition sport) {
    setState(() {
      _sport = sport;
      _category = sport.category(_category.id) ?? sport.categories.first;
      _rules = sport.defaultRules;
    });
  }

  Future<void> _start() async {
    if (_starting || !_ready) return;
    setState(() => _starting = true);
    await ref.read(scoringControllerProvider.notifier).start(NewMatch(
          sportId: _sport.id,
          categoryId: _category.id,
          sideA: _sideA,
          sideB: _sideB,
          rules: _rules,
          firstServer: _firstServer,
        ));
    if (mounted) context.go('/player/match');
  }

  @override
  Widget build(BuildContext context) {
    final sports = ref.watch(playableSportsProvider);
    final colors = context.skorx.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/player/home'),
        ),
        title: const Text('New match'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(SkorxSpace.lg, 0, SkorxSpace.lg, SkorxSpace.xxl),
          children: [
            if (sports.length > 1) ...[
              const SectionHeader('Sport'),
              _ChoiceWrap<SportDefinition>(
                options: sports,
                selected: _sport,
                label: (s) => s.name,
                onSelected: _selectSport,
              ),
            ],
            const SectionHeader('Match type'),
            _ChoiceWrap<MatchCategory>(
              options: _sport.categories,
              selected: _category,
              label: (c) => c.label,
              onSelected: (c) => setState(() => _category = c),
            ),
            const SectionHeader('Players'),
            _SideCard(
              title: 'Your side',
              fields: [
                _NameField(controller: _me, label: 'You', fieldKey: const Key('playerA1'), onChanged: _refresh),
                if (_doubles)
                  _NameField(controller: _partner, label: 'Partner', fieldKey: const Key('playerA2'), onChanged: _refresh),
              ],
            ),
            const SizedBox(height: SkorxSpace.md),
            _SideCard(
              title: 'Opponents',
              fields: [
                _NameField(
                  controller: _opponent1,
                  label: _doubles ? 'Opponent 1' : 'Opponent',
                  fieldKey: const Key('playerB1'),
                  onChanged: _refresh,
                ),
                if (_doubles)
                  _NameField(controller: _opponent2, label: 'Opponent 2', fieldKey: const Key('playerB2'), onChanged: _refresh),
              ],
            ),
            const SectionHeader('Who serves first'),
            Row(
              children: [
                Expanded(
                  child: _ServerChoice(
                    label: 'Your side',
                    selected: _firstServer == Side.a,
                    onTap: () => setState(() => _firstServer = Side.a),
                  ),
                ),
                const SizedBox(width: SkorxSpace.md),
                Expanded(
                  child: _ServerChoice(
                    label: 'Opponents',
                    selected: _firstServer == Side.b,
                    onTap: () => setState(() => _firstServer = Side.b),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SkorxSpace.lg),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const Key('customize'),
                tilePadding: EdgeInsets.zero,
                title: const Text('Customize', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(_rules.describe(), style: TextStyle(color: colors.textMuted)),
                childrenPadding: const EdgeInsets.only(bottom: SkorxSpace.md),
                children: [_RulesEditor(sport: _sport, rules: _rules, onChanged: (r) => setState(() => _rules = r))],
              ),
            ),
            const SizedBox(height: SkorxSpace.lg),
            FilledButton(
              key: const Key('startMatch'),
              onPressed: _ready && !_starting ? _start : null,
              child: const Text('Start match'),
            ),
            if (!_ready) ...[
              const SizedBox(height: SkorxSpace.sm),
              Text(
                'Add a name for every player to start.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _refresh(String _) => setState(() {});
}

class _ChoiceWrap<T> extends StatelessWidget {
  const _ChoiceWrap({required this.options, required this.selected, required this.label, required this.onSelected});

  final List<T> options;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: SkorxSpace.sm,
        runSpacing: SkorxSpace.sm,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(label(option)),
              selected: option == selected,
              onSelected: (_) => onSelected(option),
            ),
        ],
      );
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.title, required this.fields});

  final String title;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    return Container(
      padding: const EdgeInsets.all(SkorxSpace.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkorxRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          for (final field in fields) ...[const SizedBox(height: SkorxSpace.md), field],
        ],
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.label, required this.fieldKey, required this.onChanged});

  final TextEditingController controller;
  final String label;
  final Key fieldKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        key: fieldKey,
        controller: controller,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      );
}

class _ServerChoice extends StatelessWidget {
  const _ServerChoice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(SkorxRadius.md),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.blue.withValues(alpha: 0.16) : colors.surface,
            borderRadius: BorderRadius.circular(SkorxRadius.md),
            border: Border.all(color: selected ? colors.blue : colors.border, width: selected ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[Icon(Icons.sports_tennis_rounded, size: 18, color: colors.blue), const SizedBox(width: 6)],
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The old app's match settings: games, scoring, play to, win by. Only
/// options the sport supports are offered.
class _RulesEditor extends StatelessWidget {
  const _RulesEditor({required this.sport, required this.rules, required this.onChanged});

  final SportDefinition sport;
  final MatchRules rules;
  final ValueChanged<MatchRules> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(
          context,
          'Games',
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (final n in sport.bestOfOptions) ButtonSegment(value: n, label: Text(n == 1 ? '1 game' : 'Best of $n')),
            ],
            selected: {rules.bestOf},
            onSelectionChanged: (v) => onChanged(rules.copyWith(bestOf: v.first)),
          ),
        ),
        if (sport.scoringSystems.length > 1)
          _row(
            context,
            'Scoring',
            SegmentedButton<ScoringSystem>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ScoringSystem.sideOut, label: Text('Side out')),
                ButtonSegment(value: ScoringSystem.rally, label: Text('Rally')),
              ],
              selected: {rules.scoring},
              onSelectionChanged: (v) => onChanged(rules.copyWith(scoring: v.first)),
            ),
          ),
        _row(
          context,
          'Play to',
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [for (final n in sport.pointTargets) ButtonSegment(value: n, label: Text('$n'))],
            selected: {rules.pointsToWin},
            emptySelectionAllowed: true,
            onSelectionChanged: (v) => v.isEmpty ? null : onChanged(rules.copyWith(pointsToWin: v.first)),
          ),
        ),
        _row(
          context,
          'Win by',
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('1 point')),
              ButtonSegment(value: true, label: Text('2 points')),
            ],
            selected: {rules.winByTwo},
            onSelectionChanged: (v) => onChanged(rules.copyWith(winByTwo: v.first)),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, Widget control) => Padding(
        padding: const EdgeInsets.only(bottom: SkorxSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: context.skorx.colors.textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: SkorxSpace.xs),
            SizedBox(width: double.infinity, child: control),
          ],
        ),
      );
}
