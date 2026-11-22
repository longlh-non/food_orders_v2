import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/topping.dart';

/// Thin HTTP wrapper around the backend's /orders, /menu and /toppings routes.
///
/// All requests use the relative `/api` prefix. In dev this is same-origin
/// through Caddy (customer.local/api → localhost:3000, prefix stripped), so
/// no CORS. In prod the same relative URL works as long as the frontend and
/// backend are served under one domain (or you proxy /api at the edge).
///
/// Pass a [client] in tests (e.g. `MockClient` from `package:http/testing`);
/// the app uses the default.
class OrderApiClient {
  OrderApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = '/api';

  final http.Client _client;

  /// All orders. Each order is parsed on its own: one malformed order is
  /// skipped (and logged in debug builds) instead of emptying the whole list
  /// for everyone.
  Future<List<Order>> fetchOrders() async {
    final response = await _client.get(Uri.parse('$_baseUrl/orders'));
    final list = jsonDecode(response.body) as List;
    return [for (final json in list) ?_parseOrder(json)];
  }

  /// Parses one order from the server, or returns null if it's malformed.
  /// Catch-all on purpose: orders echo whatever a client posted, so any
  /// wrong type (TypeError from a cast, FormatException from a check) must
  /// cost only that order.
  static Order? _parseOrder(Object? json) {
    try {
      return Order.fromJson(json as Map<String, dynamic>);
    } on Object catch (e) {
      if (kDebugMode) debugPrint('Skipped a malformed order: $e');
      return null;
    }
  }

  /// Sends a new order (`POST /orders`) and returns the server's copy.
  ///
  /// Throws [OrderRequestException] when the order was not accepted: any
  /// non-2xx answer (400 invalid, 409 duplicate id, 500 ...), no answer at
  /// all, or a 2xx whose body isn't a valid order.
  Future<Order> placeOrder(Order order) => _orderCall(
    'POST /orders',
    () => _client.post(
      Uri.parse('$_baseUrl/orders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(order.toJson()),
    ),
  );

  /// Changes an order's status (`PATCH /orders/{id}`) and returns the
  /// updated order. Throws [OrderRequestException] like [placeOrder]
  /// (404 for an unknown id).
  Future<Order> updateStatus(String id, OrderStatus status) => _orderCall(
    'PATCH /orders/{id}',
    () => _client.patch(
      // Ids come from whoever placed the order, so encode it: a `/`, `?` or
      // `%` in an id must not change the path or query.
      Uri(path: '$_baseUrl/orders/${Uri.encodeComponent(id)}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status.name}),
    ),
  );

  /// Customer: switches an unpaid (or just expired) transfer order to cash
  /// (`POST /orders/{id}/switch-to-cash`). Errors like [updateStatus]; 409
  /// means too late or the wrong state.
  Future<Order> switchToCash(String id) =>
      _paymentCall('POST /orders/{id}/switch-to-cash', id, 'switch-to-cash');

  /// Customer: asks for a fresh payment window on an expired transfer order
  /// (`POST /orders/{id}/renew-payment`). 409 means too late or the wrong
  /// state; 503 means bank transfer isn't set up.
  Future<Order> renewPayment(String id) =>
      _paymentCall('POST /orders/{id}/renew-payment', id, 'renew-payment');

  /// Staff: switches an unpaid or expired order to cash
  /// (`POST /orders/{id}/staff-switch-to-cash`). [staffHeaders] are sent as
  /// request headers only; they are never stored, logged or put in an error.
  Future<Order> staffSwitchToCash(
    String id, {
    required Map<String, String> staffHeaders,
  }) => _paymentCall(
    'POST /orders/{id}/staff-switch-to-cash',
    id,
    'staff-switch-to-cash',
    staffHeaders: staffHeaders,
  );

  /// Staff: confirms the bank transfer arrived
  /// (`POST /orders/{id}/confirm-payment`). Headers as for
  /// [staffSwitchToCash]. 409 includes an expired (cancelled) order.
  Future<Order> confirmPayment(
    String id, {
    required Map<String, String> staffHeaders,
  }) => _paymentCall(
    'POST /orders/{id}/confirm-payment',
    id,
    'confirm-payment',
    staffHeaders: staffHeaders,
  );

  /// One `POST /orders/{id}/<action>` call with no body. Ids are encoded like
  /// in [updateStatus].
  Future<Order> _paymentCall(
    String what,
    String id,
    String action, {
    Map<String, String>? staffHeaders,
  }) => _orderCall(
    what,
    () => _client.post(
      Uri(path: '$_baseUrl/orders/${Uri.encodeComponent(id)}/$action'),
      headers: staffHeaders,
    ),
  );

  /// Runs one order request and parses the order it returns, turning every
  /// kind of failure into one [OrderRequestException], so UI code catches a
  /// single type. The response body is never copied into the message: the
  /// server's text isn't meant for customers.
  static Future<Order> _orderCall(
    String what,
    Future<http.Response> Function() send,
  ) async {
    final http.Response response;
    try {
      response = await send();
    } on http.ClientException {
      throw OrderRequestException('$what: no answer from the server');
    }
    final status = response.statusCode;
    if (status < 200 || status > 299) {
      throw OrderRequestException(
        '$what failed with HTTP $status',
        statusCode: status,
      );
    }
    // Bad JSON is a FormatException, a wrong type a TypeError, and a status
    // this app doesn't know (`OrderStatus.values.byName`) an ArgumentError.
    OrderRequestException invalid() => OrderRequestException(
      '$what returned an invalid order',
      statusCode: status,
    );
    try {
      return Order.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } on FormatException {
      throw invalid();
    } on TypeError {
      throw invalid();
    } on ArgumentError {
      throw invalid();
    }
  }

  /// Where [item]'s picture is served (`/api/images/<name>`), or null when
  /// it has none. Relative, so it stays same-origin through Caddy and in
  /// deploy. The name is checked again here, so an item built in code with
  /// a bad name gets no URL rather than a strange one.
  static String? imageUrlFor(MenuItem item) {
    final image = item.image;
    if (image == null || !menuImageName.hasMatch(image)) return null;
    return '$_baseUrl/images/$image';
  }

  /// The menu, in the order the backend lists it.
  ///
  /// Anything but 200 throws an [http.ClientException]. A body that isn't a JSON list
  /// of valid items with unique ids throws a [FormatException] (see
  /// [MenuItem.fromJson]).
  Future<List<MenuItem>> fetchMenu() async {
    final response = await _client.get(Uri.parse('$_baseUrl/menu'));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'GET /menu failed with HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('GET /menu must return a JSON list');
    }
    final items = decoded.map(MenuItem.fromJson).toList();
    // Items are equal by id, so duplicates would silently merge in the cart.
    if (items.map((i) => i.id).toSet().length != items.length) {
      throw const FormatException('GET /menu returned duplicate item ids');
    }
    return items;
  }

  /// The toppings foods can take. Same checks as [fetchMenu]: anything but
  /// 200 throws an [http.ClientException]; a body that isn't a JSON list of
  /// valid toppings with unique ids throws a [FormatException].
  Future<List<Topping>> fetchToppings() async {
    final response = await _client.get(Uri.parse('$_baseUrl/toppings'));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'GET /toppings failed with HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('GET /toppings must return a JSON list');
    }
    final toppings = decoded.map(Topping.fromJson).toList();
    if (toppings.map((t) => t.id).toSet().length != toppings.length) {
      throw const FormatException('GET /toppings returned duplicate ids');
    }
    return toppings;
  }

