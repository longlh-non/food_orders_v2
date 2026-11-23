import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_app.dart';

import 'package:food_orders/customer/pages/menu_page.dart';
import 'package:food_orders/customer/pages/payment_qr_page.dart';
import 'package:food_orders/customer/state/cart.dart';
import 'package:food_orders/customer/state/menu_state.dart';
import 'package:food_orders/customer/state/my_orders.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/api/order_repository.dart';
import 'package:food_orders/shared/models/order.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

List<Map<String, Object>> menuJson({double burgerPrice = 25000}) => [
  {
    'id': 'burger',
    'name': 'Classic Burger',
    'description': 'Beef patty, lettuce, tomato, house sauce',
    'price': burgerPrice,
  },
  {
    'id': 'pizza',
    'name': 'Margherita Pizza',
    'description': 'Tomato, mozzarella, fresh basil',
    'price': 30000.0,
  },
  {
    'id': 'salad',
    'name': 'Caesar Salad',
    'description': 'Romaine, parmesan, croutons, caesar dressing',
    'price': 10000.0,
  },
  {
    'id': 'fries',
    'name': 'Fries',
    'description': 'Hand-cut, sea salt',
    'price': 15000.0,
  },
  {'id': 'soda', 'name': 'Soda', 'description': '330ml can', 'price': 4000.0},
];

/// A MenuState whose backend answers with whatever [respond] returns.
/// [respond] answers `/api/menu`; `/api/toppings` answers [toppings].
MenuState stateWith(
  FutureOr<http.Response> Function() respond, {
  List<Object> toppings = const [],
}) {
  return MenuState(
    OrderApiClient(
      client: MockClient(
        (request) async =>
            request.url.path.endsWith('/toppings') ? ok(toppings) : respond(),
      ),
    ),
  );
}

// UTF-8 with an explicit charset, like the real backend: a plain
// `http.Response(String)` would encode the body as Latin-1, which can't hold
// Vietnamese letters.
http.Response ok(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> pumpPage(
  WidgetTester tester,
  MenuState state, {
  double width = 800,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    l10nApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: MenuPage(state: state),
    ),
  );
}

/// Top edge of each tile's Add button, in grid order.
List<double> addButtonRows(WidgetTester tester) => tester
    .widgetList(find.byType(AddItemButton))
    .map((w) => tester.getTopLeft(find.byWidget(w)).dy)
    .toList();

