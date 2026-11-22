import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/customer/state/cart.dart';
import 'package:food_orders/customer/state/menu_state.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/models/menu_item.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const menuBody =
    '[{"id":"burger","name":"Classic Burger","description":"Beef","price":9.5},'
    '{"id":"fries","name":"Fries","description":"Salted","price":3.5}]';

void main() {
  group('MenuState', () {
    test('goes loading -> loaded', () async {
      final state = MenuState(
        OrderApiClient(
          client: MockClient((_) async => http.Response(menuBody, 200)),
        ),
      );
      final seen = <bool>[];
      state.addListener(() => seen.add(state.isLoading));

      await state.load();

      expect(seen, [true, false]);
      expect(state.items.map((i) => i.id), ['burger', 'fries']);
      expect(state.error, isNull);
    });

    test('goes loading -> error, then recovers on retry', () async {
      var fail = true;
      final state = MenuState(
        OrderApiClient(
          client: MockClient(
            (_) async => fail
                ? http.Response('down', 502)
                : http.Response(menuBody, 200),
          ),
        ),
      );

      await state.load();
      expect(state.isLoading, isFalse);
      expect(state.error, isA<http.ClientException>());
      expect(state.items, isEmpty);

      fail = false;
      await state.load();
      expect(state.error, isNull);
      expect(state.items, hasLength(2));
    });

    test('malformed menu data becomes an error, not a crash', () async {
      final state = MenuState(
        OrderApiClient(
          client: MockClient(
            (_) async => http.Response('[{"id":"x","price":"free"}]', 200),
          ),
        ),
      );

      await state.load();

      expect(state.error, isA<FormatException>());
      expect(state.isLoading, isFalse);
    });

    test('a second load() while one is running sends no request', () async {
      final paths = <String>[];
      final gate = Completer<void>();
      final state = MenuState(
        OrderApiClient(
          client: MockClient((request) async {
            paths.add(request.url.path);
            await gate.future;
            return request.url.path.endsWith('/toppings')
                ? http.Response('[]', 200)
                : http.Response(menuBody, 200);
          }),
        ),
      );

      final first = state.load();
      // Let the first load's requests reach the mock (sent asynchronously).
      await Future<void>.delayed(Duration.zero);
      // One load = one menu request + one toppings request.
      expect(paths, unorderedEquals(['/api/menu', '/api/toppings']));

      await state.load(); // returns immediately: already loading
      await Future<void>.delayed(Duration.zero);
      expect(paths, hasLength(2));

      gate.complete();
      await first;
      expect(paths, hasLength(2));
      expect(state.items, hasLength(2));
    });
  });

  test('hasLoaded is false until a load succeeds', () async {
    var fail = true;
    final state = MenuState(
      OrderApiClient(
        client: MockClient(
          (_) async =>
              fail ? http.Response('down', 502) : http.Response('[]', 200),
        ),
      ),
    );
    expect(state.hasLoaded, isFalse);

    await state.load();
    expect(state.hasLoaded, isFalse);

    fail = false;
    await state.load();
    expect(state.hasLoaded, isTrue);
    expect(state.items, isEmpty);
  });

  group('Cart.refreshItems', () {
    MenuItem item(String id, double price) =>
        MenuItem(id: id, name: 'Item $id', description: '', price: price);

    setUp(Cart.instance.clear);
    tearDown(Cart.instance.clear);

    test('swaps in the fresh item and keeps the quantity', () {
      final cart = Cart.instance
        ..add(item('burger', 9.5))
        ..add(item('burger', 9.5));

      final result = cart.refreshItems([item('burger', 10.5)], const []);

      expect(result, (removed: 0, repriced: 1));
      expect(cart.lines.keys.single.item.price, 10.5);
      expect(cart.lines.values.single, 2);
      expect(cart.total, 21.0);
    });

    test('removes items that left the menu and counts them', () {
      final cart = Cart.instance
        ..add(item('burger', 9.5))
        ..add(item('fries', 3.5));

      final result = cart.refreshItems([item('burger', 9.5)], const []);

      expect(result, (removed: 1, repriced: 0));
      expect(cart.lines.keys.map((l) => l.item.id), ['burger']);
    });
  });

  test('Cart keeps one entry for two separately parsed copies of an item', () {
    final cart = Cart.instance;
    addTearDown(cart.clear);
    cart.clear();
    final burgerJson = (jsonDecode(menuBody) as List).first;

    cart.add(MenuItem.fromJson(burgerJson));
    cart.add(MenuItem.fromJson(burgerJson));

    expect(cart.lines, hasLength(1));
    expect(cart.lines.values.single, 2);
  });
}
