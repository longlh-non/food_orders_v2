// ignore_for_file: avoid_print

import 'dart:io';

import 'package:food_orders_backend/database.dart';
import 'package:food_orders_backend/mock_orders.dart';
import 'package:food_orders_backend/mock_orders_db.dart';
import 'package:food_orders_backend/orders_export.dart' show isValidMonth;

const _usage = '''
Seeds realistic delivered/cancelled mock orders for one month.

  dart run bin/seed_mock_orders.dart [--month=YYYY-MM] [--db=PATH]
                                     [--seed=N] [--clean] [--yes]

  --month  default: the previous full calendar month
  --db     default: ORDERS_DB if set, else backend/data/orders.db
  --seed   default: 2026 (same seed = same orders, apart from the ids)
  --clean  first delete rows whose id starts with mock-
  --yes    skip the typed confirmation
''';

Future<void> main(List<String> args) async {
  String? month;
  String? dbArg;
  var seed = 2026;
  var clean = false;
  var yes = false;
  for (final a in args) {
    if (a.startsWith('--month=')) {
      month = a.substring(8);
    } else if (a.startsWith('--db=')) {
      dbArg = a.substring(5);
    } else if (a.startsWith('--seed=')) {
      final n = int.tryParse(a.substring(7));
      if (n == null) return _fail('--seed must be a whole number');
      seed = n;
    } else if (a == '--clean') {
      clean = true;
    } else if (a == '--yes') {
      yes = true;
    } else {
      return _fail('Unknown argument: $a');
    }
  }

  final now = DateTime.now();
  final prev = DateTime(now.year, now.month - 1, 1);
  month ??=
      '${prev.year.toString().padLeft(4, '0')}-'
      '${prev.month.toString().padLeft(2, '0')}';
  if (!isValidMonth(month)) return _fail('--month must be YYYY-MM');

  final fromEnv = Platform.environment['ORDERS_DB'];
  final rawPath = (dbArg != null && dbArg.isNotEmpty)
      ? dbArg
      : (fromEnv != null && fromEnv.isNotEmpty)
      ? fromEnv
      : File.fromUri(Platform.script).parent.parent.uri
            .resolve('data/orders.db')
            .toFilePath();
  final path = rawPath == ':memory:' ? rawPath : File(rawPath).absolute.path;

  print('Database: $path');
  print('Month:    $month   seed: $seed   clean: $clean');
  if (path != ':memory:') {
    print('Back it up first (backend stopped):');
    print('  cp "$path" "$path.\$(date +%F-%H%M).bak"');
  }
  if (!yes) {
    stdout.write('Type yes to add mock orders to this database: ');
    final answer = stdin.readLineSync()?.trim();
    if (answer != 'yes') {
      print('Cancelled. Nothing was written.');
      exit(1);
    }
  }

  final db = openDatabase(path);
  try {
    final rows = buildMockOrders(
      month: month,
      menuItems: readMenuItems(db),
      toppings: readToppings(db),
      seed: seed,
      runTimestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (rows.isEmpty) {
      return _fail('No available menu items in this database; nothing to do.');
    }
    final n = seedMockOrders(db, rows, clean: clean);
    final dates = rows.map((r) => r['placedAt'] as String).toList()..sort();
    print('Inserted $n orders, ${dates.first} to ${dates.last}.');
    print('By status: ${_count(rows, 'status')}');
    print('By payment method: ${_count(rows, 'paymentMethod')}');
    print('To remove them again:');
    print('  sqlite3 "$path" "$cleanupSql"');
  } on MockSeedRefused catch (e) {
    return _fail(e.message);
  } finally {
    db.close();
  }
}

String _count(List<Map<String, dynamic>> rows, String key) {
  final counts = <String, int>{};
  for (final r in rows) {
    counts[r[key] as String] = (counts[r[key] as String] ?? 0) + 1;
  }
  return counts.entries.map((e) => '${e.key}=${e.value}').join(', ');
}

void _fail(String message) {
  stderr.writeln(message);
  if (message.startsWith('--') || message.startsWith('Unknown')) {
    stderr.writeln(_usage);
  }
  exit(message.startsWith('--') || message.startsWith('Unknown') ? 64 : 1);
}
