import 'package:flutter/material.dart';

/// The sporty display face (Barlow Condensed): scores, headlines and
/// broadcast-style labels. Body text stays in the platform font for
/// readability.
abstract final class SkorxType {
  static const family = 'BarlowCondensed';

  /// Big italic headline, e.g. "READY TO PLAY?".
  static TextStyle headline(double size, {Color? color, FontWeight weight = FontWeight.w900}) => TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        fontStyle: FontStyle.italic,
        height: 0.92,
        letterSpacing: -0.5,
        color: color,
      );

  /// Upright numerals for scores and stats; tabular so digits don't jump.
  static TextStyle score(double size, {Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );

  /// Small tracked caps label, e.g. "LIVE NOW".
  static TextStyle label({Color? color, double size = 13}) => TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: color,
      );
}
