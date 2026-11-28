import 'package:food_orders_backend/database.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// A database that has run steps 1 to 8 only: what a server from before the
/// `finished` status left behind.
Database _version8() {
  final db = openDatabase(':memory:');
  db.userVersion = 8;
  return db;
}

void main() {
  test('step 9: delivered -> finished, ready -> preparing, the rest intact', () {
    final db = _version8();
    addTearDown(db.close);
    const rows = [
      // id, status, method, due
      ('a', 'delivered', 'cash', null),
      ('b', 'ready', 'bank_transfer', null),
      ('c', 'preparing', 'cash', null),
      ('d', 'cancelled', 'bank_transfer', '2026-11-19T08:05:00.000Z'),
      ('e', 'awaiting_payment', 'bank_transfer', '2026-11-19T08:05:00.000Z'),
      ('f', 'delivered', null, null),
      ('g', 'ready', null, null),
      ('h', 'cancelled', 'cash', null),
    ];
    for (final (id, status, method, due) in rows) {
      db.execute(
        'INSERT INTO orders (id, customer_name, status, placed_at, items_json, '
        'payment_method, payment_due_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          'N-$id',
          status,
          '2026-11-0${rows.indexWhere((r) => r.$1 == id) + 1}',
          '[]',
          method,
          due,
        ],
      );
    }
    final before = db.select('SELECT * FROM orders ORDER BY rowid').toList();

    migrate(db);

    expect(db.userVersion, 9);
    final after = db.select('SELECT * FROM orders ORDER BY rowid');
    expect(after.map((r) => r['id']), rows.map((r) => r.$1));
    expect(after.map((r) => r['status']), [
      'finished',
      'preparing',
      'preparing',
      'cancelled',
      'awaiting_payment',
      'finished',
      'preparing',
      'cancelled',
    ]);
    for (var i = 0; i < rows.length; i++) {
      for (final col in [
        'id',
        'customer_name',
        'placed_at',
        'items_json',
        'payment_method',
        'payment_due_at',
      ]) {
        expect(after[i][col], before[i][col], reason: '${rows[i].$1} $col');
      }
    }
  });

  test('a second open does nothing', () {
    final db = _version8();
    addTearDown(db.close);
    db.execute(
      'INSERT INTO orders (id, customer_name, status, placed_at, items_json) '
      "VALUES ('a', 'x', 'delivered', '2026-11-01T10:00:00', '[]')",
    );
    migrate(db);
    // A new `delivered` row after step 9 is not touched by running it again.
    db.execute(
      'INSERT INTO orders (id, customer_name, status, placed_at, items_json) '
      "VALUES ('b', 'x', 'delivered', '2026-11-01T10:00:00', '[]')",
    );
    migrate(db);
    expect(db.userVersion, 9);
    expect(
      db
          .select('SELECT id, status FROM orders ORDER BY rowid')
          .map((r) => r['status']),
      ['finished', 'delivered'],
    );
  });

  test('a failure in the step leaves version 8 and every row unchanged', () {
    final db = _version8();
    addTearDown(db.close);
    db.execute(
      'INSERT INTO orders (id, customer_name, status, placed_at, items_json) '
      "VALUES ('a', 'x', 'delivered', '2026-11-01T10:00:00', '[]'), "
      "('b', 'x', 'ready', '2026-11-01T10:00:00', '[]')",
    );
    // A trigger that refuses the second UPDATE (ready -> preparing) makes the
    // step fail after the first UPDATE already ran.
    db.execute('''
      CREATE TRIGGER refuse_preparing BEFORE UPDATE ON orders
      WHEN NEW.status = 'preparing'
      BEGIN SELECT RAISE(ABORT, 'refused'); END
    ''');

    expect(() => migrate(db), throwsA(isA<SqliteException>()));

    expect(db.userVersion, 8);
    expect(
      db
          .select('SELECT status FROM orders ORDER BY rowid')
          .map((r) => r['status']),
      ['delivered', 'ready'],
    );
  });

  test('a fresh database ends at version 9', () {
    final db = openDatabase(':memory:');
    addTearDown(db.close);
    expect(db.userVersion, 9);
  });
}
