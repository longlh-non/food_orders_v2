import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/locale_controller.dart';
import 'package:food_orders/shared/theme.dart';
import 'package:food_orders/shared/widgets/language_picker.dart';

const _names = {
  'vi': 'Tiếng Việt',
  'en': 'English',
  'de': 'Deutsch',
  'es': 'Español',
  'fr': 'Français',
  'ru': 'Русский',
  'lo': 'ລາວ',
  'ja': '日本語',
  'zh': '中文',
  'ko': '한국어',
};

Widget _app({ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(appBar: AppBar(actions: const [LanguagePicker()])),
);

/// The names of the entries that show a check mark.
List<String> _checked(WidgetTester tester) {
  final result = <String>[];
  for (final item in tester.widgetList<PopupMenuItem<Locale>>(
    find.byType(PopupMenuItem<Locale>),
  )) {
    final hasCheck = find
        .descendant(of: find.byWidget(item), matching: find.byIcon(Icons.check))
        .evaluate()
        .isNotEmpty;
    if (hasCheck) result.add(_names[item.value!.languageCode]!);
  }
  return result;
}

void main() {
  setUp(
    () => LocaleController.instance.setLocale(LocaleController.defaultLocale),
  );
  tearDown(
    () => LocaleController.instance.setLocale(LocaleController.defaultLocale),
  );

  testWidgets('lists all 10 native names, only the current one checked', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byType(LanguagePicker));
    await tester.pumpAndSettle();

    for (final name in _names.values) {
      expect(find.text(name), findsOneWidget);
    }
    expect(
      tester
          .widgetList<PopupMenuItem<Locale>>(find.byType(PopupMenuItem<Locale>))
          .map((i) => i.value),
      LocaleController.supported,
    );
    expect(_checked(tester), ['Tiếng Việt']);
  });

  testWidgets('tapping an entry sets the locale, closes, and moves the mark', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.byType(LanguagePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();

    expect(LocaleController.instance.locale, const Locale('fr'));
    expect(find.text('Français'), findsNothing); // menu closed

    await tester.tap(find.byType(LanguagePicker));
    await tester.pumpAndSettle();
    expect(_checked(tester), ['Français']);
  });

  testWidgets('an outside change to the controller is reflected', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    LocaleController.instance.setLocale(const Locale('ja'));
    await tester.pump();
    await tester.tap(find.byType(LanguagePicker));
    await tester.pumpAndSettle();
    expect(_checked(tester), ['日本語']);
  });

  testWidgets('fits at 360px wide with text scale 2.0', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(2.0),
        ),
        child: _app(),
      ),
    );
    await tester.tap(find.byType(LanguagePicker));
    await tester.pumpAndSettle();
    expect(find.text('Русский'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'customerTheme': customerTheme,
    'restaurantTheme': restaurantTheme,
  }.entries) {
    testWidgets('works under ${entry.key}', (tester) async {
      await tester.pumpWidget(_app(theme: entry.value()));
      await tester.tap(find.byType(LanguagePicker));
      await tester.pumpAndSettle();
      expect(find.text('한국어'), findsOneWidget);
      await tester.tap(find.text('한국어'));
      await tester.pumpAndSettle();
      expect(LocaleController.instance.locale, const Locale('ko'));
      expect(tester.takeException(), isNull);
    });
  }
}
