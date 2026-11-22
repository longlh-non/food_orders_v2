import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/models/order.dart';
import 'package:food_orders/shared/models/topping.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const chaJson = {'id': 'cha', 'name': 'Thêm chả', 'price': 10000.0};

http.Response utf8Json(Object body, {int status = 200}) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('Topping.fromJson', () {
    test('parses a valid topping', () {
      final t = Topping.fromJson(chaJson);

      expect(t.id, 'cha');
      expect(t.name, 'Thêm chả');
      expect(t.price, 10000.0);
    });

    test('cleans the name like menu names', () {
      final t = Topping.fromJson({...chaJson, 'name': 'Thêm\nchả\u202E'});

      expect(t.name, 'Thêm chả');
    });

    for (final (label, json) in <(String, Object?)>[
      ('a non-object', 'cha'),
      ('an empty id', {...chaJson, 'id': ''}),
      ('a numeric id', {...chaJson, 'id': 1}),
      ('a numeric name', {...chaJson, 'name': 5}),
      ('an invisible-only name', {...chaJson, 'name': '\u200B\n '}),
      ('a negative price', {...chaJson, 'price': -1}),
      ('an infinite price', {...chaJson, 'price': double.infinity}),
      ('a string price', {...chaJson, 'price': '10000'}),
    ]) {
      test('rejects $label', () {
        expect(() => Topping.fromJson(json), throwsFormatException);
      });
    }

    test('is equal by id', () {
      expect(
        Topping.fromJson(chaJson),
        Topping.fromJson({...chaJson, 'price': 11000.0}),
      );
    });
  });

  group('OrderItem with toppings', () {
    OrderItem withToppings() => OrderItem(
      menuItemId: 'xoi-thit',
      name: 'Xôi thịt',
      quantity: 2,
      price: 25000,
      toppings: const [
        OrderTopping(id: 'cha', name: 'Thêm chả', price: 10000),
        OrderTopping(id: 'trung-trang', name: 'Thêm trứng tráng', price: 8000),
      ],
    );

    test('a plain item serialises exactly as before toppings existed', () {
      final plain = OrderItem(name: 'Trà đá', quantity: 1, price: 4000);

      expect(plain.toJson(), {'name': 'Trà đá', 'quantity': 1, 'price': 4000});
    });

    test('writes id and toppings when set', () {
      expect(withToppings().toJson(), {
        'id': 'xoi-thit',
        'name': 'Xôi thịt',
        'quantity': 2,
        'price': 25000,
        'toppings': [
          {'id': 'cha', 'name': 'Thêm chả', 'price': 10000},
          {'id': 'trung-trang', 'name': 'Thêm trứng tráng', 'price': 8000},
        ],
      });
    });

    test('omits a topping id when it is null', () {
      const t = OrderTopping(name: 'Thêm chả', price: 10000);

      expect(t.toJson(), {'name': 'Thêm chả', 'price': 10000});
    });

    test('round-trips through JSON, keeping the ids', () {
      final back = OrderItem.fromJson(
        jsonDecode(jsonEncode(withToppings().toJson())) as Map<String, dynamic>,
      );

      expect(back.menuItemId, 'xoi-thit');
      expect(back.toppings.map((t) => t.id), ['cha', 'trung-trang']);
      expect(back.toppings.map((t) => t.price), [10000, 8000]);
      expect(back.toJson(), withToppings().toJson());
    });

    test('an old order line (no id, no toppings) still parses', () {
      final old = OrderItem.fromJson({
        'name': 'Xôi thịt',
        'quantity': 1,
        'price': 25000,
      });

      expect(old.menuItemId, isNull);
      expect(old.toppings, isEmpty);
    });

    for (final (label, json) in <(String, Map<String, dynamic>)>[
      ('an empty item id', {'id': '', 'name': 'X', 'quantity': 1, 'price': 1}),
      ('a numeric item id', {'id': 3, 'name': 'X', 'quantity': 1, 'price': 1}),
      (
        'toppings that are not a list',
        {'name': 'X', 'quantity': 1, 'price': 1, 'toppings': 'chả'},
      ),
      (
        'a topping that is not an object',
        {
          'name': 'X',
          'quantity': 1,
          'price': 1,
          'toppings': ['chả'],
        },
      ),
      (
        'an empty topping id',
        {
          'name': 'X',
          'quantity': 1,
          'price': 1,
          'toppings': [
            {'id': '', 'name': 'Chả', 'price': 1},
          ],
        },
      ),
      (
        'a topping with an infinite price',
        {
          'name': 'X',
          'quantity': 1,
          'price': 1,
          'toppings': [
            {'name': 'Chả', 'price': double.infinity},
          ],
        },
      ),
    ]) {
      test('rejects $label', () {
        expect(() => OrderItem.fromJson(json), throwsFormatException);
      });
    }

    test('unit price and subtotal include the toppings', () {
      final item = withToppings();

      expect(item.unitPrice, closeTo(43000, 0.001));
      expect(item.subtotal, closeTo(86000, 0.001));
    });

    test('Order.total adds lines with toppings', () {
      final order = Order(
        id: '1',
        customerName: 'Bao',
        items: [
          withToppings(),
          OrderItem(
            menuItemId: 'tra-da',
            name: 'Trà đá',
            quantity: 1,
            price: 4000,
          ),
        ],
        status: OrderStatus.preparing,
        placedAt: DateTime(2026, 11, 12),
      );

      expect(order.total, closeTo(90000, 0.001));
    });
  });

  group('OrderApiClient.fetchToppings', () {
    OrderApiClient replying(http.Response response) => OrderApiClient(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/toppings');
        return response;
      }),
    );

    test('returns the toppings in order', () async {
      final api = replying(
        utf8Json([
          chaJson,
          {'id': 'thit', 'name': 'Thêm thịt', 'price': 10000.0},
        ]),
      );

      final toppings = await api.fetchToppings();

      expect(toppings.map((t) => t.id), ['cha', 'thit']);
      expect(toppings.first.name, 'Thêm chả');
    });

    test('throws a ClientException on a non-200 status', () {
      final api = replying(http.Response('down', 502));

      expect(api.fetchToppings(), throwsA(isA<http.ClientException>()));
    });

    test('throws a FormatException when the body is not a list', () {
      final api = replying(utf8Json(chaJson));

      expect(api.fetchToppings(), throwsFormatException);
    });

    test('throws a FormatException on a bad element', () {
      final api = replying(
        utf8Json([
          chaJson,
          {'id': 'x', 'name': 'X', 'price': 'free'},
        ]),
      );

      expect(api.fetchToppings(), throwsFormatException);
    });

    test('throws a FormatException on duplicate ids', () {
      final api = replying(utf8Json([chaJson, chaJson]));

      expect(api.fetchToppings(), throwsFormatException);
    });
  });
}
