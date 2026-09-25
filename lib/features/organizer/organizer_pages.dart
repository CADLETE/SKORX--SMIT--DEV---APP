import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../shared/widgets.dart';
import '../shell/workspace_shell.dart';
import '../workspace/workspace.dart';
import '../workspace/workspace_controller.dart';

const organizerDestinations = [
  ShellDestination('Dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  ShellDestination('Tournaments', Icons.emoji_events_outlined, Icons.emoji_events_rounded),
  ShellDestination('Matches', Icons.scoreboard_outlined, Icons.scoreboard_rounded),
  ShellDestination('Schedule', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
  ShellDestination('More', Icons.grid_view_outlined, Icons.grid_view_rounded),
];

/// The organizer workspace open for [organizationId], or null when the user
/// is not a member (the router already sends them home in that case).
OrganizerWorkspace? organizerWorkspace(WidgetRef ref, String organizationId) => ref
    .watch(workspaceControllerProvider)
    .available
    .whereType<OrganizerWorkspace>()
    .where((w) => w.organizationId == organizationId)
    .firstOrNull;

/// Answers: what needs my attention, what is live, what is next.
class OrganizerDashboardPage extends StatelessWidget {
  const OrganizerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        Text('Command center', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: SkorxSpace.lg),
        const Row(
          children: [
            Expanded(child: _Kpi(label: 'Live', value: '-')),
            SizedBox(width: SkorxSpace.md),
            Expanded(child: _Kpi(label: 'Upcoming', value: '-')),
          ],
        ),
        const SizedBox(height: SkorxSpace.md),
        const Row(
          children: [
            Expanded(child: _Kpi(label: 'Check-in', value: '-')),
            SizedBox(width: SkorxSpace.md),
            Expanded(child: _Kpi(label: 'Courts active', value: '-')),
          ],
        ),
        const SectionHeader('Needs attention'),
        const EmptyState(
          icon: Icons.task_alt_rounded,
          title: 'All clear',
          message: 'Late check-ins, unassigned referees and delayed matches show here.',
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.skorx.colors;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(SkorxSpace.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(SkorxRadius.lg),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: colors.textMuted)),
            const SizedBox(height: SkorxSpace.xs),
            Text(
              value,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}

class OrganizerTournamentsPage extends StatelessWidget {
  const OrganizerTournamentsPage({super.key});

  @override
  Widget build(BuildContext context) => const PageBody(
        children: [
          SectionHeader('Tournaments'),
          EmptyState(
            icon: Icons.emoji_events_rounded,
            title: 'No tournaments yet',
            message: 'Tournaments created here or on the web TMS show here.',
          ),
        ],
      );
}

class OrganizerMatchesPage extends StatelessWidget {
  const OrganizerMatchesPage({super.key});

  @override
  Widget build(BuildContext context) => const PageBody(
        children: [
          SectionHeader('Matches'),
          EmptyState(
            icon: Icons.scoreboard_rounded,
            title: 'No matches yet',
            message: 'Live, upcoming and completed matches for the selected tournament show here.',
          ),
        ],
      );
}

class OrganizerSchedulePage extends StatelessWidget {
  const OrganizerSchedulePage({super.key});

  @override
  Widget build(BuildContext context) => const PageBody(
        children: [
          SectionHeader('Schedule'),
          EmptyState(
            icon: Icons.calendar_month_rounded,
            title: 'Nothing scheduled',
            message: 'Pick a day, then a court, to see its timeline.',
          ),
        ],
      );
}

/// A tool in "More". [capability] hides it from roles that cannot use it.
class OrganizerModule {
  const OrganizerModule(this.label, this.icon, [this.capability]);

  final String label;
  final IconData icon;
  final String? capability;
}

const organizerModules = [
  OrganizerModule('Draws', Icons.account_tree_rounded, 'editTournament'),
  OrganizerModule('Check-in', Icons.how_to_reg_rounded, 'manageCheckIn'),
  OrganizerModule('Players', Icons.groups_rounded, 'managePlayers'),
  OrganizerModule('Teams', Icons.diversity_3_rounded, 'managePlayers'),
  OrganizerModule('Courts', Icons.grid_on_rounded, 'manageSchedule'),
  OrganizerModule('Referees', Icons.sports_rounded, 'assignReferee'),
  OrganizerModule('Payments', Icons.payments_rounded, 'managePayments'),
  OrganizerModule('Streaming', Icons.videocam_rounded, 'manageStreaming'),
  OrganizerModule('Announcements', Icons.campaign_rounded, 'editTournament'),
  OrganizerModule('Add-ons', Icons.extension_rounded, 'managePayments'),
  OrganizerModule('Analytics', Icons.query_stats_rounded, 'viewAnalytics'),
  OrganizerModule('Settings', Icons.settings_rounded, 'manageSettings'),
];

class OrganizerMorePage extends ConsumerWidget {
  const OrganizerMorePage({super.key, required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = organizerWorkspace(ref, organizationId);
    final modules = organizerModules.where((m) => m.capability == null || (workspace?.can(m.capability!) ?? false));
    final colors = context.skorx.colors;
    return PageBody(
      children: [
        const SectionHeader('Tools'),
        if (modules.isEmpty)
          const EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'No tools for your role',
            message: 'Ask an owner of this organization if you need more access.',
          ),
        for (final module in modules)
          Padding(
            padding: const EdgeInsets.only(bottom: SkorxSpace.sm),
            child: ListTile(
              minTileHeight: 56,
              tileColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SkorxRadius.md),
                side: BorderSide(color: colors.border),
              ),
              leading: Icon(module.icon, color: context.skorx.highlight),
              title: Text(module.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: Icon(Icons.chevron_right_rounded, color: colors.textMuted),
              // Each module arrives with the organizer step (build step 6).
              onTap: null,
            ),
          ),
      ],
    );
  }
}
