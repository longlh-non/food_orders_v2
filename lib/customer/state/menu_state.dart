import 'package:flutter/foundation.dart';

import '../../shared/api/order_api_client.dart';
import '../../shared/models/menu_item.dart';
import '../../shared/models/topping.dart';

/// The customer app's copy of the menu, fetched from `GET /api/menu`.
///
/// Use [MenuState.instance] in the app (same style as `Cart` and
/// `MyOrders`). Tests build their own with `MenuState(OrderApiClient(client:
/// MockClient(...)))`.
///
/// Holds the menu items, the toppings, a loading flag and the last error.
/// The menu page listens (and the cart is synced from it); [load] notifies
/// when it starts and again when it finishes, whether it worked or failed.
class MenuState extends ChangeNotifier {
  MenuState(this._api);

  static final MenuState instance = MenuState(OrderApiClient());

  final OrderApiClient _api;

  List<MenuItem> _items = const [];
  List<Topping> _toppings = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  Object? _error;

  /// The last menu that loaded successfully (empty until the first load).
  List<MenuItem> get items => _items;

  /// The toppings foods can take, loaded together with the menu.
  List<Topping> get toppings => _toppings;
  bool get isLoading => _isLoading;

  /// True once a load has succeeded. Tells "not loaded yet" apart from
  /// "the menu really is empty".
  bool get hasLoaded => _hasLoaded;

  /// Why the last [load] failed, or null if it succeeded / hasn't run.
  Object? get error => _error;

  /// Fetches the menu. Safe to call again to retry after an error. A call
  /// made while a load is already running does nothing.
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Menu and toppings load together: one loading state, one error
      // state. If either fails, the page shows the usual error and Retry.
      final results = await Future.wait<Object>([
        _api.fetchMenu(),
        _api.fetchToppings(),
      ], eagerError: true);
      _items = List.unmodifiable(results[0] as List<MenuItem>);
      _toppings = List.unmodifiable(results[1] as List<Topping>);
      _hasLoaded = true;
    } on Object catch (e, stackTrace) {
      // Deliberate catch-all: this is the boundary between the network and
      // the UI. Whatever went wrong (backend down, bad data), the page shows
      // an error with a Retry button instead of crashing.
      _error = e;
      // Debug builds only: in a release web build this would reach every
      // customer's browser console.
      if (kDebugMode) debugPrint('Menu failed to load: $e\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
