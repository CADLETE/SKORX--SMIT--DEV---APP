import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import 'workspace.dart';
import 'workspace_controller.dart';

IconData workspaceIcon(Workspace workspace) => switch (workspace) {
      PlayerWorkspace() => Icons.sports_tennis_rounded,
      OrganizerWorkspace() => Icons.dashboard_customize_rounded,
      RefereeWorkspace() => Icons.sports_rounded,
    };

/// The current workspace, top left of every shell. Tapping it opens the
/// switcher; it never takes a slot in the bottom navigation.
class WorkspaceChip extends ConsumerWidget {
  const WorkspaceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final current = state.current;
    final colors = context.skorx.colors;
    final canSwitch = state.available.length > 1;

    return Semantics(
      button: canSwitch,
      label: canSwitch ? 'Workspace: ${current.title}. Switch workspace' : 'Workspace: ${current.title}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(SkorxRadius.xl),
        onTap: canSwitch ? () => showWorkspaceSwitcher(context) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(SkorxSpace.sm, SkorxSpace.xs, SkorxSpace.md, SkorxSpace.xs),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(SkorxRadius.xl),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: context.skorx.highlight.withValues(alpha: 0.18),
                child: Icon(workspaceIcon(current), size: 16, color: context.skorx.highlight),
              ),
              const SizedBox(width: SkorxSpace.sm),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    if (current is! PlayerWorkspace)
                      Text(
                        current.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                  ],
                ),
              ),
              if (canSwitch) ...[
                const SizedBox(width: SkorxSpace.xs),
                Icon(Icons.unfold_more_rounded, size: 18, color: colors.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showWorkspaceSwitcher(BuildContext context) async {
  final target = await showModalBottomSheet<Workspace>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _WorkspaceSheet(),
  );
  if (target == null || !context.mounted) return;
  await switchWorkspace(context, target);
}

/// A short, calm transition that says where the user is going, then opens
/// that workspace where they left it. It is the same account, so there is no
/// loading or sign-in step.
Future<void> switchWorkspace(BuildContext context, Workspace target) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final state = container.read(workspaceControllerProvider);
  if (target.key == state.current.key) return;
  final destination = state.entryLocation(target);
  final router = GoRouter.of(context);
  final reduceMotion = MediaQuery.of(context).disableAnimations;

  if (!reduceMotion) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Switching workspace',
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => _SwitchingOverlay(target: target),
      transitionBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    );
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
  router.go(destination);
}

class _SwitchingOverlay extends StatelessWidget {
  const _SwitchingOverlay({required this.target});

  final Workspace target;

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    final kind = switch (target) {
      PlayerWorkspace() => 'Player workspace',
      OrganizerWorkspace() => 'Organizer workspace',
      RefereeWorkspace() => 'Referee workspace',
    };
    return Material(
      color: colors.background.withValues(alpha: 0.96),
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(workspaceIcon(target), size: 40, color: colors.blue),
              const SizedBox(height: SkorxSpace.lg),
              Text('Switching to', style: TextStyle(color: colors.textMuted)),
              const SizedBox(height: SkorxSpace.xs),
              Text(target.title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: SkorxSpace.xs),
              Text(kind, style: TextStyle(color: colors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceSheet extends ConsumerWidget {
  const _WorkspaceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final organizations = state.available.whereType<OrganizerWorkspace>().toList();
    final referee = state.available.whereType<RefereeWorkspace>().firstOrNull;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(SkorxSpace.lg, 0, SkorxSpace.lg, SkorxSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Switch workspace', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: SkorxSpace.md),
            _WorkspaceTile(workspace: const PlayerWorkspace(), selected: state.current is PlayerWorkspace),
            if (organizations.isNotEmpty) ...[
              const _SheetLabel('Organizations'),
              for (final org in organizations) _WorkspaceTile(workspace: org, selected: state.current.key == org.key),
            ],
            if (referee != null) ...[
              const _SheetLabel('Referee'),
              _WorkspaceTile(workspace: referee, selected: state.current is RefereeWorkspace),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: SkorxSpace.lg, bottom: SkorxSpace.sm),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: context.skorx.colors.textMuted,
          ),
        ),
      );
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({required this.workspace, required this.selected});

  final Workspace workspace;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: SkorxSpace.sm),
      child: ListTile(
        selected: selected,
        minTileHeight: 60,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SkorxRadius.md),
          side: BorderSide(color: selected ? colors.blue : colors.border),
        ),
        tileColor: colors.surfaceMuted,
        selectedTileColor: colors.surfaceInteractive,
        leading: Icon(workspaceIcon(workspace), color: selected ? colors.blue : colors.textMuted),
        title: Text(workspace.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(workspace.subtitle),
        trailing: selected ? Icon(Icons.check_rounded, color: colors.blue) : null,
        onTap: () => Navigator.of(context).pop(workspace),
      ),
    );
  }
}
