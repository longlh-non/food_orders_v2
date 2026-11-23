import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'orders_api.dart' show defaultMaxStoredOrders;

/// Database side of the mock-order dev tool (`bin/seed_mock_orders.dart`).
/// Kept out of `bin/` so the tests can call it. Never opens a file itself.

/// The one statement that removes mock rows (and only mock rows).
const cleanupSql = "DELETE FROM orders WHERE id LIKE 'mock-%'";

/// The available menu items, in the `GET /menu` shape the generator reads.
List<Map<String, dynamic>> readMenuItems(Database db) => [
  for (final r in db.select(
    'SELECT id, name, price, category, allow_toppings FROM menu_items '
    'WHERE available = 1 ORDER BY rowid',
  ))
    {
      'id': r['id'],
      'name': r['name'],
      'price': r['price'],
      // Same rule as menu_api.dart: only foods take toppings.
      'allowToppings': r['category'] == 'food' && r['allow_toppings'] == 1,
    },
];

List<Map<String, dynamic>> readToppings(Database db) => [
  for (final r in db.select(
    'SELECT id, name, price FROM toppings ORDER BY rowid',
  ))
    {'id': r['id'], 'name': r['name'], 'price': r['price']},
];

/// Thrown when the insert would reach the order cap; nothing was written.
class MockSeedRefused implements Exception {
  MockSeedRefused(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Inserts [rows] in one transaction, with the same column list as a real
/// `POST /orders`. With [clean], deletes `mock-%` rows first. Refuses (and
/// rolls back, so even the clean is undone) when the stored count plus
/// [rows] would reach [maxStoredOrders]. Returns the number inserted.
int seedMockOrders(
  Database db,
  List<Map<String, dynamic>> rows, {
  bool clean = false,
  int maxStoredOrders = defaultMaxStoredOrders,
}) {
  db.execute('BEGIN');
  try {
    if (clean) db.execute(cleanupSql);
    final count =
        db.select('SELECT COUNT(*) AS n FROM orders').first['n'] as int;
    if (count + rows.length >= maxStoredOrders) {
      throw MockSeedRefused(
        'Refused: $count orders stored + ${rows.length} new would reach the '
        'limit of $maxStoredOrders. Nothing was written.',
      );
    }
    final stmt = db.prepare(
      'INSERT INTO orders (id, customer_name, status, placed_at, items_json, '
      'payment_method, payment_due_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
    );
    try {
      for (final r in rows) {
        stmt.execute([
          r['id'],
          r['customerName'],
          r['status'],
          r['placedAt'],
          jsonEncode(r['items']),
          r['paymentMethod'],
          r['paymentDueAt'],
        ]);
      }
    } finally {
      stmt.close();
    }
    db.execute('COMMIT');
    return rows.length;
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}
