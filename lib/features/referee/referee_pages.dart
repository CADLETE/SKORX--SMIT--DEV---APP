import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import '../shell/workspace_shell.dart';

const refereeDestinations = [
  ShellDestination('Current', Icons.sports_rounded, Icons.sports_rounded),
  ShellDestination('Upcoming', Icons.event_outlined, Icons.event_rounded),
  ShellDestination('Completed', Icons.task_alt_outlined, Icons.task_alt_rounded),
  ShellDestination('Profile', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Answers one question: which match am I scoring?
class RefereeListPage extends StatelessWidget {
  const RefereeListPage.current({super.key})
      : _title = 'Current match',
        _empty = 'No match assigned right now',
        _message = 'When an organizer assigns you a match it opens here, ready to score.';

  const RefereeListPage.upcoming({super.key})
      : _title = 'Upcoming',
        _empty = 'Nothing coming up',
        _message = 'Matches assigned to you show here with court and time.';

  const RefereeListPage.completed({super.key})
      : _title = 'Completed',
        _empty = 'No matches refereed yet',
        _message = 'Results you submit are kept here.';

  final String _title;
  final String _empty;
  final String _message;

  @override
  Widget build(BuildContext context) => PageBody(
        children: [
          SectionHeader(_title),
          EmptyState(icon: Icons.sports_rounded, title: _empty, message: _message),
        ],
      );
}