  /// Infinite stream of server-side Order events via Server-Sent Events.
  ///
  /// SSE wire format is lines of `data: <json>\n\n` separated by blank
  /// lines. We buffer bytes, split on `\n\n`, pick out the `data:` lines,
  /// and yield parsed Orders. Comments (`:` lines) and ping events are
  /// ignored.
  ///
  /// Resilience: if the connection drops (network blip, backend restart),
  /// we wait 2s and reconnect. A real app should use exponential backoff
  /// and a max retry budget.
  Stream<Order> streamUpdates() async* {
    while (true) {
      try {
        final request = http.Request(
          'GET',
          Uri.parse('$_baseUrl/orders/stream'),
        );
        final response = await _client.send(request);
        if (response.statusCode != 200) {
          throw http.ClientException('SSE status ${response.statusCode}');
        }
        var buffer = '';
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          buffer += chunk;
          while (buffer.contains('\n\n')) {
            final eventEnd = buffer.indexOf('\n\n');
            final rawEvent = buffer.substring(0, eventEnd);
            buffer = buffer.substring(eventEnd + 2);
            for (final line in rawEvent.split('\n')) {
              if (!line.startsWith('data: ')) continue;
              final payload = line.substring(6);
              // One bad event is skipped; the stream carries on, so orders
              // that arrive after it in the same chunk aren't lost.
              Object? decoded;
              try {
                decoded = jsonDecode(payload);
              } on FormatException {
                if (kDebugMode) debugPrint('Skipped an unreadable event');
                continue;
              }
              final order = _parseOrder(decoded);
              if (order != null) yield order;
            }
          }
        }
      } catch (_) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }
}

/// A `placeOrder` or `updateStatus` call that didn't succeed.
///
/// [message] is for developers (logs, test failures). Never show it to
/// customers or staff: UI code shows its own short fixed text instead.
class OrderRequestException implements Exception {
  const OrderRequestException(this.message, {this.statusCode});

  final String message;

  /// The HTTP status the server answered with, or null when there was no
  /// answer at all (backend down, network error).
  final int? statusCode;

  @override
  String toString() => 'OrderRequestException: $message';
}
