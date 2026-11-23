import 'package:flutter/foundation.dart';

import '../../shared/models/menu_item.dart';
import '../../shared/models/order.dart';
import '../../shared/models/topping.dart';

/// One line in the cart: a dish plus the toppings chosen for it.
///
/// Two lines are the same line when they have the same dish and the same
/// **set** of toppings, whatever order the toppings were picked in. So
/// "Xôi thịt + chả" added twice is one line with quantity 2, while plain
/// "Xôi thịt" is a separate line.
class CartLine {
  /// Makes a line for [item] with [toppings]. A topping listed twice is kept
  /// once, and the stored list can't be changed afterwards, so a line's
  /// identity can't shift while it is a key in the cart's map.
  CartLine(this.item, [List<Topping> toppings = const []])
    : toppings = List.unmodifiable(_uniqueById(toppings));

  final MenuItem item;

  /// In the order they were picked, each topping at most once.
  final List<Topping> toppings;

  /// The price of one unit: the dish plus its toppings.
  double get unitPrice =>
      toppings.fold(item.price, (sum, topping) => sum + topping.price);

  Set<String> get _toppingIds => {for (final t in toppings) t.id};

  @override
  bool operator ==(Object other) =>
      other is CartLine &&
      other.item.id == item.id &&
      setEquals(other._toppingIds, _toppingIds);

  @override
  int get hashCode =>
      Object.hash(item.id, Object.hashAllUnordered(_toppingIds));

  /// Drops repeated toppings (same id), keeping the first and the order.
  static List<Topping> _uniqueById(List<Topping> toppings) {
    final seen = <String>{};
    return [
      for (final t in toppings)
        if (seen.add(t.id)) t,
    ];
  }
}

/// Session-local shopping cart for the customer app.
///
/// Singleton `ChangeNotifier` — only one customer flow is active in a browser
/// tab at a time. Not persisted; refreshing clears it. State moves to the
/// server-side `Order` once the customer places the order.
///
/// Holds a map from [CartLine] to quantity, in the order lines were first
/// added. The cart button on the menu page and the cart page listen through
/// `ListenableBuilder`; [add], [remove], [clear] and [refreshItems] call
/// `notifyListeners` so they redraw.
class Cart extends ChangeNotifier {
  /// Private, so nobody can make a second cart; use [instance].
  Cart._();

  /// The one cart shared by the whole customer app.
  static final Cart instance = Cart._();

  final Map<CartLine, int> _lines = {};

  /// Each line and its quantity, in the order lines were first added.
  Map<CartLine, int> get lines => Map.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;

  /// Total quantity across all lines (shown in the badge on the round cart button).
  int get itemCount => _lines.values.fold(0, (sum, qty) => sum + qty);

  double get total =>
      _lines.entries.fold(0, (sum, e) => sum + e.key.unitPrice * e.value);

  /// Adds one unit of [item] with [toppings], merging into an identical
  /// line if there is one.
  void add(MenuItem item, {List<Topping> toppings = const []}) {
    final line = CartLine(item, toppings);
    _lines[line] = (_lines[line] ?? 0) + 1;
    notifyListeners();
  }

  /// Decrements one line; removes it when its quantity hits zero.
  void remove(CartLine line) {
    final current = _lines[line];
    if (current == null) return;
    if (current <= 1) {
      _lines.remove(line);
    } else {
      _lines[line] = current - 1;
    }
    notifyListeners();
  }

  /// Swaps every line's dish and toppings for their freshly loaded versions
  /// after the menu reloads (new price or name, same id), keeping quantities.
  /// A line whose dish **or** any of whose toppings is no longer on the menu
  /// is removed. Returns how many lines were removed and how many changed
  /// price, so the page can tell the customer.
  ///
  /// Needed because a Map keeps its original key: without this, a line would
  /// keep the old prices.
  ///
  /// [toppings] is required on purpose: leaving it out would silently drop
  /// every line that has toppings.
  ({int removed, int repriced}) refreshItems(
    List<MenuItem> menu,
    List<Topping> toppings,
  ) {
    final freshItems = {for (final item in menu) item.id: item};
    final freshToppings = {for (final t in toppings) t.id: t};
    var removed = 0;
    var repriced = 0;
    final updated = <CartLine, int>{};
    for (final MapEntry(key: line, value: quantity) in _lines.entries) {
      final item = freshItems[line.item.id];
      final lineToppings = [
        for (final t in line.toppings) ?freshToppings[t.id],
      ];
      if (item == null || lineToppings.length != line.toppings.length) {
        removed++;
        continue;
      }
      final fresh = CartLine(item, lineToppings);
      if (fresh.unitPrice != line.unitPrice) repriced++;
      updated[fresh] = (updated[fresh] ?? 0) + quantity;
    }
    _lines
      ..clear()
      ..addAll(updated);
    notifyListeners();
    return (removed: removed, repriced: repriced);
  }

  /// Empties the cart and notifies listeners (used after an order is placed).
  void clear() {
    _lines.clear();
    notifyListeners();
  }

  /// Snapshot the cart into [OrderItem]s to attach to an [Order]. Every line
  /// carries the dish id and each topping's id (owner decision TOP3), so the
  /// server can later check prices against the menu. `price` is the dish's
  /// base price; the toppings carry their own.
  List<OrderItem> toOrderItems() => [
    for (final MapEntry(key: line, value: quantity) in _lines.entries)
      OrderItem(
        menuItemId: line.item.id,
        name: line.item.name,
        quantity: quantity,
        price: line.item.price,
        toppings: [
          for (final t in line.toppings)
            OrderTopping(id: t.id, name: t.name, price: t.price),
        ],
      ),
  ];
}
