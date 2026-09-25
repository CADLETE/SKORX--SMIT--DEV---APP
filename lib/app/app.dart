import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/workspace/workspace_controller.dart';
import 'routing/router.dart';
import 'theme/app_theme.dart';

class SkorxApp extends ConsumerWidget {
  const SkorxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // The accent follows the open workspace: cyan for Player, lime for
    // Organizer and Referee.
    final accent = ref.watch(workspaceControllerProvider.select((s) => s.current.accent));

    return MaterialApp.router(
      title: 'SkorX',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: buildSkorxTheme(brightness: Brightness.light, accent: accent),
      darkTheme: buildSkorxTheme(brightness: Brightness.dark, accent: accent),
      // Dark is the SkorX hero look; a light/dark setting comes with Settings.
      themeMode: ThemeMode.dark,
    );
  }
}
