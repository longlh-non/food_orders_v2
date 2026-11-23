import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/l10n.dart';

void main() {
  test('AppLocalizations supports exactly the controller locales', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      {for (final l in LocaleController.supported) l.languageCode},
    );
  });

  for (final locale in LocaleController.supported) {
    testWidgets('renders a known key in ${locale.languageCode}', (
      tester,
    ) async {
      final arb = jsonDecode(
        File('lib/shared/l10n/app_${locale.languageCode}.arb')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) =>
                Text(AppLocalizations.of(context)!.statusAwaitingPayment),
          ),
        ),
      );
      expect(find.text(arb['statusAwaitingPayment'] as String), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a placeholder message fills in its argument', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(l10n.orderNewFrom('Alice'), 'New order from Alice');
    expect(l10n.tooManyTriesWait(1), contains('1 second.'));
    expect(l10n.tooManyTriesWait(5), contains('5 seconds.'));
  });

  testWidgets('Lao has Material localizations, so widgets build', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('lo'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) =>
              Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ),
    );
    expect(find.text('ຕົກລົງ'), findsOneWidget);
  });
}
