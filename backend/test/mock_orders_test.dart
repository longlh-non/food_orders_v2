import 'package:food_orders_backend/mock_orders.dart';
import 'package:food_orders_backend/orders_api.dart';
import 'package:test/test.dart';

const _menu = [
  {'id': 'xoi-thit', 'name': 'Xôi thịt', 'price': 25000, 'allowToppings': true},
  {'id': 'xoi-ruoc', 'name': 'Xôi ruốc', 'price': 20000, 'allowToppings': true},
  {'id': 'tra-da', 'name': 'Trà đá', 'price': 5000, 'allowToppings': false},
  {'id': 'banh', 'name': 'Bánh mì', 'price': 15000, 'allowToppings': false},
];
const _toppings = [
  {'id': 'cha', 'name': 'Thêm chả', 'price': 10000},
  {'id': 'thit', 'name': 'Thêm thịt', 'price': 12000},
];
const _month = '2026-10';

List<Map<String, dynamic>> _build({
  String month = _month,
  List<Map<String, dynamic>> menu = _menu,
  List<Map<String, dynamic>> toppings = _toppings,
  int seed = 7,
  int ts = 1000,
}) => buildMockOrders(
  month: month,
  menuItems: menu,
  toppings: toppings,
  seed: seed,
  runTimestampMs: ts,
);

Map<String, dynamic> _stripId(Map<String, dynamic> r) => {...r}..remove('id');

void main() {
  test('same seed gives the same orders apart from the id timestamp', () {
    final a = _build(ts: 1);
    final b = _build(ts: 2);
    expect(a, isNotEmpty);
    expect(a.map(_stripId).toList(), b.map(_stripId).toList());
    expect(a.first['id'], startsWith('mock-1-'));
    expect(b.first['id'], startsWith('mock-2-'));
    expect(
      _build(seed: 8).map(_stripId).toList(),
      isNot(a.map(_stripId).toList()),
    );
  });

  test('every row respects the order limits', () {
    final topIds = _toppings.map((t) => t['id']).toSet();
    final allowByName = {for (final m in _menu) m['name']: m['allowToppings']};
    final ids = <Object?>{};
    for (final seed in [1, 2, 3]) {
      for (final r in _build(seed: seed)) {
        final id = r['id'] as String;
        expect(id, startsWith('mock-'));
        expect(id.length, lessThanOrEqualTo(maxIdLength));
        ids.add('$seed$id');
        expect(
          (r['customerName'] as String).length,
          lessThanOrEqualTo(maxNameLength),
        );
        expect(['delivered', 'cancelled'], contains(r['status']));
        expect(orderStatuses, contains(r['status']));
        expect(paymentMethods, contains(r['paymentMethod']));
        expect(r['paymentDueAt'], isNull);
        expect(r['placedAt'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}T')));
        expect(DateTime.tryParse(r['placedAt'] as String), isNotNull);
        final items = (r['items'] as List).cast<Map<String, dynamic>>();
        expect(items, isNotEmpty);
        expect(items.length, lessThanOrEqualTo(maxItemsPerOrder));
        for (final i in items) {
          expect(
            (i['name'] as String).length,
            lessThanOrEqualTo(maxNameLength),
          );
          expect(i['quantity'], isA<int>());
          expect(i['quantity'], inInclusiveRange(1, maxQuantity));
          expect(i['price'], isA<int>());
          expect(i['price'], inInclusiveRange(0, maxPrice));
          final tops = (i['toppings'] as List?)?.cast<Map<String, dynamic>>();
          if (tops != null) {
            expect(allowByName[i['name']], isTrue);
            expect(tops.length, lessThanOrEqualTo(maxToppingsPerItem));
            for (final t in tops) {
              expect(topIds, contains(t['id']));
            }
          }
        }
      }
    }
  });

  test('mixes statuses and methods, and uses toppings', () {
    final rows = _build();
    expect(rows.map((r) => r['status']).toSet(), {'delivered', 'cancelled'});
    expect(rows.map((r) => r['paymentMethod']).toSet(), paymentMethods);
    final withTop = rows
        .expand((r) => r['items'] as List)
        .any((i) => (i as Map).containsKey('toppings'));
    expect(withTop, isTrue);
  });

  test('one day of the month always has no orders, for every seed', () {
    for (var seed = 0; seed < 50; seed++) {
      final rows = _build(seed: seed);
      final days = rows
          .map((r) => r['placedAt'] as String)
          .where((p) => p.startsWith('$_month-'))
          .map((p) => p.substring(0, 10))
          .toSet();
      expect(days.length, lessThan(31), reason: 'seed $seed');
      expect(days.length, 30, reason: 'exactly one empty day, seed $seed');
    }
  });

  test('a few rows fall just outside the month and are still valid', () {
    final outside = _build()
        .where((r) => !(r['placedAt'] as String).startsWith('$_month-'))
        .toList();
    expect(outside.length, inInclusiveRange(2, 3));
    expect(
      outside.map((r) => (r['placedAt'] as String).substring(0, 10)).toSet(),
      {'2026-09-30', '2026-11-01'},
    );
    for (final r in outside) {
      expect(['delivered', 'cancelled'], contains(r['status']));
      expect(r['items'], isNotEmpty);
    }
  });

  test('December and February month edges', () {
    final dec = _build(month: '2026-12');
    expect(
      dec.map((r) => (r['placedAt'] as String).substring(0, 10)),
      containsAll(['2026-11-30', '2027-01-01']),
    );
    final feb = _build(month: '2028-02');
    final inMonth = feb.where(
      (r) => (r['placedAt'] as String).startsWith('2028-02-'),
    );
    expect(
      inMonth
          .map((r) => (r['placedAt'] as String).substring(0, 10))
          .toSet()
          .length,
      28,
    );
  });

  test('toppings never attach when none are given; empty menu gives []', () {
    final noTops = _build(toppings: const []);
    expect(noTops, isNotEmpty);
    expect(
      noTops
          .expand((r) => r['items'] as List)
          .any((i) => (i as Map).containsKey('toppings')),
      isFalse,
    );
    expect(_build(menu: const []), isEmpty);
    final noToppingMenu = _build(menu: [_menu[2], _menu[3]]);
    expect(
      noToppingMenu
          .expand((r) => r['items'] as List)
          .any((i) => (i as Map).containsKey('toppings')),
      isFalse,
    );
  });

  test('menu entries outside the limits are skipped', () {
    final rows = _build(
      menu: [
        {
          'id': 'x',
          'name': 'Quá đắt',
          'price': maxPrice + 1,
          'allowToppings': false,
        },
        {'id': 'y', 'name': 'Lẻ', 'price': 9.5, 'allowToppings': false},
        _menu[2],
      ],
    );
    final names = rows
        .expand((r) => r['items'] as List)
        .map((i) => (i as Map)['name'])
        .toSet();
    expect(names, {'Trà đá'});
  });

  test('rejects a bad month', () {
    expect(() => _build(month: '2026-13'), throwsArgumentError);
  });
}
