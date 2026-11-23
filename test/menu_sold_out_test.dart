import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/customer/pages/add_food_dialog.dart';
import 'package:food_orders/customer/pages/menu_page.dart';
import 'package:food_orders/customer/state/cart.dart';
import 'package:food_orders/customer/state/menu_state.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/models/menu_item.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object> item(
  String id,
  String name,
  String category, {
  bool available = true,
  bool allowToppings = false,
}) => {
  'id': id,
  'name': name,
  'description': '',
  'price': 20000,
  'category': category,
  'allowToppings': allowToppings,
  'available': available,
};

const toppings = [
  {'id': 'cha', 'name': 'Thêm chả', 'price': 10000},
];

Future<MenuState> loaded(List<Map<String, Object>> menu) async {
  final state = MenuState(
    OrderApiClient(
      client: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode(
              request.url.path.endsWith('/toppings') ? toppings : menu,
            ),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    ),
  );
  await state.load();
  return state;
}

Future<void> pump(
  WidgetTester tester,
  MenuState state, {
  double width = 800,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: MenuPage(state: state),
    ),
  );
}

IconButton plusButton(WidgetTester tester, String name) =>
    tester.widget<IconButton>(
      find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Thêm $name',
      ),
    );

void main() {
  setUp(Cart.instance.clear);
  tearDown(Cart.instance.clear);

  testWidgets('a sold-out food shows the label; its "+" is disabled', (
    tester,
  ) async {
    await pump(
      tester,
      await loaded([
        item('a', 'Xôi thịt', 'food', available: false, allowToppings: true),
      ]),
    );

    expect(find.text('Hết hàng'), findsOneWidget);
    expect(plusButton(tester, 'Xôi thịt').onPressed, isNull);
    await tester.tap(find.byTooltip('Thêm Xôi thịt'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(Cart.instance.lines, isEmpty);
  });

  testWidgets('a sold-out drink in the grid is not addable', (tester) async {
    await pump(
      tester,
      await loaded([item('t', 'Trà đá', 'drink', available: false)]),
    );
    await tester.tap(find.widgetWithText(Tab, 'Đồ uống'));
    await tester.pumpAndSettle();

    expect(find.text('Hết hàng'), findsOneWidget);
    expect(plusButton(tester, 'Trà đá').onPressed, isNull);
    await tester.tap(find.byTooltip('Thêm Trà đá'), warnIfMissed: false);
    await tester.pump();
    expect(Cart.instance.lines, isEmpty);
    expect(find.text('Đã thêm Trà đá'), findsNothing);
  });

  testWidgets('an available item has no label and still adds', (tester) async {
    await pump(tester, await loaded([item('a', 'Xôi ruốc', 'food')]));

    expect(find.text('Hết hàng'), findsNothing);
    await tester.tap(find.byTooltip('Thêm Xôi ruốc'));
    await tester.pumpAndSettle();
    // Asks nothing (no toppings, no drinks), so it goes straight in.
    expect(Cart.instance.lines.keys.single.item.id, 'a');
    expect(find.text('Đã thêm Xôi ruốc'), findsOneWidget);
  });

  testWidgets('a mixed list renders both kinds in the original order', (
    tester,
  ) async {
    await pump(
      tester,
      await loaded([
        item('a', 'Xôi A', 'food', available: false),
        item('b', 'Xôi B', 'food'),
        item('c', 'Xôi C', 'food', available: false),
      ]),
    );

    expect(find.text('Hết hàng'), findsNWidgets(2));
    expect(plusButton(tester, 'Xôi A').onPressed, isNull);
    expect(plusButton(tester, 'Xôi B').onPressed, isNotNull);
    expect(plusButton(tester, 'Xôi C').onPressed, isNull);
    final xs = [
      for (final n in ['Xôi A', 'Xôi B', 'Xôi C'])
        tester.getTopLeft(find.text(n)).dx,
    ];
    expect(xs[0], lessThan(xs[1]));
    expect(xs[1], lessThan(xs[2]));
  });

  testWidgets('a sold-out drink is listed but cannot be chosen in the dialog', (
    tester,
  ) async {
    await pump(
      tester,
      await loaded([
        item('a', 'Xôi thịt', 'food'),
        item('t', 'Trà đá', 'drink', available: false),
        item('b', 'Bò húc', 'drink'),
      ]),
    );
    await tester.tap(find.byTooltip('Thêm Xôi thịt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm đồ uống'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Tiếp'));
    await tester.pumpAndSettle();

    expect(find.text('Trà đá'), findsOneWidget);
    expect(find.text('Hết hàng'), findsOneWidget);
    await tester.tap(find.text('Trà đá'), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Nothing chosen, so the confirm button stays disabled.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Thêm'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Bò húc'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
    await tester.pumpAndSettle();
    expect([for (final l in Cart.instance.lines.keys) l.item.id], ['a', 'b']);
  });

  test('addFoodAsks ignores a list of only sold-out drinks', () {
    MenuItem make(bool available) => MenuItem(
      id: 'x',
      name: 'x',
      description: '',
      price: 1,
      category: MenuCategory.drink,
      available: available,
    );
    final dish = make(true);
    expect(addFoodAsks(dish, const [], [make(false)]), isFalse);
    expect(addFoodAsks(dish, const [], [make(false), make(true)]), isTrue);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('sold-out tiles fit at 360 px (text x$scale)', (tester) async {
      await pump(
        tester,
        await loaded([
          item('a', 'Xôi thịt rất là dài tên', 'food', available: false),
          item('b', 'Xôi ruốc', 'food'),
        ]),
        width: 360,
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Hết hàng'), findsOneWidget);
    });
  }
}
