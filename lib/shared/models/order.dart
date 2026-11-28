import 'display_text.dart';

/// The order lifecycle. A cash order starts `preparing`; a bank-transfer
/// order starts `awaiting_payment` and moves on through the payment routes.
/// Later steps happen on the restaurant side via
/// [OrderRepository.updateStatus]. `delivered` and `cancelled` are terminal
/// (except that an order cancelled by the payment expiry can be renewed or
/// switched to cash within a window the server decides).
///
/// `finished` ("Đã phục vụ") is being added to replace `ready` and
/// `delivered`; those two stay in this enum until the cleanup task removes
/// them, and screens treat `finished` like `delivered` until then.
///
/// Keep in sync by hand with the backend's status list (see CLAUDE.md).
enum OrderStatus {
  // ignore: constant_identifier_names
  awaiting_payment,
  preparing,
  ready,
  delivered,
  finished,
  cancelled,
}

/// How an order is paid. Keep in sync with the backend (`cash`,
/// `bank_transfer`).
// ignore: constant_identifier_names
enum PaymentMethod { cash, bank_transfer }

/// A topping chosen for one order line, with the price it had when ordered.
class OrderTopping {
  /// The topping's menu id. Null only in orders stored before toppings
  /// carried ids; new orders from the app always set it.
  final String? id;
  final String name;

  /// VND, whole number (never cents).
  final double price;

  const OrderTopping({this.id, required this.name, required this.price});

  /// Shape sent as one entry of an [OrderItem]'s `toppings` list at POST
  /// /orders. Omits `id` when null, matching [fromJson].
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'price': price,
  };

  /// Parses one topping from an order's `toppings` list (GET /orders, SSE
  /// events). `id` is optional for orders stored before toppings carried one.
  factory OrderTopping.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('order topping must be a JSON object');
    }
    final name = json['name'];
    final price = json['price'];
    if (name is! String) {
      throw const FormatException('order topping name must be a string');
    }
    if (price is! num || !price.isFinite || price < 0) {
      throw const FormatException(
        'order topping price must be a finite number of at least 0',
      );
    }
    return OrderTopping(
      id: _optionalId(json, 'order topping'),
      // Customer-chosen text shown to restaurant staff: cleaned like menu
      // names (no fake line breaks, no hidden or direction-changing marks).
      name: displayText(name),
      price: price.toDouble(),
    );
  }
}

/// One line item within an [Order].
///
/// [price] is the base price of the dish, without toppings. One unit costs
/// `price` plus the toppings' prices; see [subtotal].
class OrderItem {
  /// The menu item's id (JSON key `id`). Null only in orders stored before
  /// items carried ids; new orders from the app always set it.
  final String? menuItemId;
  final String name;
  final int quantity;

  /// VND, whole number (never cents). Base price of the dish, without
  /// toppings — see the class doc above.
  final double price;
  final List<OrderTopping> toppings;

  OrderItem({
    this.menuItemId,
    required this.name,
    required this.quantity,
    required this.price,
    this.toppings = const [],
  });

  /// The price of one unit: the dish plus its toppings.
  double get unitPrice =>
      toppings.fold(price, (sum, topping) => sum + topping.price);

  double get subtotal => unitPrice * quantity;

  /// Shape sent to the backend at POST /orders. A plain item (no id, no
  /// toppings) is exactly what it was before toppings existed.
  Map<String, dynamic> toJson() => {
    if (menuItemId != null) 'id': menuItemId,
    'name': name,
    'quantity': quantity,
    'price': price,
    if (toppings.isNotEmpty) 'toppings': [for (final t in toppings) t.toJson()],
  };

  /// Inverse of [toJson]; used when parsing GET /orders and SSE events.
  /// Orders stored before toppings existed have no `id` and no `toppings`;
  /// both are optional.
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final rawToppings = json['toppings'];
    if (json.containsKey('toppings') && rawToppings is! List) {
      throw const FormatException('order item toppings must be a list');
    }
    return OrderItem(
      menuItemId: _optionalId(json, 'order item'),
      name: displayText(json['name'] as String),
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      toppings: [
        for (final t in (rawToppings as List?) ?? const [])
          OrderTopping.fromJson(t),
      ],
    );
  }
}

/// Reads an optional `id`: missing means null (an older order); present
/// must be a non-empty string.
String? _optionalId(Map<String, dynamic> json, String what) {
  if (!json.containsKey('id')) return null;
  final id = json['id'];
  if (id is! String || id.isEmpty) {
    throw FormatException('$what id must be a non-empty string');
  }
  return id;
}

