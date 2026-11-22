import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/customer/pages/cart_page.dart';
import 'package:food_orders/customer/state/cart.dart';
import 'package:food_orders/customer/state/menu_state.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/models/menu_item.dart';
import 'package:food_orders/shared/models/topping.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const xoi = MenuItem(
  id: 'xoi-thit',
  name: 'Xôi thịt',
  description: '',
  price: 25000,
);
const traDa = MenuItem(
  id: 'tra-da',
  name: 'Trà đá',
  description: '',
  price: 4000,
  category: MenuCategory.drink,
  allowToppings: false,
);
const cha = Topping(id: 'cha', name: 'Thêm chả', price: 10000);
const trung = Topping(id: 'trung-trang', name: 'Thêm trứng tráng', price: 8000);

http.Response utf8Json(Object body, {int status = 200}) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  final cart = Cart.instance;
  setUp(cart.clear);
  tearDown(cart.clear);

  group('cart lines', () {
    test('the same plain dish twice is one line with quantity 2', () {
      cart
        ..add(xoi)
        ..add(xoi);

      expect(cart.lines, hasLength(1));
      expect(cart.lines.values.single, 2);
    });

    test('a dish with and without toppings are two lines', () {
      cart
        ..add(xoi)
        ..add(xoi, toppings: [cha]);

      expect(cart.lines, hasLength(2));
    });

    test('topping order does not matter', () {
      cart
        ..add(xoi, toppings: [cha, trung])
        ..add(xoi, toppings: [trung, cha]);

      expect(cart.lines, hasLength(1));
      expect(cart.lines.values.single, 2);
    });

    test('different toppings are separate lines', () {
      cart
        ..add(xoi, toppings: [cha])
        ..add(xoi, toppings: [trung]);

      expect(cart.lines, hasLength(2));
    });

    test('a topping picked twice counts once on the line', () {
      cart.add(xoi, toppings: [cha, cha]);

      expect(cart.lines.keys.single.toppings, [cha]);
      expect(cart.total, 35000);
    });

    test('remove decrements, then deletes only that line', () {
      cart
        ..add(xoi)
        ..add(xoi, toppings: [cha])
        ..add(xoi, toppings: [cha]);
      final withCha = CartLine(xoi, [cha]);

      cart.remove(withCha);
      expect(cart.lines[withCha], 1);
      cart.remove(withCha);

      expect(cart.lines.keys, [CartLine(xoi)]);
    });

    test('total and itemCount include toppings and quantities', () {
      cart
        ..add(xoi, toppings: [cha, trung]) // 43.000
        ..add(xoi, toppings: [cha, trung]) // 43.000
        ..add(traDa); // 4.000

      expect(cart.itemCount, 3);
      expect(cart.total, 90000);
    });

    test('toOrderItems carries ids, the base price and the toppings', () {
      cart
        ..add(xoi, toppings: [cha])
        ..add(traDa);

      final items = cart.toOrderItems();

      expect(items.map((i) => i.toJson()), [
        {
          'id': 'xoi-thit',
          'name': 'Xôi thịt',
          'quantity': 1,
          'price': 25000,
          'toppings': [
            {'id': 'cha', 'name': 'Thêm chả', 'price': 10000},
          ],
        },
        {'id': 'tra-da', 'name': 'Trà đá', 'quantity': 1, 'price': 4000},
      ]);
    });

    test('clear empties the cart', () {
      cart
        ..add(xoi)
        ..clear();

      expect(cart.isEmpty, isTrue);
    });
  });

  group('refresh after a menu reload', () {
    test('a changed dish or topping price reprices the line', () {
      cart.add(xoi, toppings: [cha]);

      final result = cart.refreshItems(
        [
          const MenuItem(
            id: 'xoi-thit',
            name: 'Xôi thịt đặc biệt',
            description: '',
            price: 27000,
          ),
        ],
        [const Topping(id: 'cha', name: 'Thêm chả', price: 11000)],
      );

      expect(result, (removed: 0, repriced: 1));
      expect(cart.lines.keys.single.unitPrice, 38000);
      expect(cart.lines.keys.single.item.name, 'Xôi thịt đặc biệt');
      expect(cart.lines.keys.single.toppings.single.name, 'Thêm chả');
      expect(cart.lines.values.single, 1);
    });

    test('a line whose topping left the menu is removed', () {
      cart
        ..add(xoi, toppings: [cha])
        ..add(xoi);

      final result = cart.refreshItems([xoi], [trung]);

      expect(result, (removed: 1, repriced: 0));
      expect(cart.lines.keys, [CartLine(xoi)]);
    });

    test('a line whose dish left the menu is removed', () {
      cart
        ..add(xoi)
        ..add(traDa);

      final result = cart.refreshItems([traDa], [cha]);

      expect(result, (removed: 1, repriced: 0));
      expect(cart.lines.keys.single.item.id, 'tra-da');
    });
  });

  group('MenuState with toppings', () {
    test('retry recovers once toppings load again', () async {
      var fail = true;
      final s = MenuState(
        OrderApiClient(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/toppings')) {
              return fail
                  ? http.Response('down', 502)
                  : utf8Json([
                      {'id': 'cha', 'name': 'Thêm chả', 'price': 10000.0},
                    ]);
            }
            return utf8Json([
              {
                'id': 'xoi-thit',
                'name': 'Xôi thịt',
                'description': '',
                'price': 25000.0,
              },
            ]);
          }),
        ),
      );

      await s.load();
      expect(s.error, isNotNull);

      fail = false;
      await s.load();
      expect(s.error, isNull);
      expect(s.hasLoaded, isTrue);
      expect(s.toppings.single.id, 'cha');
    });

    MenuState state({bool toppingsFail = false}) => MenuState(
      OrderApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/toppings')) {
            return toppingsFail
                ? http.Response('down', 502)
                : utf8Json([
                    {'id': 'cha', 'name': 'Thêm chả', 'price': 10000.0},
                  ]);
          }
          return utf8Json([
            {
              'id': 'xoi-thit',
              'name': 'Xôi thịt',
              'description': '',
              'price': 25000.0,
            },
          ]);
        }),
      ),
    );

    test('loads the menu and the toppings together', () async {
      final s = state();

      await s.load();

      expect(s.items.single.id, 'xoi-thit');
      expect(s.toppings.single.id, 'cha');
      expect(s.error, isNull);
    });

    test(
      'a failing toppings request is the same error as a failing menu',
      () async {
        final s = state(toppingsFail: true);

        await s.load();

        expect(s.error, isA<http.ClientException>());
        expect(s.hasLoaded, isFalse);
        expect(s.isLoading, isFalse);
      },
    );
  });

  group('cart page', () {
    testWidgets('shows a toppings line, per-line +/- and the total', (
      tester,
    ) async {
      cart
        ..add(traDa)
        ..add(xoi, toppings: [cha, trung]);

      await tester.pumpWidget(const MaterialApp(home: CartPage()));

      expect(find.text('+ Thêm chả   + Thêm trứng tráng'), findsOneWidget);
      expect(find.text('43.000 VNĐ each'), findsOneWidget);
      expect(find.text('4.000 VNĐ each'), findsOneWidget);
      expect(find.text('Total: 47.000 VNĐ'), findsOneWidget);

      // + on the topping line only touches that line.
      final toppingTile = find.ancestor(
        of: find.text('Xôi thịt'),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(of: toppingTile, matching: find.byIcon(Icons.add)),
      );
      await tester.pump();

      expect(cart.lines[CartLine(xoi, [cha, trung])], 2);
      expect(cart.lines[CartLine(traDa)], 1);
      expect(find.text('Total: 90.000 VNĐ'), findsOneWidget);

      // − on the plain line removes it and leaves the topping line alone.
      final plainTile = find.ancestor(
        of: find.text('Trà đá'),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(of: plainTile, matching: find.byIcon(Icons.remove)),
      );
      await tester.pump();

      expect(cart.lines.keys, [
        CartLine(xoi, [cha, trung]),
      ]);
      expect(cart.lines.values.single, 2);
      expect(find.text('Total: 86.000 VNĐ'), findsOneWidget);
    });
  });
}
