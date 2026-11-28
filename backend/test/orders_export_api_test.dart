import 'dart:convert';
import 'dart:io';

import 'package:food_orders_backend/database.dart';
import 'package:food_orders_backend/orders_api.dart';
import 'package:food_orders_backend/shop_settings.dart';
import 'package:food_orders_backend/staff_gate.dart';
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'xlsx_test_reader.dart';

const _xlsxType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

// Obviously fake shop details; never real data.
final _shopEnv = <String, String?>{
  'SHOP_NAME': 'QUAN THU NGHIEM',
  'SHOP_TAX_CODE': '0000000000-999',
  'SHOP_ADDRESS': '99 Duong Gia Dinh',
  'SHOP_LOCATION': '100 Duong Demo',
  'SHOP_REPRESENTATIVE': 'Nguyen Van Mau',
};

/// A stand-in for `stderr` that keeps what is written to it.
class _CapturedStderr implements Stdout {
  final lines = <String>[];
  @override
  void writeln([Object? object = '']) => lines.add('$object');
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const token = 'staff-token-for-tests-1234';

Map<String, dynamic> order(
  String id,
  String placedAt, {
  String customer = 'Nguyễn Văn An',
  Object price = 25000,
}) => {
  'id': id,
  'customerName': customer,
  'items': [
    {'name': 'Xôi thịt', 'quantity': 2, 'price': price},
  ],
  'status': 'finished',
  'placedAt': placedAt,
};

void main() {
  late Database db;
  late OrdersApi api;

  void store(Map<String, dynamic> o) => db.execute(
    'INSERT INTO orders (id, customer_name, status, placed_at, items_json) '
    'VALUES (?, ?, ?, ?, ?)',
    [
      o['id'],
      o['customerName'],
      o['status'],
      o['placedAt'],
      jsonEncode(o['items']),
    ],
  );

  setUp(() {
    db = openDatabase(':memory:');
    api = OrdersApi(
      db,
      staffGate: StaffGate(id: testStaffId, password: token),
    );
    store(order('oct', '2026-10-31T23:59:00.000', customer: 'Tháng Mười'));
    store(order('nov-2', '2026-11-20T09:00:00.000', customer: 'Trần Thị Bích'));
    store(order('nov-1', '2026-11-02T08:30:00.000'));
    store(order('dec', '2026-12-01T00:00:00.000', customer: 'Tháng Mười Hai'));
  });

  tearDown(() async {
    await api.close();
    db.close();
  });

  Future<Response> export(String query, {String? sent = token}) => Future.sync(
    () => api.handler(
      Request(
        'GET',
        Uri.parse('http://localhost/orders/export$query'),
        headers: staffCreds(sent),
      ),
    ),
  );

  Future<String> text(Response r) async =>
      utf8.decode(await r.read().expand((c) => c).toList());

  test(
    'a month with orders: only that month, exact headers, BOM, UTF-8',
    () async {
      final response = await export('?month=2026-11');

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'text/csv; charset=utf-8');
      expect(
        response.headers['content-disposition'],
        'attachment; filename="orders-2026-11.csv"',
      );
      expect(response.headers['cache-control'], 'no-store');
      final bytes = await response.read().expand((c) => c).toList();
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      final body = utf8.decode(bytes.skip(3).toList());
      expect(body, contains('Nguyễn Văn An'));
      expect(body, contains('Trần Thị Bích'));
      expect(body, isNot(contains('Tháng Mười')));
      // Oldest first: the 2nd of November before the 20th.
      expect(body.indexOf('nov-1'), lessThan(body.indexOf('nov-2')));
    },
  );

  test('an empty month: 200 with only the header', () async {
    final response = await export('?month=2027-01');
    expect(response.statusCode, 200);
    final lines = (await text(response))
        .split('\r\n')
        .where((l) => l.isNotEmpty)
        .toList();
    expect(lines, hasLength(2), reason: 'sep=; line and the header');
  });

