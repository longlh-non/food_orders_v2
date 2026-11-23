import 'package:flutter/material.dart';

// Themes for both apps. They share one brand colour, `_brand` (#7E1109), so
// the customer and restaurant apps look like the same business. Both use
// Material 3.
//
// The two functions stay separate so either app can diverge later without
// touching the other.

/// The main brand colour, shown exactly on app bars and buttons.
const _brand = Color(0xFF7E1109);

/// The second brand colour: a warm cream (#EEE9E3) used as the page
/// background behind white cards. Only a background, never text: dark text
/// on it is about 14:1, while white text on it would be about 1.2:1.
const _cream = Color(0xFFEEE9E3);

/// A Material 3 palette generated from [_brand], with the exact brand colour
/// pinned as `primary`. A seed alone would give a nearby derived tone, not
/// #7E1109 itself. Text on it stays white: white on this dark red is about
/// 10.6:1 contrast, well above the 4.5:1 minimum (black would fail).
///
/// Pages use [_cream] (`surface`). Cards (`surfaceContainerLow`, the
/// Material 3 card colour) are pinned to white so they stand out cleanly on
/// it; the derived tone would look a dull pink-grey there. Text colours
/// (`onSurface` and friends) stay as Material derives them.
ColorScheme _brandScheme() => ColorScheme.fromSeed(seedColor: _brand).copyWith(
  primary: _brand,
  onPrimary: Colors.white,
  surface: _cream,
  surfaceContainerLow: Colors.white,
);

/// The customer app's cards are rounder, with a soft shadow, on the cream
/// page (decision TILE2). The restaurant app keeps Material's default cards.
ThemeData customerTheme() => ThemeData(
  colorScheme: _brandScheme(),
  useMaterial3: true,
  cardTheme: CardThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
);

/// Unlike [customerTheme], adds no custom `cardTheme` — see there for why.
ThemeData restaurantTheme() =>
    ThemeData(colorScheme: _brandScheme(), useMaterial3: true);