/// An order placed by a customer.
///
/// Immutable — status changes produce a new instance via [copyWith]. The id
/// is a millisecond timestamp generated on the customer at placement time;
/// good enough for a dev prototype, not for production (collisions possible,
/// not globally unique). A real backend would assign the id server-side.
class Order {
  final String id;
  final String customerName;
  final List<OrderItem> items;
  final OrderStatus status;
  final DateTime placedAt;
  final PaymentMethod paymentMethod;

  /// When an unpaid bank-transfer order expires (UTC), set by the server.
  /// Never sent by the app: [toJson] leaves it out. Kept on an order that
  /// was cancelled by expiry (see [expiredUnpaid]).
  final DateTime? paymentDueAt;

  /// How long after [paymentDueAt] the customer can still renew or switch
  /// to cash. The server decides; this is only for display.
  static const renewWindow = Duration(minutes: 15);

  Order({
    required this.id,
    required this.customerName,
    required this.items,
    required this.status,
    required this.placedAt,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentDueAt,
  });

  /// True for an order the server cancelled because the transfer wasn't made
  /// in time (a staff cancel clears [paymentDueAt]).
  bool get expiredUnpaid =>
      status == OrderStatus.cancelled &&
      paymentMethod == PaymentMethod.bank_transfer &&
      paymentDueAt != null;

  /// The end of the renew / switch-to-cash window of an expired order, else
  /// null. For display only.
  DateTime? get renewableUntil =>
      expiredUnpaid ? paymentDueAt!.add(renewWindow) : null;

  double get total => items.fold(0, (sum, item) => sum + item.subtotal);

  /// Returns a copy with the given fields replaced. [paymentDueAt] can't be
  /// cleared to null with this; build a new [Order] for that.
  Order copyWith({
    OrderStatus? status,
    PaymentMethod? paymentMethod,
    DateTime? paymentDueAt,
  }) => Order(
    id: id,
    customerName: customerName,
    items: items,
    status: status ?? this.status,
    placedAt: placedAt,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    paymentDueAt: paymentDueAt ?? this.paymentDueAt,
  );

  /// Shape sent to the backend at POST /orders. [paymentDueAt] is left out
  /// on purpose: the server sets it and rejects any order that sends it.
  Map<String, dynamic> toJson() => {
    'id': id,
    'customerName': customerName,
    'items': items.map((i) => i.toJson()).toList(),
    'status': status.name,
    'placedAt': placedAt.toIso8601String(),
    'paymentMethod': paymentMethod.name,
    // paymentDueAt is never sent: the server owns it (an unknown field is a
    // 400 at POST /orders).
  };

  /// Inverse of [toJson], plus the server-only fields: parses one order from
  /// GET /orders, a PATCH reply, or an SSE event.
  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    customerName: displayText(json['customerName'] as String),
    items: (json['items'] as List)
        .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
        .toList(),
    status: OrderStatus.values.byName(json['status'] as String),
    placedAt: DateTime.parse(json['placedAt'] as String),
    paymentMethod: _readPaymentMethod(json),
    paymentDueAt: _readPaymentDueAt(json),
  );
}

/// A missing `paymentMethod` is cash (orders stored before payment methods);
/// anything present must be a known method name.
PaymentMethod _readPaymentMethod(Map<String, dynamic> json) {
  if (!json.containsKey('paymentMethod')) return PaymentMethod.cash;
  final raw = json['paymentMethod'];
  for (final method in PaymentMethod.values) {
    if (raw == method.name) return method;
  }
  throw const FormatException('order paymentMethod is not a known method');
}

/// Null or missing means no deadline; a string is parsed as an instant (UTC).
DateTime? _readPaymentDueAt(Map<String, dynamic> json) {
  final raw = json['paymentDueAt'];
  if (raw == null) return null;
  if (raw is! String) {
    throw const FormatException('order paymentDueAt must be a string');
  }
  return DateTime.parse(raw).toUtc();
}

/// Human-readable labels for status chips and snackbars. Kept separate from
/// the enum so UI copy can change without touching the data layer.
extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
    OrderStatus.awaiting_payment => 'Chờ thanh toán',
    OrderStatus.preparing => 'Đang chuẩn bị',
    OrderStatus.ready => 'Sẵn sàng lấy hàng',
    OrderStatus.delivered => 'Đã giao',
    OrderStatus.finished => 'Đã phục vụ',
    OrderStatus.cancelled => 'Đã hủy',
  };
}

/// Labels for the payment method, shown to customers and staff.
extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.cash => 'Tiền mặt',
    PaymentMethod.bank_transfer => 'Chuyển khoản',
  };
}
