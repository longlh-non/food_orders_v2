import 'dart:convert';

import 'package:food_orders_backend/database.dart';
import 'package:food_orders_backend/orders_api.dart';
import 'package:food_orders_backend/staff_gate.dart';
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

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
  'status': 'delivered',
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

  test('the other /orders routes still work', () async {
    Future<Response> call(String method, String path, [Object? body]) =>
        Future.sync(
          () => api.handler(
            Request(
              method,
              Uri.parse('http://localhost$path'),
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
      (await call('PATCH', '/orders/new', {'status': 'ready'})).statusCode,
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