  for (final query in [
    '',
    '?month=',
    '?month=2026-13',
    '?month=2026-1',
    '?month=..%2Fx',
    '?month=2026-11%2F..%2F..%2Fx',
    '?month=${'9' * 500}',
    '?month=%zz',
    '?month=2026-11&month=2026-12x',
  ]) {
    test('month "$query" -> 400, no file name, no data', () async {
      final response = await export(query);
      expect(response.statusCode, 400);
      expect(response.headers['content-disposition'], isNull);
      expect(await text(response), isNot(contains('An')));
    });
  }

  for (final (label, sent, gate, status) in [
    ('no token', null, StaffGate(id: testStaffId, password: token), 401),
    (
      'wrong token',
      'wrong-token-but-long-1234',
      StaffGate(id: testStaffId, password: token),
      401,
    ),
    ('gate disabled', token, StaffGate(), 403),
  ]) {
    test('$label -> $status, no customer data', () async {
      final gated = OrdersApi(db, staffGate: gate);
      addTearDown(gated.close);
      final response = await Future.sync(
        () => gated.handler(
          Request(
            'GET',
            Uri.parse('http://localhost/orders/export?month=2026-11'),
            headers: staffCreds(sent),
          ),
        ),
      );
      expect(response.statusCode, status);
      final body = await text(response);
      expect(body, isNot(contains('Nguyễn')));
      expect(body, isNot(contains(token)));
    });
  }

  test('the token is checked before the month', () async {
    final response = await export('?month=nonsense', sent: null);
    expect(response.statusCode, 401);
  });

  test('without a staff gate at all the export is off (403)', () async {
    final plain = OrdersApi(db);
    addTearDown(plain.close);
    final response = await Future.sync(
      () => plain.handler(
        Request(
          'GET',
          Uri.parse('http://localhost/orders/export?month=2026-11'),
          headers: staffCreds(token),
        ),
      ),
    );
    expect(response.statusCode, 403);
  });

  test('a malformed stored order -> 500 with a fixed message', () async {
    store(order('bad', '2026-11-15T12:00:00.000', price: 'not a number'));
    final response = await export('?month=2026-11');
    expect(response.statusCode, 500);
    final body = await text(response);
    expect(body, 'Export failed: a stored order is malformed');
    expect(body, isNot(contains('Nguyễn')));
  });

  test('unreadable items JSON -> 500 too', () async {
    db.execute(
      "INSERT INTO orders VALUES ('broken', 'X', 'preparing', "
      "'2026-11-16T10:00:00.000', '{not json', NULL, NULL)",
    );
    expect((await export('?month=2026-11')).statusCode, 500);
  });

  test('an export changes nothing in the database', () async {
    final before = db.select('SELECT COUNT(*) AS n FROM orders').first['n'];
    final version = db.userVersion;

    await export('?month=2026-11');

    expect(db.select('SELECT COUNT(*) AS n FROM orders').first['n'], before);
    expect(db.userVersion, version);
  });

  test('a formula-like customer name is neutralised in the file', () async {
    store(
      order('evil', '2026-11-10T10:00:00.000', customer: "=cmd|' /C calc'!A0"),
    );
    final body = await text(await export('?month=2026-11'));
    expect(body, contains("'=cmd"));
    expect(body, isNot(contains(';=cmd')));
  });

