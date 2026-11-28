import 'dart:convert';

import 'package:food_orders_backend/database.dart';
import 'package:food_orders_backend/mock_orders.dart';
import 'package:food_orders_backend/mock_orders_db.dart';
import 'package:food_orders_backend/orders_report.dart';
import 'package:food_orders_backend/report_detail.dart';
import 'package:food_orders_backend/report_summary.dart';
import 'package:food_orders_backend/shop_settings.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

const _month = '2026-10';

Map<String, dynamic> _fromRow(Row row) => {
  'id': row['id'],
  'customerName': row['customer_name'],
  'items': jsonDecode(row['items_json'] as String),
  'status': row['status'],
  'placedAt': row['placed_at'],
  'paymentMethod': row['payment_method'] ?? 'cash',
  'paymentDueAt': row['payment_due_at'],
};

List<Map<String, dynamic>> _rows(Database db, {int seed = 3, int ts = 5}) =>
    buildMockOrders(
      month: _month,
      menuItems: readMenuItems(db),
      toppings: readToppings(db),
      seed: seed,
      runTimestampMs: ts,
    );

void _fillTo(Database db, int n) {
  db.execute('''
    WITH RECURSIVE c(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM c WHERE i < $n)
    INSERT INTO orders (id, customer_name, status, placed_at, items_json)
    SELECT 'real-' || i, 'x', 'finished', '2026-01-01T10:00:00', '[]' FROM c
  ''');
}

void main() {
  late Database db;
  setUp(() => db = openDatabase(':memory:'));
  tearDown(() => db.close());

  test('reads the real seeded menu and toppings', () {
    expect(readMenuItems(db), isNotEmpty);
    expect(readToppings(db), isNotEmpty);
  });

  test('inserted rows round-trip through the report functions', () {
    final rows = _rows(db);
    expect(seedMockOrders(db, rows), rows.length);
    final stored = [
      for (final r in db.select('SELECT * FROM orders ORDER BY rowid'))
        _fromRow(r),
    ];
    expect(stored.length, rows.length);

    final expectedFinished = rows
        .where(
          (r) =>
              r['status'] == 'finished' &&
              (r['placedAt'] as String).startsWith('$_month-'),
        )
        .toList();
    final finished = finishedOrders(stored, _month);
    expect(finished.length, expectedFinished.length);

    final days = dailyTotals(finished, _month);
    expect(days.length, 31);
    expect(days.fold<int>(0, (n, d) => n + d.orders.length), finished.length);
    final expectedCash = expectedFinished
        .where((r) => r['paymentMethod'] == 'cash')
        .fold<num>(0, (s, r) => s + orderTotal(r));
    final expectedTransfer = expectedFinished
        .where((r) => r['paymentMethod'] == 'bank_transfer')
        .fold<num>(0, (s, r) => s + orderTotal(r));
    expect(days.fold<num>(0, (s, d) => s + d.cash), expectedCash);
    expect(days.fold<num>(0, (s, d) => s + d.transfer), expectedTransfer);
    expect(expectedCash, greaterThan(0));
    expect(expectedTransfer, greaterThan(0));
    expect(days.where((d) => d.orders.isEmpty), isNotEmpty);
    expect(daysWithOrders(finished, _month).length, lessThan(31));
  });

  test('both report builders make non-empty zip bytes from the data', () {
    seedMockOrders(db, _rows(db));
    final stored = [
      for (final r in db.select('SELECT * FROM orders')) _fromRow(r),
    ];
    final finished = finishedOrders(stored, _month);
    final shop = ShopSettings({
      'SHOP_NAME': 'QUÁN THỬ',
      'SHOP_TAX_CODE': '0000000000-999',
      'SHOP_ADDRESS': '99 Đường Giả Định',
      'SHOP_LOCATION': '100 Đường Demo',
      'SHOP_REPRESENTATIVE': 'Nguyễn Văn Mẫu',
    });
    final summary = buildSummaryReport(
      shop: shop,
      month: _month,
      days: dailyTotals(finished, _month),
    );
    final detail = buildDetailReport(
      month: _month,
      days: daysWithOrders(finished, _month),
    );
    for (final bytes in [summary, detail]) {
      expect(bytes.length, greaterThan(100));
      expect(bytes.take(2), [0x50, 0x4B]); // "PK": a zip file
    }
  });

  test('refuses to reach the order cap and writes nothing', () {
    _fillTo(db, 95);
    final rows = _rows(db);
    expect(rows.length, greaterThan(5));
    expect(
      () => seedMockOrders(db, rows, maxStoredOrders: 100),
      throwsA(isA<MockSeedRefused>()),
    );
    expect(db.select('SELECT COUNT(*) AS n FROM orders').first['n'], 95);
  });

  test('a refusal also undoes --clean', () {
    _fillTo(db, 10);
    final rows = _rows(db);
    seedMockOrders(db, rows.take(3).toList());
    expect(
      () => seedMockOrders(db, rows, clean: true, maxStoredOrders: 20),
      throwsA(isA<MockSeedRefused>()),
    );
    expect(db.select('SELECT COUNT(*) AS n FROM orders').first['n'], 13);
  });

  test('--clean removes only mock- rows', () {
    _fillTo(db, 1);
    db.execute(
      "INSERT INTO orders (id, customer_name, status, placed_at, items_json) "
      "VALUES ('mocking-bird', 'y', 'finished', '2026-01-01T10:00:00', '[]')",
    );
    seedMockOrders(db, _rows(db, ts: 1));
    final first =
        db
                .select(
                  "SELECT COUNT(*) AS n FROM orders WHERE id LIKE 'mock-%'",
                )
                .first['n']
            as int;
    final second = _rows(db, ts: 2, seed: 9);
    seedMockOrders(db, second, clean: true);
    final mock = db
        .select("SELECT COUNT(*) AS n FROM orders WHERE id LIKE 'mock-%'")
        .first['n'];
    expect(mock, second.length);
    expect(first, isNot(second.length + 100000));
    final others = db.select(
      "SELECT id FROM orders WHERE id NOT LIKE 'mock-%'",
    );
    expect(others.map((r) => r['id']).toSet(), {'real-1', 'mocking-bird'});
  });

  test('append without --clean keeps earlier mock rows', () {
    final a = _rows(db, ts: 1);
    final b = _rows(db, ts: 2);
    seedMockOrders(db, a);
    seedMockOrders(db, b);
    expect(
      db.select('SELECT COUNT(*) AS n FROM orders').first['n'],
      a.length + b.length,
    );
  });
}
