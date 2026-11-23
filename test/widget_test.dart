import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/customer/main.dart';
import 'package:food_orders/restaurant/main.dart';
import 'package:food_orders/shared/l10n.dart';

void main() {
  // Builds the app without any network. The menu body stays on its spinner
  // here (nothing calls MenuState.instance.load()); the page's states and the
  // grid are tested in menu_page_test.dart with an injected MenuState.
  testWidgets('Customer app renders menu page in Vietnamese and English', (
    tester,
  ) async {
    addTearDown(
      () => LocaleController.instance.setLocale(LocaleController.defaultLocale),
    );
    await tester.pumpWidget(const CustomerApp());
    expect(find.text('Thực đơn'), findsOneWidget);

    LocaleController.instance.setLocale(const Locale('en'));
    await tester.pump();
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Thực đơn'), findsNothing);
    // The app title (browser tab) is translated too.
    expect(tester.widget<Title>(find.byType(Title)).title, 'Food Orders');
  });

  testWidgets('Restaurant app renders orders page in Vietnamese and English', (
    tester,
  ) async {
    addTearDown(
      () => LocaleController.instance.setLocale(LocaleController.defaultLocale),
    );
    await tester.pumpWidget(const RestaurantApp());
    expect(find.text('Danh sách đơn hàng'), findsOneWidget);

    LocaleController.instance.setLocale(const Locale('en'));
    await tester.pump();
    expect(find.text('Incoming Orders'), findsOneWidget);
    expect(find.text('Danh sách đơn hàng'), findsNothing);
    expect(
      tester.widget<Title>(find.byType(Title)).title,
      'Food Orders — Restaurant',
    );
  });
}
