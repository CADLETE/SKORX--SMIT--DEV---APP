import 'package:flutter/material.dart';

import 'tokens.dart';

/// Which workspace the theme is for. Player is personal and energetic
/// (cyan/blue); organizer and referee are operational (lime/blue).
enum WorkspaceAccent { player, operations }

/// Builds the app theme. The two workspaces share every token except the
/// accent, so they read as one product with different emphasis.
ThemeData buildSkorxTheme({required Brightness brightness, required WorkspaceAccent accent}) {
  final colors = brightness == Brightness.dark ? SkorxColors.dark : SkorxColors.light;
  final isOps = accent == WorkspaceAccent.operations;
  final primary = colors.blue;
  // Accent used for the active navigation indicator and highlights.
  final highlight = isOps ? colors.lime : colors.cyan;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: Colors.white,
    secondary: highlight,
    onSecondary: colors.navy,
    tertiary: colors.limeText,
    onTertiary: colors.navy,
    error: colors.live,
    onError: Colors.white,
    surface: colors.surface,
    onSurface: colors.text,
    onSurfaceVariant: colors.textMuted,
    surfaceContainerLowest: colors.background,
    surfaceContainerLow: colors.surfaceMuted,
    surfaceContainer: colors.surface,
    surfaceContainerHigh: colors.surfaceElevated,
    surfaceContainerHighest: colors.surfaceInteractive,
    outline: colors.border,
    outlineVariant: colors.border,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    extensions: [SkorxThemeExtension(colors: colors, highlight: highlight, accent: accent)],
  );

  final text = base.textTheme.apply(bodyColor: colors.text, displayColor: colors.text);

  return base.copyWith(
    textTheme: text.copyWith(
      displayLarge: text.displayLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.5),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      foregroundColor: colors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SkorxRadius.lg),
        side: BorderSide(color: colors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: highlight.withValues(alpha: 0.18),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? colors.text : colors.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? highlight : colors.textMuted),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SkorxRadius.md)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: colors.border),
        foregroundColor: colors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SkorxRadius.md)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: SkorxSpace.lg, vertical: SkorxSpace.lg),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SkorxRadius.md),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SkorxRadius.md),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SkorxRadius.md),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SkorxRadius.xl)),
      ),
    ),
  );
}

/// Tokens that Material's ColorScheme has no slot for.
class SkorxThemeExtension extends ThemeExtension<SkorxThemeExtension> {
  const SkorxThemeExtension({required this.colors, required this.highlight, required this.accent});

  final SkorxColors colors;
  final Color highlight;
  final WorkspaceAccent accent;

  @override
  SkorxThemeExtension copyWith({SkorxColors? colors, Color? highlight, WorkspaceAccent? accent}) =>
      SkorxThemeExtension(
        colors: colors ?? this.colors,
        highlight: highlight ?? this.highlight,
        accent: accent ?? this.accent,
      );

  @override
  SkorxThemeExtension lerp(SkorxThemeExtension? other, double t) {
    if (other == null) return this;
    return SkorxThemeExtension(
      colors: t < 0.5 ? colors : other.colors,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      accent: t < 0.5 ? accent : other.accent,
    );
  }
}

extension SkorxThemeContext on BuildContext {
  SkorxThemeExtension get skorx => Theme.of(this).extension<SkorxThemeExtension>()!;
}
