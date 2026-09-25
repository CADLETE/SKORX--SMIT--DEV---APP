import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import '../shell/workspace_shell.dart';

const playerDestinations = [
  ShellDestination('Home', Icons.home_outlined, Icons.home_rounded),
  ShellDestination('My Paddle', Icons.sports_tennis_outlined, Icons.sports_tennis_rounded),
  ShellDestination('Tournaments', Icons.emoji_events_outlined, Icons.emoji_events_rounded),
  ShellDestination('Matches', Icons.scoreboard_outlined, Icons.scoreboard_rounded),
  ShellDestination('Profile', Icons.person_outline_rounded, Icons.person_rounded),
];

class MyPaddlePage extends StatelessWidget {
  const MyPaddlePage({super.key});

  @override
  Widget build(BuildContext context) => const PageBody(
        children: [
          SectionHeader('Performance'),
          EmptyState(
            icon: Icons.insights_rounded,
            title: 'Your stats start with your first match',
            message: 'Win rate, form and rival records per sport show here.',
          ),
          SectionHeader('Achievements'),
          EmptyState(
            icon: Icons.military_tech_rounded,
            title: 'No achievements yet',
            message: 'First Victory, Hot Streak and more unlock as you play.',
          ),
        ],
      );
}

class PlayerTournamentsPage extends StatelessWidget {
  const PlayerTournamentsPage({super.key});

  @override
  Widget build(BuildContext context) => const PageBody(
        children: [
          SectionHeader('My tournaments'),
          EmptyState(
            icon: Icons.emoji_events_rounded,
            title: 'You have not entered a tournament',
            message: 'Tournaments you register for show here with your divisions and next match.',
          ),
        ],
      );
}

class PlayerMatchesPage extends StatelessWidget {
  const PlayerMatchesPage({super.key});

  @override
  Widget build(BuildContext context) => const PageBody(
        children: [
          SectionHeader('Match history'),
          EmptyState(
            icon: Icons.scoreboard_rounded,
            title: 'No matches yet',
            message: 'Every casual and tournament match you play is kept here.',
          ),
        ],
      );
}