void main() {
  void resetShared() {
    Cart.instance.clear();
    MyOrders.instance.clearForTest();
    OrderRepository.instance.setOrdersForTest(const []);
  }

  setUp(resetShared);
  tearDown(resetShared);

  testWidgets('shows a spinner before the menu has loaded', (tester) async {
    final gate = Completer<http.Response>();
    final state = stateWith(() => gate.future);

    await pumpPage(tester, state);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    unawaited(state.load());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete(ok(menuJson()));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows names and prices once loaded', (tester) async {
    final state = stateWith(() => ok(menuJson()));
    await state.load();

    await pumpPage(tester, state, width: 1000);

    expect(find.text('Classic Burger'), findsOneWidget);
    expect(find.text('25.000 VNĐ'), findsOneWidget);
    expect(find.text('Soda'), findsOneWidget);
    expect(find.text('4.000 VNĐ'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('shows a generic error with Retry, which reloads', (
    tester,
  ) async {
    var fail = true;
    final state = stateWith(
      () => fail ? http.Response('boom: secret detail', 502) : ok(menuJson()),
    );
    await state.load();

    await pumpPage(tester, state);
    expect(find.text('Không tải được thực đơn'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
    expect(find.textContaining('502'), findsNothing);

    fail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Không tải được thực đơn'), findsNothing);
    expect(find.text('Classic Burger'), findsOneWidget);
  });

  // An entirely empty menu shows the per-tab message (the old global
  // "Menu is empty" message was folded into it by the tabs card).
  testWidgets('shows the empty-tab message for an empty menu', (tester) async {
    final state = stateWith(() => ok(<Object>[]));
    await state.load();

    await pumpPage(tester, state);

    expect(find.text('Chưa có món nào trong mục này'), findsOneWidget);
  });

  testWidgets('Add puts the item in the cart', (tester) async {
    final state = stateWith(() => ok(menuJson()));
    await state.load();
    await pumpPage(tester, state, width: 1000);

    await tester.tap(find.byType(AddItemButton).first);
    await tester.pump();

    expect(Cart.instance.lines.keys.single.item.id, 'burger');
    expect(find.text('Đã thêm Classic Burger'), findsOneWidget);
  });

  group('category tabs', () {
    /// One item per category except Ăn vặt, which starts empty (TAB1).
    List<Map<String, Object>> mixedMenu({bool withNibble = false}) => [
      {
        'id': 'xoi-thit',
        'name': 'Xôi thịt',
        'description': '',
        'price': 25000.0,
        'category': 'food',
        'allowToppings': true,
      },
      {
        'id': 'mi-tom-bo',
        'name': 'Mì tôm bò',
        'description': '',
        'price': 30000.0,
        'category': 'food',
        'allowToppings': true,
      },
      {
        'id': 'tra-da',
        'name': 'Trà đá',
        'description': '',
        'price': 4000.0,
        'category': 'drink',
        'allowToppings': false,
      },
      {
        'id': 'trung-ngai-cuu',
        'name': 'Trứng ngải cứu',
        'description': '',
        'price': 10000.0,
        'category': 'snack',
        'allowToppings': false,
      },
      if (withNibble)
        {
          'id': 'khoai-lang-nuong',
          'name': 'Khoai lang nướng',
          'description': '',
          'price': 15000.0,
          'category': 'nibble',
          'allowToppings': false,
        },
    ];

    Future<void> openTab(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(Tab, label));
      await tester.pumpAndSettle();
    }

    testWidgets('shows four tabs with the owner\'s labels, in order', (
      tester,
    ) async {
      final state = stateWith(() => ok(mixedMenu()));
      await state.load();

      await pumpPage(tester, state);

      final labels = [
        for (final tab in find.byType(Tab).evaluate())
          tester
              .widget<Text>(
                find.descendant(
                  of: find.byWidget(tab.widget),
                  matching: find.byType(Text),
                ),
              )
              .data,
      ];
      expect(labels, ['Đồ ăn', 'Đồ uống', 'Ăn nhẹ', 'Ăn vặt']);
    });

    testWidgets('starts on Đồ ăn and each tab shows only its own items', (
      tester,
    ) async {
      final state = stateWith(() => ok(mixedMenu()));
      await state.load();
      await pumpPage(tester, state);

      expect(find.text('Xôi thịt'), findsOneWidget);
      expect(find.text('Mì tôm bò'), findsOneWidget);
      expect(find.text('Trà đá'), findsNothing);

      await openTab(tester, 'Đồ uống');
      expect(find.text('Trà đá'), findsOneWidget);
      expect(find.text('Xôi thịt'), findsNothing);

      await openTab(tester, 'Ăn nhẹ');
      expect(find.text('Trứng ngải cứu'), findsOneWidget);
      expect(find.text('Trà đá'), findsNothing);
    });

    testWidgets('keeps menu order inside a tab', (tester) async {
      final state = stateWith(() => ok(mixedMenu()));
      await state.load();
      await pumpPage(tester, state, width: 1000);

      final xoi = tester.getTopLeft(find.text('Xôi thịt'));
      final mi = tester.getTopLeft(find.text('Mì tôm bò'));
      expect(xoi.dx, lessThan(mi.dx), reason: 'first item comes first');
    });

    testWidgets('Ăn vặt shows the empty message when it has no items', (
      tester,
    ) async {
      final state = stateWith(() => ok(mixedMenu()));
      await state.load();
      await pumpPage(tester, state);

      await openTab(tester, 'Ăn vặt');

      expect(find.text('Chưa có món nào trong mục này'), findsOneWidget);
    });

    testWidgets('Ăn vặt shows an item once one exists', (tester) async {
      final state = stateWith(() => ok(mixedMenu(withNibble: true)));
      await state.load();
      await pumpPage(tester, state);

      await openTab(tester, 'Ăn vặt');

      expect(find.text('Khoai lang nướng'), findsOneWidget);
      expect(find.text('Chưa có món nào trong mục này'), findsNothing);
    });

    testWidgets('Add on a drink tab adds the drink to the cart', (
      tester,
    ) async {
      final state = stateWith(() => ok(mixedMenu()));
      await state.load();
      await pumpPage(tester, state);

      await openTab(tester, 'Đồ uống');
      await tester.tap(find.byType(AddItemButton));
      await tester.pump();

      expect(Cart.instance.lines.keys.single.item.id, 'tra-da');
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('the tab bar fits at 360 px (text x$scale)', (tester) async {
        final state = stateWith(() => ok(mixedMenu()));
        await state.load();

        await pumpPage(tester, state, width: 360, textScale: scale);

        expect(tester.takeException(), isNull);
        expect(find.byType(Tab), findsNWidgets(4));
        // No label may be cut off: a too-narrow tab fades its text out
        // without raising any overflow error.
        for (final label in ['Đồ ăn', 'Đồ uống', 'Ăn nhẹ', 'Ăn vặt']) {
          final text = tester.renderObject<RenderParagraph>(find.text(label));
          expect(
            text.size.width,
            greaterThanOrEqualTo(
              text.getMaxIntrinsicWidth(double.infinity) - 0.5,
            ),
            reason: '"$label" is cut off at text x$scale',
          );
        }
        final rows = addButtonRows(tester);
        expect(rows[0], rows[1], reason: '2 columns at 360 px');
      });
    }

    testWidgets('each tile has its icon, in tab order', (tester) async {
      final state = stateWith(() => ok(mixedMenu()));
      await state.load();
      await pumpPage(tester, state);

      for (final (label, icon) in [
        ('Đồ ăn', Icons.rice_bowl),
        ('Đồ uống', Icons.local_drink),
        ('Ăn nhẹ', Icons.bakery_dining),
        ('Ăn vặt', Icons.cookie),
      ]) {
        expect(
          find.descendant(
            of: find.widgetWithText(Tab, label),
            matching: find.byIcon(icon),
          ),
          findsOneWidget,
          reason: label,
        );
      }
    });

    Color? labelColour(WidgetTester tester, String label) =>
        tester.widget<Text>(find.text(label)).style?.color;

    testWidgets('the selected tile is highlighted, and it follows taps', (
      tester,
    ) async {
      final state = stateWith(() => ok(mixedMenu()));
      await state.load();
      await pumpPage(tester, state);
      final primary = Theme.of(tester.element(find.byType(TabBar)))
          .colorScheme
          .primary;

      expect(labelColour(tester, 'Đồ ăn'), primary);
      expect(labelColour(tester, 'Đồ uống'), isNot(primary));
      FontWeight? weight(String label) =>
          tester.widget<Text>(find.text(label)).style?.fontWeight;
      expect(weight('Đồ ăn'), FontWeight.bold);
      expect(weight('Đồ uống'), isNot(FontWeight.bold));

      await openTab(tester, 'Đồ uống');
      expect(weight('Đồ uống'), FontWeight.bold);

      expect(labelColour(tester, 'Đồ uống'), primary);
      expect(labelColour(tester, 'Đồ ăn'), isNot(primary));
    });

    testWidgets('tapping a far tile never highlights the ones in between', (
      tester,
    ) async {
      final state = stateWith(() => ok(mixedMenu(withNibble: true)));
      await state.load();
      await pumpPage(tester, state);
      final primary = Theme.of(tester.element(find.byType(TabBar)))
          .colorScheme
          .primary;

      await tester.tap(find.widgetWithText(Tab, 'Ăn vặt'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(labelColour(tester, 'Đồ uống'), isNot(primary));
        expect(labelColour(tester, 'Ăn nhẹ'), isNot(primary));
      }
      await tester.pumpAndSettle();
      expect(labelColour(tester, 'Ăn vặt'), primary);
    });

    testWidgets('swiping the menu moves the selection', (tester) async {
      final state = stateWith(() => ok(mixedMenu()));
      await state.load();
      await pumpPage(tester, state);
      final primary = Theme.of(tester.element(find.byType(TabBar)))
          .colorScheme
          .primary;

      await tester.fling(find.byType(TabBarView), const Offset(-600, 0), 2000);
      await tester.pumpAndSettle();

      expect(find.text('Trà đá'), findsOneWidget);
      expect(labelColour(tester, 'Đồ uống'), primary);
      expect(labelColour(tester, 'Đồ ăn'), isNot(primary));
    });

    testWidgets('at 360 px and text x2.0 the last tile can be scrolled to '
        'and selected', (tester) async {
      final state = stateWith(() => ok(mixedMenu(withNibble: true)));
      await state.load();
      await pumpPage(tester, state, width: 360, textScale: 2.0);
      expect(tester.takeException(), isNull);

      await tester.dragUntilVisible(
        find.widgetWithText(Tab, 'Ăn vặt'),
        find.byType(TabBar),
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Ăn vặt'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Khoai lang nướng'), findsOneWidget);
    });

    testWidgets('the chosen tab is kept after visiting the cart', (
      tester,
    ) async {
      final state = stateWith(() => ok(mixedMenu()));
      await state.load();
      await pumpPage(tester, state);

      await openTab(tester, 'Đồ uống');
      await tester.tap(find.byTooltip('Giỏ hàng'));
      await tester.pumpAndSettle();
      expect(find.text('Giỏ hàng của bạn'), findsOneWidget);
      await goBack(tester);
      await tester.pumpAndSettle();

      expect(find.text('Trà đá'), findsOneWidget);
      expect(find.text('Xôi thịt'), findsNothing);
    });

    group('Your orders banner', () {
      Order order(String id, OrderStatus status) => Order(
        id: id,
        customerName: 'An',
        items: [OrderItem(name: 'Xôi thịt', quantity: 1, price: 25000)],
        status: status,
        placedAt: DateTime(2026, 11, 12, 8, 30),
      );

      testWidgets('shows on Đồ ăn and Đồ uống with an active order', (
        tester,
      ) async {
        final state = stateWith(() => ok(mixedMenu()));
        await state.load();
        OrderRepository.instance.setOrdersForTest([
          order('mine', OrderStatus.preparing),
        ]);
        MyOrders.instance.track('mine');
        await pumpPage(tester, state);

        expect(find.text('Đơn của bạn'), findsOneWidget);
        await openTab(tester, 'Đồ uống');
        expect(find.text('Đơn của bạn'), findsOneWidget);
        expect(find.text('Trà đá'), findsOneWidget);
      });

      testWidgets('is absent without an active order of this browser', (
        tester,
      ) async {
        final state = stateWith(() => ok(mixedMenu()));
        await state.load();
        OrderRepository.instance.setOrdersForTest([
          order('mine-done', OrderStatus.delivered),
          order('someone-else', OrderStatus.preparing),
        ]);
        MyOrders.instance.track('mine-done');
        await pumpPage(tester, state);

        expect(find.text('Đơn của bạn'), findsNothing);
        await openTab(tester, 'Đồ uống');
        expect(find.text('Đơn của bạn'), findsNothing);
      });

      group('transfer orders', () {
        Order transfer(
          String id,
          OrderStatus status, {
          required Duration dueIn,
          bool withDue = true,
        }) => Order(
          id: id,
          customerName: 'An',
          items: [OrderItem(name: 'Xôi thịt', quantity: 1, price: 25000)],
          status: status,
          placedAt: DateTime(2026, 11, 12, 8, 30),
          paymentMethod: PaymentMethod.bank_transfer,
          paymentDueAt: withDue ? DateTime.now().toUtc().add(dueIn) : null,
        );

        Future<void> show(WidgetTester tester, List<Order> orders) async {
          final state = stateWith(() => ok(mixedMenu()));
          await state.load();
          OrderRepository.instance.setOrdersForTest(orders);
          for (final o in orders) {
            MyOrders.instance.track(o.id);
          }
          await pumpPage(tester, state, width: 360);
        }

        testWidgets('an awaiting order opens the payment page on tap', (
          tester,
        ) async {
          await show(tester, [
            transfer(
              'wait-0001',
              OrderStatus.awaiting_payment,
              dueIn: const Duration(minutes: 5),
            ),
          ]);
          expect(find.text('Đơn của bạn'), findsOneWidget);
          expect(find.text('Chờ thanh toán'), findsOneWidget);

          await tester.tap(find.text('#0001'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(PaymentQrPage), findsOneWidget);
          expect(find.text('Chuyển sang tiền mặt'), findsOneWidget);
          // Leave before the page's one-second timer matters.
          await goBack(tester);
          await tester.pumpAndSettle();
        });

        testWidgets('an order expired within 15 minutes is listed and asks', (
          tester,
        ) async {
          // Cancelled 6 minutes ago: its deadline was 6 minutes ago.
          await show(tester, [
            transfer(
              'late-0002',
              OrderStatus.cancelled,
              dueIn: const Duration(minutes: -6),
            ),
          ]);
          expect(find.text('Đơn của bạn'), findsOneWidget);
          expect(find.text('Hết hạn thanh toán'), findsOneWidget);

          await tester.tap(find.text('#0002'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Tạo mã QR mới'), findsOneWidget);
          await goBack(tester);
          await tester.pumpAndSettle();
        });

        testWidgets('past 15 minutes, staff-cancelled and delivered stay off', (
          tester,
        ) async {
          await show(tester, [
            transfer(
              'old-0003',
              OrderStatus.cancelled,
              dueIn: const Duration(minutes: -16),
            ),
            transfer(
              'staff-0004',
              OrderStatus.cancelled,
              dueIn: Duration.zero,
              withDue: false,
            ),
            transfer(
              'done-0005',
              OrderStatus.delivered,
              dueIn: const Duration(minutes: -30),
            ),
          ]);
          expect(find.text('Đơn của bạn'), findsNothing);
        });
      });
    });

    testWidgets('each tab keeps its scroll position', (tester) async {
      final menu = [
        for (var i = 0; i < 30; i++)
          {
            'id': 'food-$i',
            'name': 'Món $i',
            'description': '',
            'price': 25000.0,
            'category': 'food',
            'allowToppings': true,
          },
        ...mixedMenu(),
      ];
      final state = stateWith(() => ok(menu));
      await state.load();
      await pumpPage(tester, state, width: 360);

      ScrollPosition tabScroll() => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;

      tabScroll().jumpTo(600);
      await tester.pumpAndSettle();
      expect(tabScroll().pixels, 600);

      await openTab(tester, 'Đồ uống');
      expect(tabScroll().pixels, 0, reason: 'other tabs start at the top');
      await openTab(tester, 'Đồ ăn');

      expect(tabScroll().pixels, 600);
    });
  });

  group('grid layout', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('2 columns at 360 px, no overflow (text x$scale)', (
        tester,
      ) async {
        final state = stateWith(() => ok(menuJson()));
        await state.load();

        await pumpPage(tester, state, width: 360, textScale: scale);

        final rows = addButtonRows(tester);
        expect(rows.length, greaterThanOrEqualTo(2));
        expect(rows[0], rows[1], reason: 'first two tiles share a row');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a 60-character name at text x2.0 still fits at 360 px', (
      tester,
    ) async {
      final long = menuJson()
        ..[0] = {
          ...menuJson()[0],
          'name': 'Extra Large Double Cheese Bacon Burger With Everything On',
        };
      final state = stateWith(() => ok(long));
      await state.load();

      await pumpPage(tester, state, width: 360, textScale: 2.0);

      expect(tester.takeException(), isNull);
      expect(find.byType(AddItemButton), findsWidgets);
    });

    testWidgets('a long VND price at text x2.0 still fits at 360 px', (
      tester,
    ) async {
      final pricey = menuJson()..[0] = {...menuJson()[0], 'price': 1250000.0};
      final state = stateWith(() => ok(pricey));
      await state.load();

      await pumpPage(tester, state, width: 360, textScale: 2.0);

      expect(tester.takeException(), isNull);
      expect(find.text('1.250.000 VNĐ'), findsOneWidget);
    });

    testWidgets('more columns at 1000 px than at 360 px', (tester) async {
      final state = stateWith(() => ok(menuJson()));
      await state.load();

      await pumpPage(tester, state, width: 360);
      final narrow = addButtonRows(tester)
          .where((dy) => dy == addButtonRows(tester).first)
          .length;

      await pumpPage(tester, state, width: 1000);
      final wide = addButtonRows(tester)
          .where((dy) => dy == addButtonRows(tester).first)
          .length;

      expect(narrow, 2);
      expect(wide, greaterThan(narrow));
    });
  });

  group('cart refresh after a menu reload', () {
    testWidgets('cart lines take the new price; removed items leave', (
      tester,
    ) async {
      var body = menuJson();
      final state = stateWith(() => ok(body));
      await state.load();
      await pumpPage(tester, state, width: 1000);

      // Put a burger (9.50) and fries in the cart.
      await tester.tap(find.byType(AddItemButton).at(0));
      await tester.tap(find.byType(AddItemButton).at(3));
      await tester.pumpAndSettle();

      // The owner raises the burger price and removes fries; the menu reloads.
      body = menuJson(burgerPrice: 27000)
        ..removeWhere((item) => item['id'] == 'fries');
      // Not runAsync: the snackbar's timer must live on the test's fake
      // clock, or it fires after the test has torn the page down.
      unawaited(state.load());
      await tester.pumpAndSettle();

      final cart = Cart.instance.lines;
      expect(cart.keys.map((l) => l.item.id), ['burger']);
      expect(cart.keys.single.item.price, 27000);
      expect(cart.values.single, 1);
      expect(
        find.text(
          'Giá của 1 món trong giỏ hàng đã thay đổi. '
          '1 món không còn trong thực đơn và đã bị xóa khỏi giỏ hàng.',
        ),
        findsOneWidget,
      );
    });
  });

  group('tile pictures', () {
    /// Gives the test environment's network error (it answers every request
    /// with an error, at once) about 100 ms of real time to reach the
    /// pictures. A fixed wait: with `frameBuilder` the placeholder also shows
    /// while loading, so there is no visible signal to poll for. The
    /// failed-load test is still not vacuous: without `errorBuilder` the
    /// error arrives within this wait and replaces the placeholder.
    Future<void> settleImages(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    Map<String, Object?> food(String id, String name, String? image) => {
      'id': id,
      'name': name,
      'description': '',
      'price': 25000.0,
      'category': 'food',
      'allowToppings': true,
      'image': image,
    };

    Finder cardOf(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(Card));

    testWidgets('no picture: the placeholder, and no Image widget', (
      tester,
    ) async {
      final state = stateWith(() => ok([food('xoi-thit', 'Xôi thịt', null)]));
      await state.load();
      await pumpPage(tester, state);

      expect(find.byType(Image), findsNothing);
      expect(
        find.descendant(
          of: cardOf('Xôi thịt'),
          matching: find.byIcon(Icons.restaurant),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a picture loads from /api/images/<name>; a failed load '
        'shows the placeholder at the same size', (tester) async {
      final state = stateWith(
        () => ok([
          food('xoi-thit', 'Xôi thịt', 'xoi-thit.webp'),
          food('xoi-ruoc', 'Xôi ruốc', null),
        ]),
      );
      await state.load();
      await pumpPage(tester, state);

      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image as ResizeImage;
      expect(
        (provider.imageProvider as NetworkImage).url,
        '/api/images/xoi-thit.webp',
      );
      expect(provider.width, isNotNull, reason: 'decoded at a capped width');
      expect(image.semanticLabel, 'Xôi thịt');
      expect(image.fit, BoxFit.cover);

      // The test environment answers every network request with an error,
      // so this is the errorBuilder path (a missing file, or offline).
      await settleImages(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: cardOf('Xôi thịt'),
          matching: find.byIcon(Icons.restaurant),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(cardOf('Xôi thịt')),
        tester.getSize(cardOf('Xôi ruốc')),
      );
    });

    for (final scale in [1.0, 1.3]) {
      testWidgets('a mixed grid fits at 360 px, 2 per row (text x$scale)', (
        tester,
      ) async {
        final state = stateWith(
          () => ok([
            food('a', 'Xôi thịt', 'xoi-thit.webp'),
            food('b', 'Xôi ruốc', null),
            food('c', 'Mì tôm bò', 'mi-tom-bo.jpg'),
            food('d', 'Mì tôm trứng', null),
          ]),
        );
        await state.load();
        await pumpPage(tester, state, width: 360, textScale: scale);
        await settleImages(tester);

        expect(tester.takeException(), isNull);
        final rows = addButtonRows(tester);
        expect(rows[0], rows[1], reason: '2 columns at 360 px');
        expect(rows[2], greaterThan(rows[0]));
      });
    }
  });

  group('tile redesign', () {
    Map<String, Object?> food(String id, String name, String description) => {
      'id': id,
      'name': name,
      'description': description,
      'price': 25000.0,
      'category': 'food',
      'allowToppings': false,
    };

    testWidgets('a tile shows name, price and a "+" - no description', (
      tester,
    ) async {
      final state = stateWith(
        () => ok([food('xoi-thit', 'Xôi thịt', 'Thịt kho, hành phi')]),
      );
      await state.load();
      await pumpPage(tester, state);

      expect(find.text('Xôi thịt'), findsOneWidget);
      expect(find.text('25.000 VNĐ'), findsOneWidget);
      expect(find.byTooltip('Thêm Xôi thịt'), findsOneWidget);
      expect(find.text('Thịt kho, hành phi'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Thêm'), findsNothing);
    });

    testWidgets('the "+" tap target is at least 48 x 48', (tester) async {
      final state = stateWith(() => ok([food('a', 'Xôi thịt', '')]));
      await state.load();
      await pumpPage(tester, state);

      final size = tester.getSize(find.byType(AddItemButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('the "+" on a direct-add item adds it and shows the SnackBar', (
      tester,
    ) async {
      final state = stateWith(() => ok([food('a', 'Xôi thịt', '')]));
      await state.load();
      await pumpPage(tester, state);

      await tester.tap(find.byTooltip('Thêm Xôi thịt'));
      await tester.pump();

      expect(Cart.instance.lines.keys.single.item.id, 'a');
      expect(find.text('Đã thêm Xôi thịt'), findsOneWidget);
    });

    testWidgets('AddItemButton with onPressed null is disabled', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        l10nApp(
          home: Scaffold(
            body: Row(
              children: [
                const AddItemButton(tooltip: 'Thêm hết hàng', onPressed: null),
                AddItemButton(tooltip: 'Thêm được', onPressed: () => taps++),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Thêm hết hàng'), warnIfMissed: false);
      await tester.tap(find.byTooltip('Thêm được'));
      await tester.pump();

      expect(taps, 1);
      final disabled = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Thêm hết hàng',
        ),
      );
      expect(disabled.onPressed, isNull);
      expect(find.byTooltip('Thêm hết hàng'), findsOneWidget);
    });
  });

  group('cart button', () {
    List<Map<String, Object?>> foods(int n) => [
      for (var i = 0; i < n; i++)
        {
          'id': 'f$i',
          'name': 'Món $i',
          'description': '',
          'price': 25000.0,
          'category': 'food',
          'allowToppings': false,
        },
    ];

    Finder badgeText() => find.descendant(
      of: find.byType(FloatingActionButton),
      matching: find.byType(Text),
    );

    testWidgets('one round cart button at the bottom, none in the top bar', (
      tester,
    ) async {
      final state = stateWith(() => ok(foods(2)));
      await state.load();
      await pumpPage(tester, state);

      expect(find.byTooltip('Giỏ hàng'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.shopping_cart),
        ),
        findsNothing,
      );
      expect(find.byType(BottomAppBar), findsOneWidget);
      final button = tester.getSize(find.byType(FloatingActionButton));
      expect(button.width, greaterThanOrEqualTo(56));
      expect(
        tester.getCenter(find.byType(FloatingActionButton)).dx,
        closeTo(400, 1),
        reason: 'centred on an 800 px screen',
      );
    });

    testWidgets('the badge is hidden when empty and counts items live', (
      tester,
    ) async {
      final state = stateWith(() => ok(foods(2)));
      await state.load();
      await pumpPage(tester, state);
      expect(badgeText(), findsNothing);

      await tester.tap(find.byTooltip('Thêm Món 0'));
      await tester.pump();
      expect(tester.widget<Text>(badgeText()).data, '1');

      await tester.tap(find.byTooltip('Thêm Món 0'));
      await tester.tap(find.byTooltip('Thêm Món 1'));
      await tester.pump();
      expect(tester.widget<Text>(badgeText()).data, '3');
    });

    testWidgets('the button opens the cart; back keeps the chosen tab', (
      tester,
    ) async {
      final state = stateWith(
        () => ok([
          ...foods(1),
          {
            'id': 'tra-da',
            'name': 'Trà đá',
            'description': '',
            'price': 4000.0,
            'category': 'drink',
            'allowToppings': false,
          },
        ]),
      );
      await state.load();
      await pumpPage(tester, state);
      await tester.tap(find.widgetWithText(Tab, 'Đồ uống'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Giỏ hàng'));
      await tester.pumpAndSettle();
      expect(find.text('Giỏ hàng của bạn'), findsOneWidget);
      expect(find.byType(BottomAppBar), findsNothing, reason: 'menu only');

      await goBack(tester);
      await tester.pumpAndSettle();
      expect(find.text('Trà đá'), findsOneWidget);
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('at 360 px (text x$scale) the last tile scrolls clear of '
          'the bar and its "+" works', (tester) async {
        final state = stateWith(() => ok(foods(9)));
        await state.load();
        await pumpPage(tester, state, width: 360, textScale: scale);
        expect(tester.takeException(), isNull);

        final last = find.byTooltip('Thêm Món 8');
        await tester.scrollUntilVisible(
          last,
          300,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, -2000),
          3000,
        );
        await tester.pumpAndSettle();

        final plus = tester.getRect(last);
        final fab = tester.getRect(find.byType(FloatingActionButton));
        // The whole last tile, not just its "+", stays clear of the cart
        // button that sticks up above the bar. (The body ends at the top of
        // the bar, so only the button can cover a tile.)
        final tile = tester.getRect(
          find.ancestor(of: last, matching: find.byType(Card)),
        );
        expect(plus.overlaps(fab), isFalse);
        expect(tile.overlaps(fab), isFalse);
        await tester.tap(last);
        await tester.pump();
        expect(Cart.instance.lines.keys.single.item.id, 'f8');
        expect(tester.takeException(), isNull);
        // Still 2 columns: some row holds exactly two "+" buttons.
        final rows = addButtonRows(tester);
        expect(rows.any((y) => rows.where((r) => r == y).length == 2), isTrue);
      });
    }

    testWidgets('the "Added" SnackBar does not cover the cart button', (
      tester,
    ) async {
      final state = stateWith(() => ok(foods(1)));
      await state.load();
      await pumpPage(tester, state, width: 360);

      await tester.tap(find.byTooltip('Thêm Món 0'));
      await tester.pumpAndSettle();

      final snack = tester.getRect(find.byType(SnackBar));
      final fab = tester.getRect(find.byType(FloatingActionButton));
      expect(find.text('Đã thêm Món 0'), findsOneWidget);
      expect(snack.overlaps(fab), isFalse);
    });
  });
}
