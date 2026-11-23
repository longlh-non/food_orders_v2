import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/customer/api/payment_client.dart';
import 'package:food_orders/shared/localized_labels.dart';
import 'package:food_orders/customer/pages/cart_page.dart';
import 'package:food_orders/customer/pages/menu_page.dart';
import 'package:food_orders/customer/pages/payment_qr_page.dart';
import 'package:food_orders/customer/state/cart.dart';
import 'package:food_orders/customer/state/menu_state.dart';
import 'package:food_orders/customer/state/my_orders.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/api/order_repository.dart';
import 'package:food_orders/shared/l10n.dart';
import 'package:food_orders/shared/models/menu_item.dart';
import 'package:food_orders/shared/models/order.dart';
import 'package:food_orders/shared/widgets/language_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/l10n_app.dart';

/// Backend data: the same string must show whatever the UI language is.
const _menu = [
  {
    'id': 'xoi-thit',
    'name': 'Xôi thịt',
    'description': 'Xôi nếp, thịt kho',
    'price': 25000,
    'category': 'food',
    'allowToppings': false,
    'image': null,
    'available': true,
  },
  {
    'id': 'het',
    'name': 'Xôi hết',
    'description': '',
    'price': 20000,
    'category': 'snack',
    'allowToppings': false,
    'image': null,
    'available': false,
  },
];

