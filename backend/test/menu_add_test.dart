import 'dart:convert';

import 'package:food_orders_backend/database.dart';
import 'package:food_orders_backend/menu_api.dart';
import 'package:food_orders_backend/staff_gate.dart';
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

// Fake credentials, for these tests only.
const staffId = 'test-staff';
const password = 'staff-password-for-tests-1234';

Map<String, String> creds([String? pw = password]) =>
    pw == null ? const {} : {staffIdHeader: staffId, staffPasswordHeader: pw};

void main() {
  late Database db;
  late Handler staff;

  setUp(() {
    db = openDatabase(':memory:');
    staff = MenuApi(
      db,
      staffGate: StaffGate(id: staffId, password: password),
    ).handler;
  });

  tearDown(() => db.close());

  Future<Response> post(
    Handler h, {
    Object? body,
    String? rawBody,
    Stream<List<int>>? stream,
    String? pw = password,
  }) => Future.sync(
    () => h(
      Request(
        'POST',
        Uri.parse('http://localhost/menu'),
        headers: creds(pw),
        body: stream ?? rawBody ?? (body == null ? null : jsonEncode(body)),
      ),
    ),
  );

  int count() =>
      db.select('SELECT count(*) AS n FROM menu_items').first['n'] as int;

  Map<String, Object?> valid([Map<String, Object?> extra = const {}]) => {
    'name': 'Xôi lá cẩm',
    'price': 30000,
    'category': 'food',
    ...extra,
  };

  Future<Map<String, dynamic>> json(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  group('success', () {
    test('201 with the full item shape and no-store', () async {
      final before = count();
      final r = await post(
        staff,
        body: valid({
          'description': 'Xôi màu tím',
          'allowToppings': true,
          'image': 'xoi-la-cam.webp',
        }),
      );
      expect(r.statusCode, 201);
      expect(r.headers['cache-control'], 'no-store');
      expect(r.headers['content-type'], startsWith('application/json'));
      expect(await json(r), {
        'id': 'xoi-la-cam',
        'name': 'Xôi lá cẩm',
        'description': 'Xôi màu tím',
        'price': 30000,
        'category': 'food',
        'allowToppings': true,
        'image': 'xoi-la-cam.webp',
        'available': true,
      });
      expect(count(), before + 1);
    });

    test('defaults, and the new item is last in GET /menu', () async {
      final r = await post(staff, body: valid());
      final item = await json(r);
      expect(item['description'], '');
      expect(item['allowToppings'], false);
      expect(item['image'], isNull);
      expect(item['available'], true);

      final menu = await Future.sync(
        () => staff(Request('GET', Uri.parse('http://localhost/menu'))),
      );
      final list = jsonDecode(await menu.readAsString()) as List;
      expect((list.last as Map)['id'], item['id']);
    });

    test('name is trimmed and stored as text', () async {
      final r = await post(staff, body: valid({'name': '  Xôi vò  '}));
      expect((await json(r))['name'], 'Xôi vò');
    });

    test('price 25000 and 25000.0 both store 25000', () async {
      for (final (i, p) in ['25000', '25000.0'].indexed) {
        final r = await post(
          staff,
          rawBody: '{"name":"Item $i","price":$p,"category":"drink"}',
        );
        expect(r.statusCode, 201);
        final row = db.select(
          'SELECT price, typeof(price) AS t FROM menu_items WHERE name = ?',
          ['Item $i'],
        ).single;
        expect(row['price'], 25000);
      }
    });

    test('price 0 and the maximum are fine', () async {
      expect((await post(staff, body: valid({'price': 0}))).statusCode, 201);
      expect(
        (await post(
          staff,
          body: valid({'name': 'Other', 'price': maxMenuPrice}),
        )).statusCode,
        201,
      );
    });

    test('allowToppings true is accepted for food only', () async {
      expect(
        (await post(staff, body: valid({'allowToppings': true}))).statusCode,
        201,
      );
      for (final category in ['snack', 'drink', 'nibble']) {
        final before = count();
        final r = await post(
          staff,
          body: valid({'category': category, 'allowToppings': true}),
        );
        expect(r.statusCode, 400, reason: category);
        expect(count(), before);
        // false is fine for them.
        expect(
          (await post(
            staff,
            body: valid({'category': category, 'allowToppings': false}),
          )).statusCode,
          201,
        );
      }
    });

    test('SQL-looking names are plain text and the table survives', () async {
      const evil = "'); DROP TABLE menu_items;--";
      final before = count();
      final r = await post(
        staff,
        body: valid({'name': evil, 'description': evil}),
      );
      expect(r.statusCode, 201);
      final item = await json(r);
      expect(item['name'], evil);
      expect(item['id'], 'drop-table-menu-items');
      expect(count(), before + 1);
    });
  });

  group('400', () {
    final bad = <String, Object?>{
      'empty object': <String, Object?>{},
      'JSON array': [1],
      'JSON string': '"x"',
      'unknown key id': valid({'id': 'x'}),
      'unknown key available': valid({'available': false}),
      'unknown key paymentDueAt': valid({'paymentDueAt': 'x'}),
      'missing name': {'price': 1, 'category': 'food'},
      'missing price': {'name': 'x', 'category': 'food'},
      'missing category': {'name': 'x', 'price': 1},
      'name null': valid({'name': null}),
      'name number': valid({'name': 5}),
      'empty name': valid({'name': ''}),
      'whitespace name': valid({'name': '   '}),
      'name 101 units': valid({'name': 'a' * 101}),
      'name 51 emoji (102 units)': valid({'name': '🍜' * 51}),
      'name control char': valid({'name': 'a\u0007b'}),
      'name newline': valid({'name': 'a\nb'}),
      'description too long': valid({'description': 'a' * 501}),
      'description emoji over': valid({'description': '🍜' * 251}),
      'description control': valid({'description': 'a\u0000b'}),
      'description number': valid({'description': 5}),
      'description null': valid({'description': null}),
      'price negative': valid({'price': -1}),
      'price fraction': valid({'price': 10.5}),
      'price too big': valid({'price': maxMenuPrice + 1}),
      'price string': valid({'price': '5'}),
      'price null': valid({'price': null}),
      'price huge': valid({'price': 1e30}),
      'unknown category': valid({'category': 'soup'}),
      'category capital': valid({'category': 'Food'}),
      'category number': valid({'category': 1}),
      'allowToppings string': valid({'allowToppings': 'yes'}),
      'allowToppings null': valid({'allowToppings': null}),
      'image slash': valid({'image': 'a/b.png'}),
      'image dotdot': valid({'image': '../x.png'}),
      'image capitals': valid({'image': 'Xoi.png'}),
      'image gif': valid({'image': 'xoi.gif'}),
      'image url': valid({'image': 'http://evil.example/x.png'}),
      'image number': valid({'image': 5}),
      'image empty': valid({'image': ''}),
    };
    bad.forEach((label, body) {
      test(label, () async {
        final before = count();
        final r = await post(staff, body: body);
        expect(r.statusCode, 400);
        expect(count(), before);
      });
    });

    for (final (label, raw) in [
      ('not JSON', 'hello'),
      ('empty body', ''),
      ('infinity price', '{"name":"x","price":1e999,"category":"food"}'),
      ('truncated', '{"name":'),
    ]) {
      test(label, () async {
        final before = count();
        final r = await post(staff, rawBody: raw);
        expect(r.statusCode, 400);
        expect(count(), before);
      });
    }

    test('error text never echoes the request', () async {
      final r = await post(staff, body: valid({'name': 'SECRET-NAME\u0007'}));
      expect(r.statusCode, 400);
      expect(await r.readAsString(), isNot(contains('SECRET')));
    });

    test('a 100-unit name and a 50-emoji name are accepted', () async {
      expect(
        (await post(staff, body: valid({'name': 'a' * 100}))).statusCode,
        201,
      );
      expect(
        (await post(staff, body: valid({'name': '🍜' * 50}))).statusCode,
        201,
      );
    });

    test('description with newline and 500 units is accepted', () async {
      final r = await post(
        staff,
        body: valid({'description': '${'a' * 249}\n${'b' * 250}'}),
      );
      expect(r.statusCode, 201);
    });
  });

  group('staff gate', () {
    test('wrong password -> 401, nothing inserted', () async {
      final before = count();
      final r = await post(staff, body: valid(), pw: 'wrong-password-123');
      expect(r.statusCode, 401);
      expect(count(), before);
    });

    test('missing headers -> 401', () async {
      final before = count();
      final r = await post(staff, body: valid(), pw: null);
      expect(r.statusCode, 401);
      expect(count(), before);
    });

    test('gate disabled -> 403 (default and unusable credentials)', () async {
      for (final h in [
        MenuApi(db).handler,
        MenuApi(
          db,
          staffGate: StaffGate(id: staffId, password: 'short'),
        ).handler,
      ]) {
        final before = count();
        final r = await post(h, body: valid());
        expect(r.statusCode, 403);
        expect(count(), before);
      }
    });

    test('429 after repeated wrong tries, even with the right one', () async {
      for (var i = 0; i < maxStaffFailures; i++) {
        expect(
          (await post(
            staff,
            body: valid(),
            pw: 'wrong-$i-xxxxxxxx',
          )).statusCode,
          401,
        );
      }
      final before = count();
      final r = await post(staff, body: valid());
      expect(r.statusCode, 429);
      expect(r.headers['retry-after'], isNotNull);
      expect(count(), before);
    });

    test('the body is not read when the gate refuses', () async {
      var read = false;
      final stream = () async* {
        read = true;
        yield utf8.encode('{}');
      }();
      final r = await post(staff, stream: stream, pw: 'wrong-password-123');
      expect(r.statusCode, 401);
      expect(read, isFalse);
      // A huge declared body with a wrong password is still 401, not 413.
      final big = await post(
        staff,
        rawBody: 'x' * (maxMenuEditBytes + 10),
        pw: 'wrong-password-123',
      );
      expect(big.statusCode, 401);
    });

    test('no secret in any reply', () async {
      final r = await post(staff, body: valid(), pw: 'wrong-password-123');
      final text = await r.readAsString();
      expect(text, isNot(contains(password)));
      expect(text, isNot(contains(staffId)));
    });
  });

  group('413', () {
    test('declared length over 4 KB', () async {
      final before = count();
      final r = await post(
        staff,
        rawBody: jsonEncode(valid({'description': 'a' * 5000})),
      );
      expect(r.statusCode, 413);
      expect(count(), before);
    });

    test('chunked body over 4 KB (no declared length)', () async {
      final before = count();
      final chunks = Stream.fromIterable([
        utf8.encode('{"name":"x","description":"'),
        for (var i = 0; i < 6; i++) utf8.encode('a' * 1000),
        utf8.encode('"}'),
      ]);
      final r = await Future.sync(
        () => staff(
          Request(
            'POST',
            Uri.parse('http://localhost/menu'),
            headers: creds(),
            body: chunks,
            context: const {},
          ),
        ),
      );
      expect(r.statusCode, 413);
      expect(count(), before);
    });
  });

  group('409 and ids', () {
    test('duplicate in the same category, ignoring case and accents', () async {
      expect((await post(staff, body: valid())).statusCode, 201);
      final before = count();
      for (final name in [
        'Xôi lá cẩm',
        'XÔI LÁ CẨM',
        'xoi la cam',
        ' xoi LA cam ',
      ]) {
        final r = await post(staff, body: valid({'name': name}));
        expect(r.statusCode, 409, reason: name);
      }
      expect(count(), before);
    });

    test('duplicate of a seeded item', () async {
      final seeded = db
          .select("SELECT name, category FROM menu_items WHERE id = 'xoi-thit'")
          .single;
      final r = await post(
        staff,
        body: valid({
          'name': (seeded['name'] as String).toUpperCase(),
          'category': seeded['category'],
        }),
      );
      expect(r.statusCode, 409);
    });

    test('same name in another category is allowed, with a suffix', () async {
      final a = await json(await post(staff, body: valid({'name': 'Xoi'})));
      final b = await json(
        await post(staff, body: valid({'name': 'Xoi', 'category': 'snack'})),
      );
      final c = await json(
        await post(staff, body: valid({'name': 'Xoi', 'category': 'drink'})),
      );
      expect([a['id'], b['id'], c['id']], ['xoi', 'xoi-2', 'xoi-3']);
    });

    test('id clash with a hand-inserted row gets the next suffix', () async {
      db.execute(
        "INSERT INTO menu_items (id, name, price, category) "
        "VALUES ('banh-mi', 'Something else', 1, 'food')",
      );
      db.execute(
        "INSERT INTO menu_items (id, name, price, category) "
        "VALUES ('banh-mi-2', 'Another', 1, 'food')",
      );
      final item = await json(
        await post(staff, body: valid({'name': 'Bánh mì'})),
      );
      expect(item['id'], 'banh-mi-3');
    });

    test('a symbols-only name gets the id item, then item-2', () async {
      final a = await json(await post(staff, body: valid({'name': '🍜'})));
      final b = await json(await post(staff, body: valid({'name': '🍕'})));
      expect([a['id'], b['id']], ['item', 'item-2']);
    });
  });

  group('503 at the cap', () {
    test('menu full -> 503 "Menu is full", nothing inserted', () async {
      final n = count();
      db.execute('BEGIN');
      for (var i = n; i < maxMenuItems; i++) {
        db.execute(
          "INSERT INTO menu_items (id, name, price, category) "
          "VALUES (?, ?, 1, 'food')",
          ['seed-$i', 'Seed $i'],
        );
      }
      db.execute('COMMIT');
      expect(count(), maxMenuItems);

      final r = await post(staff, body: valid());
      expect(r.statusCode, 503);
      expect(await r.readAsString(), 'Menu is full');
      expect(count(), maxMenuItems);
    });

    test('one below the cap still works', () async {
      final n = count();
      db.execute('BEGIN');
      for (var i = n; i < maxMenuItems - 1; i++) {
        db.execute(
          "INSERT INTO menu_items (id, name, price, category) "
          "VALUES (?, ?, 1, 'food')",
          ['seed-$i', 'Seed $i'],
        );
      }
      db.execute('COMMIT');
      expect((await post(staff, body: valid())).statusCode, 201);
      expect(count(), maxMenuItems);
    });
  });

  test('a rolled-back request leaves no open transaction', () async {
    // 409 path rolls back; a following request must be able to BEGIN again.
    await post(staff, body: valid());
    expect((await post(staff, body: valid())).statusCode, 409);
    expect((await post(staff, body: valid({'name': 'Other'}))).statusCode, 201);
  });
}
