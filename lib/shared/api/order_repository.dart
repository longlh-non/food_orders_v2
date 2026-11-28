import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/order.dart';
import 'order_api_client.dart';

/// Single source of truth for Orders across the app.
///
/// Design:
/// - Singleton — both customer and restaurant screens read from the same
///   instance. In the split-view [DemoApp] this is why one in-process repo
///   gives real cross-pane updates.
/// - `ChangeNotifier` — any widget using `ListenableBuilder` or
///   `addListener` rebuilds when the list mutates.
/// - Backed by HTTP for CRUD and a long-lived SSE stream for live updates.
///   The in-memory `_orders` list is a cache of the backend's state.
///
/// Swap target: if the backend ever moves (Firebase, Supabase, websocket),
/// only [OrderApiClient] needs to change — UI code is untouched.
class OrderRepository extends ChangeNotifier {
  OrderRepository._();
  static final OrderRepository instance = OrderRepository._();

  OrderApiClient _api = OrderApiClient();
  final List<Order> _orders = [];
  StreamSubscription<Order>? _subscription;
  bool _initialized = false;

  List<Order> get orders => List.unmodifiable(_orders);

  /// Orders that haven't reached a terminal state. Used by banners and
  /// badges that only care about in-progress work.
  List<Order> get activeOrders => _orders
      .where(
        (o) =>
            o.status != OrderStatus.delivered &&
            o.status != OrderStatus.finished &&
            o.status != OrderStatus.cancelled,
      )
      .toList();

  /// Hydrates the cache and subscribes to the live stream. Idempotent.
  ///
  /// Called fire-and-forget from each entry point's `main()`. If the backend
  /// isn't up yet the fetch fails silently; the SSE stream will reconnect
  /// and start populating when the backend comes online.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final initial = await _api.fetchOrders();
      _orders
        ..clear()
        ..addAll(initial);
      notifyListeners();
    } catch (_) {
      // backend not reachable; SSE loop will retry.
    }
    _subscription = _api.streamUpdates().listen(_merge);
  }

  /// Re-reads the order list once and merges every order into the cache
  /// (one notification). For a screen that suspects its copy is stale, e.g.
  /// the live stream is down. Errors are swallowed: the cache stays as it was.
  Future<void> refresh() async {
    final List<Order> fresh;
    try {
      fresh = await _api.fetchOrders();
    } catch (_) {
      return;
    }
    if (fresh.isEmpty) return;
    // Oldest first, so unseen orders end up newest-first like the server's.
    for (final order in fresh.reversed) {
      final index = _orders.indexWhere((o) => o.id == order.id);
      if (index == -1) {
        _orders.insert(0, order);
      } else {
        _orders[index] = order;
      }
    }
    notifyListeners();
  }

  /// Sends the new order to the backend and merges the server-returned copy
  /// into the local cache. The SSE stream will also push this event back to
  /// us; [_merge] is idempotent so the dupe is harmless.
  ///
  /// Throws [OrderRequestException] when the backend didn't accept the
  /// order; the cache is then left unchanged. Callers must await this.
  Future<void> placeOrder(Order order) async {
    final result = await _api.placeOrder(order);
    _merge(result);
  }

  /// Changes an order's status on the backend, then merges the result.
  /// Staff only: [staffHeaders] are passed straight to the client and not
  /// kept. Throws [OrderRequestException] on failure, leaving the cache
  /// unchanged.
  Future<void> updateStatus(
    String id,
    OrderStatus status, {
    required Map<String, String> staffHeaders,
  }) async {
    final result = await _api.updateStatus(
      id,
      status,
      staffHeaders: staffHeaders,
    );
    _merge(result);
  }

  /// Customer: switches an order to cash, then merges the server's copy.
  /// Throws [OrderRequestException] on failure, leaving the cache unchanged.
  Future<void> switchToCash(String id) async =>
      _merge(await _api.switchToCash(id));

  /// Customer: renews an expired transfer order, then merges the result.
  /// Same failure behaviour as [switchToCash].
  Future<void> renewPayment(String id) async =>
      _merge(await _api.renewPayment(id));

  /// Staff: switches an order to cash, then merges the result. The headers
  /// are passed straight to the client and not kept.
  Future<void> staffSwitchToCash(
    String id, {
    required Map<String, String> staffHeaders,
  }) async =>
      _merge(await _api.staffSwitchToCash(id, staffHeaders: staffHeaders));

  /// Staff: confirms a bank transfer, then merges the result.
  Future<void> confirmPayment(
    String id, {
    required Map<String, String> staffHeaders,
  }) async => _merge(await _api.confirmPayment(id, staffHeaders: staffHeaders));

  /// Tests only: makes the repository talk to [api] (e.g. an
  /// `OrderApiClient(client: MockClient(...))`) instead of the real backend.
  /// Not for app code.
  @visibleForTesting
  void setApiForTest(OrderApiClient api) => _api = api;

  /// Tests only: replaces the cached orders without any network call, so
  /// widgets that read [orders] can be tested. Not for app code.
  @visibleForTesting
  void setOrdersForTest(List<Order> orders) {
    _orders
      ..clear()
      ..addAll(orders);
    notifyListeners();
  }

  /// Insert-or-replace by id, keeping the list order (newest-first) stable
  /// for inserts. New arrivals from the SSE stream go to position 0.
  void _merge(Order order) {
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index == -1) {
      _orders.insert(0, order);
    } else {
      _orders[index] = order;
    }
    notifyListeners();
  }

  /// Cancels the SSE subscription so it can't deliver events after
  /// disposal. In practice this singleton lives for the app's lifetime and
  /// is never disposed; this exists to satisfy ChangeNotifier's contract.
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
