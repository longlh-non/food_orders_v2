import 'package:flutter/foundation.dart';

/// Tracks the IDs of orders the current customer placed in this browser
/// session, so the menu page can show a "Your orders" banner and fire
/// snackbars only for orders this user actually owns.
///
/// There is no auth yet; "mine" means "placed from this tab, this session".
/// Lost on refresh — fine for the prototype; add real auth + persistence
/// before shipping.
class MyOrders extends ChangeNotifier {
  MyOrders._();
  static final MyOrders instance = MyOrders._();

  final Set<String> _ids = {};
  Set<String> get ids => Set.unmodifiable(_ids);

  bool contains(String id) => _ids.contains(id);

  /// Tests only: forgets every tracked order.
  @visibleForTesting
  void clearForTest() {
    _ids.clear();
    notifyListeners();
  }

  void track(String orderId) {
    if (_ids.add(orderId)) notifyListeners();
  }
}
