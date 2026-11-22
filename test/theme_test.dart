import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/theme.dart';

/// WCAG contrast ratio between two colours: 1 (none) to 21 (black on white).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  const brand = Color(0xFF7E1109);
  const cream = Color(0xFFEEE9E3);

  for (final (name, theme) in [
    ('customerTheme', customerTheme),
    ('restaurantTheme', restaurantTheme),
  ]) {
    group(name, () {
      test('uses #7E1109 exactly as the primary colour', () {
        expect(theme().colorScheme.primary, brand);
      });

      test('puts white text on the primary colour', () {
        expect(theme().colorScheme.onPrimary, Colors.white);
      });

      test('text on the primary colour is at least 4.5:1 (WCAG AA)', () {
        final scheme = theme().colorScheme;
        expect(contrast(scheme.onPrimary, scheme.primary), greaterThan(4.5));
      });

      test('text on primaryContainer (e.g. the "Your orders" banner) is at '
          'least 4.5:1', () {
        final scheme = theme().colorScheme;
        expect(
          contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
          greaterThan(4.5),
        );
      });

      test('uses #EEE9E3 (cream) as the page background', () {
        expect(theme().colorScheme.surface, cream);
      });

      test('cards are white on the cream page', () {
        expect(theme().colorScheme.surfaceContainerLow, Colors.white);
      });

      test('text on the cream page is at least 4.5:1', () {
        final scheme = theme().colorScheme;
        expect(contrast(scheme.onSurface, scheme.surface), greaterThan(4.5));
        expect(
          contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThan(4.5),
        );
      });

      test('text on secondaryContainer (tonal buttons, picture placeholders) '
          'is at least 4.5:1', () {
        final scheme = theme().colorScheme;
        expect(
          contrast(scheme.onSecondaryContainer, scheme.secondaryContainer),
          greaterThan(4.5),
        );
      });

      testWidgets('a real Scaffold is cream and a real Card is white', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme(),
            home: const Scaffold(body: Card(child: Text('tile'))),
          ),
        );

        Material materialOf(Finder widget) => tester.widget<Material>(
          find.descendant(of: widget, matching: find.byType(Material)).first,
        );
        expect(materialOf(find.byType(Scaffold)).color, cream);
        expect(materialOf(find.byType(Card)).color, Colors.white);
      });

      test('is a Material 3 theme', () {
        expect(theme().useMaterial3, isTrue);
      });
    });
  }

  test('both apps share the same colour scheme', () {
    expect(customerTheme().colorScheme, restaurantTheme().colorScheme);
  });

  test('the contrast helper matches known values', () {
    expect(contrast(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrast(Colors.white, Colors.white), closeTo(1, 0.0001));
  });

  test('customer cards are rounded with a soft shadow', () {
    final card = customerTheme().cardTheme;
    final shape = card.shape as RoundedRectangleBorder;
    final radius = (shape.borderRadius as BorderRadius).topLeft.x;
    expect(radius, greaterThanOrEqualTo(16));
    expect(card.elevation, isNotNull);
    expect(card.color, Colors.white);
  });

  test('restaurant cards keep the default look', () {
    expect(restaurantTheme().cardTheme.shape, isNull);
    expect(restaurantTheme().cardTheme.elevation, isNull);
  });
}
