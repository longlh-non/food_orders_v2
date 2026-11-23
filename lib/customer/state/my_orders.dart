import 'package:flutter/foundation.dart';

/// Tracks the IDs of orders the current customer placed in this browser
/// session, so the menu page can show an "Đơn của bạn" banner and fire
/// snackbars only for orders this user actually owns.
///
/// There is no auth yet; "mine" means "placed from this tab, this session".
/// Lost on refresh — fine for the prototype; add real auth + persistence
/// before shipping.
///
/// Holds a set of order ids. The menu page listens with `addListener`;
/// [track] and [clearForTest] notify when the set changes.
class MyOrders extends ChangeNotifier {
  /// Private, so nobody can make a second tracker; use [instance].
  MyOrders._();

  /// The one tracker shared by the whole customer app.
  static final MyOrders instance = MyOrders._();

  final Set<String> _ids = {};

  /// A read-only copy of the tracked order ids.
  Set<String> get ids => Set.unmodifiable(_ids);

  /// Whether [id] was placed from this tab, this session.
  bool contains(String id) => _ids.contains(id);

  /// Tests only: forgets every tracked order.
  @visibleForTesting
  void clearForTest() {
    _ids.clear();
    notifyListeners();
  }

  /// Remembers an order id. Notifies listeners (the menu page) only when the
  /// id is new.
  void track(String orderId) {
    if (_ids.add(orderId)) notifyListeners();
  }
}