  group('report=summary|detail', () {
    late OrdersApi shop;

    setUp(() {
      shop = OrdersApi(
        db,
        staffGate: StaffGate(id: testStaffId, password: token),
        shopSettings: ShopSettings(_shopEnv),
      );
      addTearDown(shop.close);
    });

    Future<Response> call(
      String query, {
      String? sent = token,
      OrdersApi? on,
    }) => Future.sync(
      () => (on ?? shop).handler(
        Request(
          'GET',
          Uri.parse('http://localhost/orders/export$query'),
          headers: staffCreds(sent),
        ),
      ),
    );

    Future<List<int>> bytes(Response r) async =>
        r.read().expand((c) => c).toList();

    Set<Object?> allValues(ReadWorkbook wb) => {
      for (final sheet in wb.sheets)
        for (final cell in sheet.cells.values) cell.value,
    };

    void storeWith(
      String id,
      String placedAt, {
      String status = 'finished',
      String? method,
      String customer = 'Khách Kín',
      List<Map<String, dynamic>>? items,
    }) => db.execute(
      'INSERT INTO orders (id, customer_name, status, placed_at, items_json, '
      'payment_method) VALUES (?, ?, ?, ?, ?, ?)',
      [
        id,
        customer,
        status,
        placedAt,
        jsonEncode(
          items ??
              [
                {'name': 'Xôi thịt', 'quantity': 1, 'price': 10000},
              ],
        ),
        method,
      ],
    );

    for (final (report, name) in [
      ('summary', 'bao-cao-tong-hop-2026-11.xlsx'),
      ('detail', 'chi-tiet-2026-11.xlsx'),
    ]) {
      test('report=$report: 200, exact headers, a valid workbook', () async {
        storeWith('x-prep', '2026-11-05T10:00:00.000', status: 'preparing');
        storeWith('x-canc', '2026-11-05T11:00:00.000', status: 'cancelled');
        final response = await call('?month=2026-11&report=$report');

        expect(response.statusCode, 200);
        expect(response.headers['content-type'], _xlsxType);
        expect(
          response.headers['content-disposition'],
          'attachment; filename="$name"',
        );
        expect(response.headers['cache-control'], 'no-store');
        final wb = ReadWorkbook.read(await bytes(response));
        final values = allValues(wb);
        // Finished orders of November only: 2 x 25000 twice (the two
        // seeded finished orders), nothing from October or December.
        expect(
          report == 'summary' ? wb.sheetNames : wb.sheetNames.length,
          report == 'summary' ? ['gộp', 'tách'] : 1,
        );
        expect(values, contains(50000));
        expect(
          values.whereType<String>().join('|'),
          allOf(
            isNot(contains('Trần')),
            isNot(contains('Nguyễn')),
            isNot(contains('Kín')),
            isNot(contains('nov-1')),
          ),
        );
      });
    }

    test('detail: the finished orders appear, other statuses do not', () async {
      storeWith(
        'x-prep',
        '2026-11-05T10:00:00.000',
        status: 'preparing',
        items: [
          {'name': 'Món chưa giao', 'quantity': 1, 'price': 1},
        ],
      );
      final wb = ReadWorkbook.read(
        await bytes(await call('?month=2026-11&report=detail')),
      );
      final texts = allValues(wb).whereType<String>().join('|');
      expect(texts, contains('Xôi thịt'));
      expect(texts, isNot(contains('Món chưa giao')));
    });

    test('a cash, a transfer and an unmarked order land in the right '
        'columns', () async {
      storeWith(
        'c1',
        '2026-11-07T08:00:00.000',
        method: 'cash',
        items: [
          {'name': 'Cash dish', 'quantity': 1, 'price': 11000},
        ],
      );
      storeWith(
        't1',
        '2026-11-07T09:00:00.000',
        method: 'bank_transfer',
        items: [
          {'name': 'Transfer dish', 'quantity': 1, 'price': 22000},
        ],
      );
      storeWith(
        'n1',
        '2026-11-07T10:00:00.000',
        items: [
          {'name': 'Unmarked dish', 'quantity': 1, 'price': 3000},
        ],
      );
      final sheet = ReadWorkbook.read(
        await bytes(await call('?month=2026-11&report=detail')),
      ).sheets.single;
      ReadCell? find(String text) => sheet.cells.values
          .where((c) => c.text?.contains(text) ?? false)
          .firstOrNull;
      String col(ReadCell c) => c.ref.replaceAll(RegExp(r'\d'), '');
      int rowOf(ReadCell c) => int.parse(c.ref.replaceAll(RegExp(r'\D'), ''));
      num? amountOn(String text, String column) {
        final row = rowOf(find(text)!);
        return sheet.cell('$column$row')?.number;
      }

      expect(sheet.cell('C3')!.text, 'Tiền mặt');
      expect(sheet.cell('D3')!.text, 'Chuyển khoản');
      expect(amountOn('Cash dish', 'C'), 11000);
      expect(amountOn('Cash dish', 'D'), isNull);
      expect(amountOn('Transfer dish', 'D'), 22000);
      expect(amountOn('Transfer dish', 'C'), isNull);
      expect(amountOn('Unmarked dish', 'C'), 3000);
      expect(amountOn('Unmarked dish', 'D'), isNull);
      expect(col(find('Cash dish')!), isNot('C'));
    });

    for (final report in ['summary', 'detail']) {
      for (final (label, sent, gate, status) in [
        ('no token', null, StaffGate(id: testStaffId, password: token), 401),
        (
          'wrong token',
          'wrong-token-but-long-1234',
          StaffGate(id: testStaffId, password: token),
          401,
        ),
        ('gate disabled', token, StaffGate(), 403),
      ]) {
        test('$report, $label -> $status, empty of data, before month and '
            'report checks', () async {
          final gated = OrdersApi(
            db,
            staffGate: gate,
            shopSettings: ShopSettings(_shopEnv),
          );
          addTearDown(gated.close);
          final ok = await call(
            '?month=2026-11&report=$report',
            sent: sent,
            on: gated,
          );
          final bad = await call(
            '?month=nonsense&report=other',
            sent: sent,
            on: gated,
          );
          for (final r in [ok, bad]) {
            expect(r.statusCode, status);
            expect(r.headers['content-disposition'], isNull);
            final body = await text(r);
            expect(body, isNot(contains('Nguyễn')));
            expect(body, isNot(contains(token)));
          }
        });
      }

      test('$report: lock-out after wrong attempts -> 429', () async {
        final locked = OrdersApi(
          db,
          staffGate: StaffGate(id: testStaffId, password: token),
          shopSettings: ShopSettings(_shopEnv),
        );
        addTearDown(locked.close);
        for (var i = 0; i < 5; i++) {
          await call(
            '?month=2026-11&report=$report',
            sent: 'wrong-token-but-long-1234',
            on: locked,
          );
        }
        final r = await call('?month=2026-11&report=$report', on: locked);
        expect(r.statusCode, 429);
        expect(r.headers['retry-after'], isNotNull);
        expect(r.headers['content-disposition'], isNull);
      });
    }

    for (final query in [
      '',
      '?report=summary',
      '?month=2026-13&report=summary',
      '?month=..%2Fx&report=detail',
    ]) {
      test('month "$query" -> 400', () async {
        final r = await call(query);
        expect(r.statusCode, 400);
        expect(r.headers['content-disposition'], isNull);
      });
    }

    for (final query in [
      '?month=2026-11&report=other',
      '?month=2026-11&report=',
      '?month=2026-11&report=summary&report=detail',
      '?month=2026-11&report=summary&report=summary',
      '?month=2026-11&report=Summary',
      '?month=2026-11&report=%zz',
      '?month=2026-11&format=xlsx',
    ]) {
      test('"$query" -> 400', () async {
        final r = await call(query);
        expect(r.statusCode, 400);
        expect(r.headers['content-disposition'], isNull);
        expect(await text(r), isNot(contains('Nguyễn')));
      });
    }

    test(
      'summary with report settings off -> 503; detail and CSV 200',
      () async {
        final off = OrdersApi(
          db,
          staffGate: StaffGate(id: testStaffId, password: token),
        );
        addTearDown(off.close);
        final r = await call('?month=2026-11&report=summary', on: off);
        expect(r.statusCode, 503);
        expect(r.headers['content-disposition'], isNull);
        expect(await text(r), 'The summary report is not set up');
        expect(
          (await call('?month=2026-11&report=detail', on: off)).statusCode,
          200,
        );
        expect((await call('?month=2026-11', on: off)).statusCode, 200);
        // The month is checked before the settings.
        expect(
          (await call('?month=bad&report=summary', on: off)).statusCode,
          400,
        );
      },
    );

    test('the CSV without report is unchanged by the new route', () async {
      final plain = await bytes(await export('?month=2026-11'));
      final viaShop = await bytes(await call('?month=2026-11'));
      expect(viaShop, plain);
      expect(plain.take(3), [0xEF, 0xBB, 0xBF]);
    });

    for (final report in ['summary', 'detail']) {
      test('$report: a malformed stored order -> 500, fixed message, only '
          'its id logged', () async {
        storeWith(
          'bad-id',
          '2026-11-15T12:00:00.000',
          customer: 'Secret Name',
          items: [
            {'name': 'Dish', 'quantity': 1, 'price': 'not a number'},
          ],
        );
        final captured = _CapturedStderr();
        final r = await IOOverrides.runZoned(
          () => call('?month=2026-11&report=$report'),
          stderr: () => captured,
        );
        expect(r.statusCode, 500);
        expect(await text(r), 'Export failed: a stored order is malformed');
        final log = captured.lines.join('\n');
        expect(log, contains('"bad-id"'));
        expect(log, isNot(contains('Secret Name')));
        expect(log, isNot(contains('not a number')));
      });

      test('$report: unreadable items JSON -> 500', () async {
        db.execute(
          "INSERT INTO orders VALUES ('broken', 'X', 'finished', "
          "'2026-11-16T10:00:00.000', '{not json', NULL, NULL)",
        );
        expect((await call('?month=2026-11&report=$report')).statusCode, 500);
      });

      test('$report: leaves the database unchanged', () async {
        final before = db.select('SELECT COUNT(*) AS n FROM orders').first['n'];
        final version = db.userVersion;
        await call('?month=2026-11&report=$report');
        expect(
          db.select('SELECT COUNT(*) AS n FROM orders').first['n'],
          before,
        );
        expect(db.userVersion, version);
      });

      test('$report: formula-like names never become a formula', () async {
        storeWith(
          'evil',
          '2026-11-10T10:00:00.000',
          customer: "=cmd|' /C calc'!A0",
          items: [
            {'name': '=1+1', 'quantity': 1, 'price': 1000},
          ],
        );
        final wb = ReadWorkbook.read(
          await bytes(await call('?month=2026-11&report=$report')),
        );
        for (final sheet in wb.sheets) {
          for (final cell in sheet.cells.values) {
            if (cell.type == 'formula') {
              expect(cell.formula, isNot(contains('1+1')));
              expect(cell.formula, isNot(contains('cmd')));
            }
            expect(cell.text, isNot(contains('cmd')));
          }
        }
        if (report == 'detail') {
          final cell = wb.sheets.single.cells.values.firstWhere(
            (c) => c.text?.contains('=1+1') ?? false,
          );
          expect(cell.type, 'text');
        }
      });
    }
  });

  test('the other /orders routes still work', () async {
    Future<Response> call(String method, String path, [Object? body]) =>
        Future.sync(
          () => api.handler(
            Request(
              method,
              Uri.parse('http://localhost$path'),
              headers: method == 'PATCH' ? staffCreds(token) : null,
              body: body == null ? null : jsonEncode(body),
            ),
          ),
        );

    expect((await call('GET', '/orders')).statusCode, 200);
    final placed = await call('POST', '/orders', {
      ...order('new', '2026-11-19T10:00:00.000'),
      'status': 'preparing',
    });
    expect(placed.statusCode, 200);
    expect(
      (await call('PATCH', '/orders/new', {'status': 'finished'})).statusCode,
      200,
    );
    expect(
      (await call('GET', '/orders/export?month=2026-11')).statusCode,
      401,
      reason: 'no token sent',
    );
  });
}

/// The test staff ID; the password is the test's `token` value.
const testStaffId = 'test-staff';

/// Staff headers for [password] (none when null), with the test staff ID.
Map<String, String> staffCreds(String? password) => password == null
    ? const {}
    : {staffIdHeader: testStaffId, staffPasswordHeader: password};
