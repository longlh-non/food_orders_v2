import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/l10n.dart';

/// A [MaterialApp] with the app's translations switched on, for widget tests
/// of pages that read `AppLocalizations`. Vietnamese unless [locale] says
/// otherwise; [builder] is for tests that change the text scale.
MaterialApp l10nApp({
  required Widget home,
  Locale locale = const Locale('vi'),
  TransitionBuilder? builder,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: builder,
  home: home,
);

/// Taps the app bar's back button. `WidgetTester.pageBack` looks for the
/// English tooltip "Back", which Material translates (Vietnamese: "Quay lại"),
/// so it can't be used under [l10nApp].
Future<void> goBack(WidgetTester tester) => tester.tap(find.byType(BackButton));
