import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/models/menu_item.dart';
import 'package:food_orders/shared/models/order.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const burgerJson = {
  'id': 'burger',
  'name': 'Classic Burger',
  'description': 'Beef patty',
  'price': 9.5,
};

void main() {
  group('MenuItem.fromJson', () {
    test('parses a valid item', () {
      final item = MenuItem.fromJson(burgerJson);

      expect(item.id, 'burger');
      expect(item.name, 'Classic Burger');
      expect(item.description, 'Beef patty');
      expect(item.price, 9.5);
    });

    test('accepts a whole-number price and stores it as a double', () {
      final item = MenuItem.fromJson({...burgerJson, 'price': 12});

      expect(item.price, isA<double>());
      expect(item.price, 12.0);
    });

    test('makes name and description safe to display', () {
      final item = MenuItem.fromJson({
        ...burgerJson,
        'name': 'Burger\n\$0.01',
        'description': '\u202Eevil\u202C zero\u200Bwidth\tand\r\ntabs ',
      });

      expect(item.name, 'Burger \$0.01');
      expect(item.description, 'evil zerowidth and tabs');
    });

    test('Unicode line and paragraph separators become spaces', () {
      final item = MenuItem.fromJson({
        ...burgerJson,
        'name': 'Burger\u2028\$0.01',
        'description': 'a\u2029b\u0085c',
      });

      expect(item.name, 'Burger \$0.01');
      expect(item.description, 'a b c');
    });

    test('keeps zero-width joiners so emoji stay intact', () {
      const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';
      final item = MenuItem.fromJson({...burgerJson, 'name': 'Family $family'});

      expect(item.name, 'Family $family');
    });

    test('rejects a name with no visible text after cleanup', () {
      expect(
        () => MenuItem.fromJson({...burgerJson, 'name': '\u202E\u200B\n '}),
        throwsFormatException,
      );
    });

    for (final (label, json) in [
      ('a non-object', <Object?>['burger']),
      ('a missing id', {...burgerJson}..remove('id')),
      ('an empty id', {...burgerJson, 'id': ''}),
      ('a null name', {...burgerJson, 'name': null}),
      ('a missing description', {...burgerJson}..remove('description')),
      ('a string price', {...burgerJson, 'price': '9.5'}),
      ('a negative price', {...burgerJson, 'price': -1}),
      ('an infinite price', {...burgerJson, 'price': double.infinity}),
    ]) {
      test('rejects $label with a FormatException', () {
        expect(() => MenuItem.fromJson(json), throwsFormatException);
      });
    }
  });

  group('MenuItem equality', () {
    test('items with the same id are equal and share a hash code', () {
      final a = MenuItem.fromJson(burgerJson);
      final b = MenuItem.fromJson({...burgerJson, 'price': 10.5});

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('items with different ids are not equal', () {
      final a = MenuItem.fromJson(burgerJson);
      final b = MenuItem.fromJson({...burgerJson, 'id': 'pizza'});

      expect(a, isNot(b));
    });

    test('two separately parsed copies are one Map key', () {
      final counts = <MenuItem, int>{};
      counts[MenuItem.fromJson(burgerJson)] = 1;
      counts[MenuItem.fromJson(burgerJson)] = 2;

      expect(counts, hasLength(1));
      expect(counts.values.single, 2);
    });
  });

  group('OrderApiClient.fetchMenu', () {
    OrderApiClient clientReturning(String body, {int status = 200}) {
      return OrderApiClient(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/menu');
          return http.Response(body, status);
        }),
      );
    }

    test('returns the parsed items in order', () async {
      final api = clientReturning(
        jsonEncode([
          burgerJson,
          {...burgerJson, 'id': 'pizza', 'name': 'Pizza'},
        ]),
      );

      final menu = await api.fetchMenu();

      expect(menu.map((i) => i.id), ['burger', 'pizza']);
    });

    test('throws a ClientException on a non-200 status', () async {
      final api = clientReturning('Route not found', status: 404);

      expect(api.fetchMenu(), throwsA(isA<http.ClientException>()));
    });

    test('throws a FormatException on invalid JSON', () async {
      final api = clientReturning('{not json');

      expect(api.fetchMenu(), throwsFormatException);
    });

    test('throws a FormatException when the body is not a list', () async {
      final api = clientReturning(jsonEncode(burgerJson));

      expect(api.fetchMenu(), throwsFormatException);
    });

    test('throws a FormatException on duplicate ids', () async {
      final api = clientReturning(jsonEncode([burgerJson, burgerJson]));

      expect(api.fetchMenu(), throwsFormatException);
    });

    test('throws a FormatException on a malformed element', () async {
      final api = clientReturning(
        jsonEncode([
          burgerJson,
          {...burgerJson, 'id': 'bad', 'price': 'free'},
        ]),
      );

      expect(api.fetchMenu(), throwsFormatException);
    });
  });

  group('existing order calls go through the injected client', () {
    test('fetchOrders and updateStatus use it', () async {
      final requests = <String>[];
      final order = {
        'id': '1',
        'customerName': 'Alice',
        'items': [
          {'name': 'Pho', 'quantity': 1, 'price': 9.5},
        ],
        'status': 'ready',
        'placedAt': '2026-11-10T12:00:00.000',
      };
      final api = OrderApiClient(
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          final body = request.method == 'GET' ? [order] : order;
          return http.Response(jsonEncode(body), 200);
        }),
      );

      final orders = await api.fetchOrders();
      final updated = await api.updateStatus('1', OrderStatus.ready);

      expect(orders.single.id, '1');
      expect(updated.status, OrderStatus.ready);
      expect(requests, ['GET /api/orders', 'PATCH /api/orders/1']);
    });
  });
}