http.Response _json(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<MenuState> _loadedMenu() async {
  final state = MenuState(
    OrderApiClient(
      client: MockClient(
        (r) async => _json(r.url.path.endsWith('/toppings') ? [] : _menu),
      ),
    ),
  );
  await state.load();
  return state;
}

PaymentClient _payment({bool enabled = true}) => PaymentClient(
  client: MockClient((r) async {
    if (r.url.path.endsWith('/payment-info')) {
      return _json(
        enabled
            ? {
                'transferEnabled': true,
                'bankName': 'ACB',
                'accountNumber': '123',
                'accountName': 'QUAN',
              }
            : {'transferEnabled': false},
      );
    }
    return http.Response('no', 500);
  }),
);

String _tlv(String tag, String value) =>
    '$tag${value.length.toString().padLeft(2, '0')}$value';

final _start = DateTime.utc(2026, 11, 19, 10);

Order _order(OrderStatus status, {DateTime? due, String id = 'o1234'}) => Order(
  id: id,
  customerName: 'An',
  items: [OrderItem(name: 'Xôi thịt', quantity: 1, price: 25000)],
  status: status,
  placedAt: DateTime(2026, 11, 19, 10),
  paymentMethod: PaymentMethod.bank_transfer,
  paymentDueAt: due ?? _start.add(const Duration(minutes: 5)),
);

PaymentClient _qrClient() => PaymentClient(
  client: MockClient((r) async {
    final merchant =
        _tlv('00', 'A000000727') +
        _tlv('01', _tlv('00', '970403') + _tlv('01', '123456789')) +
        _tlv('02', 'QRIBFTTA');
    return _json({
      'payload':
          _tlv('00', '01') +
          _tlv('38', merchant) +
          _tlv('54', '25000') +
          _tlv('62', _tlv('05', 'QR1') + _tlv('08', 'DH001234')),
      'amount': 25000,
      'reference': 'DH001234',
      'dueAt': _start.add(const Duration(minutes: 5)).toIso8601String(),
      'bankName': 'ACB',
      'accountNumber': '123456789',
      'accountName': 'QUAN XOI',
    });
  }),
);

/// Like the real apps: rebuilds in the language [LocaleController] holds, so
/// the picker really switches it.
Widget _liveApp(Widget home) => ListenableBuilder(
  listenable: LocaleController.instance,
  builder: (context, _) =>
      l10nApp(locale: LocaleController.instance.locale, home: home),
);

void main() {
  void reset() {
    Cart.instance.clear();
    MyOrders.instance.clearForTest();
    OrderRepository.instance
      ..setApiForTest(OrderApiClient())
      ..setOrdersForTest(const []);
    LocaleController.instance.setLocale(LocaleController.defaultLocale);
  }

  setUp(reset);
  tearDown(reset);

  group('menu page', () {
    final cases = {
      const Locale('vi'): ('Thực đơn', 'Thêm Xôi thịt', 'Đã thêm Xôi thịt'),
      const Locale('en'): ('Menu', 'Add Xôi thịt', 'Added Xôi thịt'),
      const Locale('zh'): ('菜单', '添加 Xôi thịt', '已添加 Xôi thịt'),
    };
    for (final MapEntry(key: locale, value: (title, tooltip, added))
        in cases.entries) {
      testWidgets('title, Add tooltip and SnackBar in $locale', (tester) async {
        final state = await _loadedMenu();
        await tester.pumpWidget(
          l10nApp(
            locale: locale,
            home: MenuPage(state: state),
          ),
        );
        expect(find.text(title), findsOneWidget);
        // The menu item name is backend data: the same in every language.
        expect(find.text('Xôi thịt'), findsOneWidget);
        expect(find.byTooltip(tooltip), findsOneWidget);
        await tester.tap(find.byTooltip(tooltip));
        await tester.pump();
        expect(find.text(added), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the sold-out pill and the tabs follow the language', (
      tester,
    ) async {
      final state = await _loadedMenu();
      await tester.pumpWidget(
        l10nApp(
          locale: const Locale('en'),
          home: MenuPage(state: state),
        ),
      );
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Drinks'), findsOneWidget);
      expect(find.text('Light bites'), findsOneWidget);
      await tester.tap(find.text('Light bites'));
      await tester.pumpAndSettle();
      expect(find.text('Sold out'), findsOneWidget);
      expect(find.text('Xôi hết'), findsOneWidget);
    });

    testWidgets('the language picker is in the app bar and switches the page', (
      tester,
    ) async {
      final state = await _loadedMenu();
      await tester.pumpWidget(_liveApp(MenuPage(state: state)));
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(LanguagePicker),
        ),
        findsOneWidget,
      );
      expect(find.text('Thực đơn'), findsOneWidget);

      await tester.tap(find.byType(LanguagePicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Thực đơn'), findsNothing);
      // Data and prices don't change with the language.
      expect(find.text('Xôi thịt'), findsOneWidget);
      expect(find.text('25.000 VNĐ'), findsOneWidget);
    });

    testWidgets('an order status change shows a SnackBar in the language', (
      tester,
    ) async {
      final state = await _loadedMenu();
      MyOrders.instance.track('o1234');
      OrderRepository.instance.setOrdersForTest([
        _order(OrderStatus.preparing, due: null),
      ]);
      await tester.pumpWidget(
        l10nApp(
          locale: const Locale('en'),
          home: MenuPage(state: state),
        ),
      );
      OrderRepository.instance.setOrdersForTest([
        _order(OrderStatus.ready, due: null),
      ]);
      await tester.pump();
      expect(find.text('Order #1234: Ready for pickup'), findsOneWidget);
    });
  });

  group('cart page', () {
    const item = MenuItem(
      id: 'xoi-thit',
      name: 'Xôi thịt',
      description: '',
      price: 25000,
    );

    testWidgets('empty cart and title in English and Chinese', (tester) async {
      for (final (locale, title, empty) in [
        (const Locale('en'), 'Your cart', 'Your cart is empty.'),
        (const Locale('zh'), '你的购物车', '购物车是空的。'),
      ]) {
        await tester.pumpWidget(
          l10nApp(
            locale: locale,
            home: CartPage(paymentClient: _payment()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget, reason: '$locale');
        expect(find.text(empty), findsOneWidget, reason: '$locale');
      }
    });

    testWidgets('the "enter your name" message follows the language', (
      tester,
    ) async {
      Cart.instance.add(item);
      for (final (locale, button, message) in [
        (const Locale('vi'), 'Đặt hàng', 'Vui lòng nhập tên của bạn'),
        (const Locale('en'), 'Place order', 'Please enter your name'),
      ]) {
        await tester.pumpWidget(
          l10nApp(
            locale: locale,
            home: CartPage(paymentClient: _payment()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(button));
        await tester.pump();
        expect(find.text(message), findsOneWidget, reason: '$locale');
        expect(Cart.instance.isEmpty, isFalse);
        // A fresh tree, so the first language's SnackBar is gone.
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('total, line price and payment choice follow the language', (
      tester,
    ) async {
      Cart.instance.add(item);
      await tester.pumpWidget(
        l10nApp(
          locale: const Locale('en'),
          home: CartPage(paymentClient: _payment(enabled: false)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total: 25.000 VNĐ'), findsOneWidget);
      expect(find.text('25.000 VNĐ / item'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Bank transfer'), findsOneWidget);
      expect(find.text('Bank transfer is not turned on'), findsOneWidget);
    });
  });

  group('payment page', () {
    Future<void> open(
      WidgetTester tester,
      Locale locale,
      Order order, {
      DateTime? now,
    }) async {
      OrderRepository.instance.setOrdersForTest([order]);
      await tester.pumpWidget(
        l10nApp(
          locale: locale,
          home: PaymentQrPage(
            orderId: order.id,
            paymentClient: _qrClient(),
            now: () => now ?? _start,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('QR page text in English and Chinese', (tester) async {
      for (final (locale, title, wait, left, amount) in [
        (
          const Locale('en'),
          'Bank transfer',
          'Please transfer within 5 minutes to keep your order.',
          'Time left 05:00',
          'Amount',
        ),
        (const Locale('zh'), '银行转账', '请在 5 分钟内转账以保留订单。', '剩余 05:00', '金额'),
      ]) {
        await open(tester, locale, _order(OrderStatus.awaiting_payment));
        expect(find.text(title), findsOneWidget, reason: '$locale');
        expect(find.text(wait), findsOneWidget, reason: '$locale');
        expect(find.text(left), findsOneWidget, reason: '$locale');
        expect(find.text(amount), findsOneWidget, reason: '$locale');
        // Prices and the bank's own data are not translated.
        expect(find.text('25.000 VNĐ'), findsOneWidget);
        expect(find.text('ACB'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('expired and paid views in English', (tester) async {
      await open(
        tester,
        const Locale('en'),
        _order(OrderStatus.cancelled),
        now: _start.add(const Duration(minutes: 6)),
      );
      expect(
        find.text(
          'The payment time for your order has run out. '
          'Would you like to pay in cash instead?',
        ),
        findsOneWidget,
      );
      expect(find.text('Switch to cash'), findsOneWidget);
      expect(find.text('Create a new QR code'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await open(tester, const Locale('en'), _order(OrderStatus.preparing));
      expect(find.text('Payment received. Thank you!'), findsOneWidget);
      expect(find.text('Back to menu'), findsOneWidget);
    });
  });

  test(
    'every status and payment method has a label in every language',
    () async {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);
        for (final s in OrderStatus.values) {
          expect(s.localized(l10n).trim(), isNotEmpty, reason: '$locale $s');
        }
        for (final m in PaymentMethod.values) {
          expect(m.localized(l10n).trim(), isNotEmpty, reason: '$locale $m');
        }
      }
    },
  );

  // The longest languages must still fit a 360 px phone (text x1.0 and the
  // larger x1.5). An overflow would throw and show up in takeException.
  for (final code in ['de', 'ru', 'lo']) {
    for (final scale in [1.0, 1.5]) {
      group('fits at 360 px in $code (text x$scale)', () {
        final locale = Locale(code);

        Future<void> pump(WidgetTester tester, Widget home) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            l10nApp(
              locale: locale,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: home,
            ),
          );
          await tester.pumpAndSettle();
        }

        testWidgets('menu page with a banner, sold-out tile and error', (
          tester,
        ) async {
          final state = await _loadedMenu();
          MyOrders.instance.track('o1234');
          OrderRepository.instance.setOrdersForTest([
            _order(OrderStatus.preparing, due: null),
          ]);
          await pump(tester, MenuPage(state: state));
          await tester.ensureVisible(find.byType(Tab).at(2));
          await tester.tap(find.byType(Tab).at(2));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final failing = MenuState(
            OrderApiClient(
              client: MockClient((_) async => http.Response('', 500)),
            ),
          );
          await failing.load();
          await pump(tester, MenuPage(state: failing));
          expect(tester.takeException(), isNull);
        });

        testWidgets('cart page, empty and filled', (tester) async {
          await pump(tester, CartPage(paymentClient: _payment(enabled: false)));
          expect(tester.takeException(), isNull);

          Cart.instance.add(
            const MenuItem(
              id: 'x',
              name: 'Xôi thịt',
              description: '',
              price: 25000,
            ),
          );
          await pump(tester, CartPage(paymentClient: _payment(enabled: false)));
          expect(tester.takeException(), isNull);
        });

        testWidgets('payment page: QR, expired and too-late views', (
          tester,
        ) async {
          OrderRepository.instance.setOrdersForTest([
            _order(OrderStatus.awaiting_payment),
          ]);
          await pump(
            tester,
            PaymentQrPage(
              orderId: 'o1234',
              paymentClient: _qrClient(),
              now: () => _start,
            ),
          );
          // The QR details are on screen, so they were part of the check.
          expect(find.text('ACB'), findsOneWidget);
          expect(tester.takeException(), isNull);

          for (final minutes in [6, 30]) {
            OrderRepository.instance.setOrdersForTest([
              _order(OrderStatus.cancelled),
            ]);
            await pump(
              tester,
              PaymentQrPage(
                orderId: 'o1234',
                paymentClient: _qrClient(),
                now: () => _start.add(Duration(minutes: minutes)),
              ),
            );
            expect(tester.takeException(), isNull, reason: '$minutes min');
          }
        });
      });
    }
  }
}
