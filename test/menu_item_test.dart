import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/models/menu_item.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// One `GET /menu` item in the shape the backend sends today.
Map<String, Object?> item(String id, String category, bool allowToppings) => {
  'id': id,
  'name': 'Item $id',
  'description': '',
  'price': 25000.0,
  'category': category,
  'allowToppings': allowToppings,
};

/// The same item as an older backend sent it: no category, no toppings flag.
Map<String, Object?> oldItem(String id) => {
  'id': id,
  'name': 'Item $id',
  'description': '',
  'price': 25000.0,
};

void main() {
  group('category', () {
    for (final category in MenuCategory.values) {
      test('"${category.name}" parses', () {
        final parsed = MenuItem.fromJson(item('x', category.name, false));

        expect(parsed.category, category);
      });
    }

    test('missing means food (older backend)', () {
      expect(MenuItem.fromJson(oldItem('x')).category, MenuCategory.food);
    });

    for (final (label, value) in [
      ('"cake"', 'cake'),
      ('an empty string', ''),
      ('a number', 7),
      ('null', null),
      ('upper case "FOOD"', 'FOOD'),
    ]) {
      test('$label is rejected', () {
        final json = {...item('x', 'food', true), 'category': value};

        expect(() => MenuItem.fromJson(json), throwsFormatException);
      });
    }
  });

  group('allowToppings', () {
    test('true and false parse', () {
      expect(MenuItem.fromJson(item('x', 'food', true)).allowToppings, isTrue);
      expect(
        MenuItem.fromJson(item('x', 'food', false)).allowToppings,
        isFalse,
      );
    });

    test('missing is true for food', () {
      final json = item('x', 'food', true)..remove('allowToppings');

      expect(MenuItem.fromJson(json).allowToppings, isTrue);
    });

    for (final category in ['snack', 'drink', 'nibble']) {
      test('missing is false for $category', () {
        final json = item('x', category, false)..remove('allowToppings');

        expect(MenuItem.fromJson(json).allowToppings, isFalse);
      });
    }

    test('missing in an old item (no category either) is true, as food', () {
      expect(MenuItem.fromJson(oldItem('x')).allowToppings, isTrue);
    });

    for (final (label, value) in [('"yes"', 'yes'), ('1', 1), ('null', null)]) {
      test('$label is rejected', () {
        final json = {...item('x', 'food', true), 'allowToppings': value};

        expect(() => MenuItem.fromJson(json), throwsFormatException);
      });
    }
  });

  for (final category in ['snack', 'drink', 'nibble']) {
    test('a server "true" for $category is ignored: never toppings', () {
      final parsed = MenuItem.fromJson(item('x', category, true));

      expect(parsed.allowToppings, isFalse);
    });
  }

  test('equality is still by id only', () {
    final a = MenuItem.fromJson(item('x', 'food', true));
    final b = MenuItem.fromJson(item('x', 'drink', false));

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('the const constructor defaults to food with toppings', () {
    const plain = MenuItem(id: 'x', name: 'X', description: '', price: 1);

    expect(plain.category, MenuCategory.food);
    expect(plain.allowToppings, isTrue);
  });

  test(
    'a whole GET /menu reply with all four categories keeps its order',
    () async {
      final api = OrderApiClient(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode([
                item('xoi-thit', 'food', true),
                item('tra-da', 'drink', false),
                item('trung-ngai-cuu', 'snack', false),
                item('khoai-lang-nuong', 'nibble', false),
              ]),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      final menu = await api.fetchMenu();

      expect(menu.map((i) => i.id), [
        'xoi-thit',
        'tra-da',
        'trung-ngai-cuu',
        'khoai-lang-nuong',
      ]);
      expect(menu.map((i) => i.category), [
        MenuCategory.food,
        MenuCategory.drink,
        MenuCategory.snack,
        MenuCategory.nibble,
      ]);
    },
  );

  test('one bad category fails the whole menu load (TAB4: strict)', () async {
    final api = OrderApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode([
            item('xoi-thit', 'food', true),
            item('x', 'cake', false),
          ]),
          200,
        ),
      ),
    );

    expect(api.fetchMenu(), throwsFormatException);
  });

  group('image', () {
    MenuItem withImage(Object? image) =>
        MenuItem.fromJson({...item('x', 'food', true), 'image': image});

    test('missing (older backend) means no picture', () {
      expect(MenuItem.fromJson(item('x', 'food', true)).image, isNull);
    });

    test('null means no picture', () {
      expect(withImage(null).image, isNull);
    });

    for (final name in ['xoi-thit.jpg', 'a.jpeg', 'tra-da-2.png', '9.webp']) {
      test('"$name" is kept', () => expect(withImage(name).image, name));
    }

    for (final bad in <Object>[
      42,
      ['x.png'],
      '',
      '../x.png',
      'http://evil.example/x.png',
      '//evil.example/x.png',
      'a/b.png',
      'Burger.PNG',
      'x.gif',
      'x.svg',
      '.hidden.png',
      'a..b.png',
      'x.png\n',
      '${'a' * 100}.png',
    ]) {
      test('${jsonEncode(bad)} is refused', () {
        expect(
          () => withImage(bad),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('image'),
            ),
          ),
        );
      });
    }

    test('equality is still by id only', () {
      expect(withImage('a.png'), withImage('b.png'));
      expect(withImage('a.png').hashCode, withImage(null).hashCode);
    });

    test('the const constructor has no picture', () {
      const plain = MenuItem(id: 'x', name: 'X', description: '', price: 1);
      expect(plain.image, isNull);
    });
  });

  group('OrderApiClient.imageUrlFor', () {
    MenuItem itemWith(String? image) =>
        MenuItem(id: 'x', name: 'X', description: '', price: 1, image: image);

    test('builds the relative /api/images URL', () {
      expect(
        OrderApiClient.imageUrlFor(itemWith('burger.webp')),
        '/api/images/burger.webp',
      );
    });

    test('null when the item has no picture', () {
      expect(OrderApiClient.imageUrlFor(itemWith(null)), isNull);
    });

    for (final bad in [
      '../orders.db',
      'http://evil.example/x.png',
      'a/b.png',
    ]) {
      test('null for a name built in code that breaks the rule: $bad', () {
        expect(OrderApiClient.imageUrlFor(itemWith(bad)), isNull);
      });
    }
  });

  group('fetchMenu with pictures', () {
    OrderApiClient answering(List<Object?> body) => OrderApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode(body)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    test('a mix of items with and without a picture loads', () async {
      final menu = await answering([
        {...item('xoi-thit', 'food', true), 'image': 'xoi-thit.webp'},
        {...item('tra-da', 'drink', false), 'image': null},
      ]).fetchMenu();

      expect(menu.map((i) => i.image), ['xoi-thit.webp', null]);
    });

    test('one bad picture name fails the whole load', () async {
      await expectLater(
        answering([
          {...item('xoi-thit', 'food', true), 'image': 'xoi-thit.webp'},
          {...item('tra-da', 'drink', false), 'image': '../orders.db'},
        ]).fetchMenu(),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('available (sold out)', () {
    MenuItem withAvailable(Object? value) =>
        MenuItem.fromJson({...item('x', 'food', true), 'available': value});

    test('true and false are kept', () {
      expect(withAvailable(true).available, isTrue);
      expect(withAvailable(false).available, isFalse);
    });

    test('missing (older backend) means available', () {
      expect(MenuItem.fromJson(item('x', 'food', true)).available, isTrue);
    });

    for (final bad in <Object?>['false', 0, 1, null]) {
      test('${jsonEncode(bad)} is refused with a clear error', () {
        expect(
          () => withAvailable(bad),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('available'),
            ),
          ),
        );
      });
    }

    test('the const constructor is available; equality is still by id', () {
      const plain = MenuItem(id: 'x', name: 'X', description: '', price: 1);
      expect(plain.available, isTrue);
      expect(withAvailable(false), withAvailable(true));
    });
  });
}
