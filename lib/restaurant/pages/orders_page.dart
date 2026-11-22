import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/api/order_api_client.dart';
import '../../shared/api/order_repository.dart';
import '../../shared/chime.dart';
import '../../shared/models/order.dart';
import '../../shared/money.dart';
import '../state/staff_credentials.dart';
import '../widgets/staff_login_dialog.dart';
import 'export_month_dialog.dart';

/// The two staff payment actions a card can offer, each a separate backend
/// route (`restaurant-confirm-bank-transfer`).
enum PaymentAction {
  /// "Đã nhận chuyển khoản": the bank transfer arrived, only while the order
  /// is still live and waiting (never on an expired one — a late transfer is
  /// checked and refunded by hand).
  confirm,

  /// "Chuyển sang tiền mặt": make it a cash order, from either a live
  /// waiting order or one the server cancelled by expiry. No time limit for
  /// staff (PAY13).
  switchToCash,
}

/// What a payment action attempt came back as, after any staff-login retry.
enum _PayOutcome { ok, disabled, tooManyTries, conflict, other }

/// Internal signal that the server said 401: the credentials just used are
/// wrong. Never shown; the ID and password themselves never travel in it.
class _WrongCredentials implements Exception {
  const _WrongCredentials();
}

String _payOutcomeText(_PayOutcome outcome) => switch (outcome) {
  _PayOutcome.disabled => 'Chức năng đang tắt trên máy chủ',
  _PayOutcome.tooManyTries => 'Thử lại sau.',
  _PayOutcome.conflict => 'Đơn này đã được xử lý',
  _ => 'Không thể cập nhật. Thử lại.',
};

/// The transfer content staff look for in the bank app: `DH` + the last 6
/// digits of the order id (all of them when fewer; non-digits skipped; an id
/// with no digit gets 6 digits from a fixed hash). Mirrors
/// `transferReference` in `backend/lib/vietqr.dart` (the backend can't be
/// imported); keep them in sync by hand.
String transferReference(String orderId) {
  final digits = orderId.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isNotEmpty) {
    return 'DH${digits.length <= 6 ? digits : digits.substring(digits.length - 6)}';
  }
  var hash = 0x811C9DC5; // FNV-1a, 32 bit
  for (final unit in orderId.codeUnits) {
    // hash * 0x01000193 written as hash * 2^24 + hash * 403 so every step
    // stays below 2^53 and gives the same number on web as on the VM.
    final x = hash ^ unit;
    hash = ((x & 0xFF) * 16777216 + x * 403) % 4294967296;
  }
  return 'DH${(hash % 1000000).toString().padLeft(6, '0')}';
}

/// Home screen for the restaurant app.
///
/// Three jobs:
///   1. List incoming orders newest-first with status and payment method.
///   2. Fire a snackbar + play a two-note chime for new work: a new order id
///      that arrives `preparing` (cash) or `awaiting_payment` (transfer), and
///      a transfer order that was already on screen, never rang, and becomes
///      `preparing` after payment. Each id rings at most once.
///   3. Show a live count of orders that need attention (`awaiting_payment`
///      plus `preparing`) as an AppBar badge.
///
/// "New" is decided against [_seenIds], the ids already in the repository
/// when this screen last processed a change. On first mount it is seeded with
/// whatever is already there, so historical orders don't ring on page load.
/// [_awaitingUnrung] holds the seeded ids that were `awaiting_payment`: the
/// only known ids that may still ring (once, when they become `preparing`).
/// An expired or revived order is never in it, so it never rings again.
///
/// The server can show an order as `awaiting_payment` up to 15 s after its
/// deadline, so the screen treats `paymentDueAt <= now` as expired itself
/// (see [_isExpired]); a one-shot timer re-checks at the next deadline.
class OrdersPage extends StatefulWidget {
  /// [now] is the clock used for deadlines and [chime] what rings for new
  /// work; tests pass their own.
  const OrdersPage({
    super.key,
    this.now = DateTime.now,
    this.chime = playChime,
  });

  final DateTime Function() now;
  final void Function() chime;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

/// An unpaid transfer order whose deadline has passed, even if the server
/// hasn't cancelled it yet.
bool _isLapsed(Order o, DateTime now) =>
    o.status == OrderStatus.awaiting_payment &&
    o.paymentDueAt != null &&
    !o.paymentDueAt!.isAfter(now);

/// Shown as expired: cancelled by the server for an unpaid transfer, or
/// lapsed by the clock but not yet swept.
bool _isExpired(Order o, DateTime now) => o.expiredUnpaid || _isLapsed(o, now);

class _OrdersPageState extends State<OrdersPage> {
  final _seenIds = <String>{};
  final _awaitingUnrung = <String>{};
  final _busyPaymentIds = <String>{};
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    final repo = OrderRepository.instance;
    final now = widget.now();
    for (final o in repo.orders) {
      _seenIds.add(o.id);
      if (o.status == OrderStatus.awaiting_payment && !_isLapsed(o, now)) {
        _awaitingUnrung.add(o.id);
      }
    }
    repo.addListener(_onRepoChanged);
    _scheduleExpiry();
  }

  @override
  void dispose() {
    OrderRepository.instance.removeListener(_onRepoChanged);
    _expiryTimer?.cancel();
    super.dispose();
  }

  /// One-shot timer for the nearest future deadline of an awaiting order, so
  /// the card flips to "expired" without waiting for the server.
  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final now = widget.now();
    DateTime? next;
    for (final o in OrderRepository.instance.orders) {
      final due = o.paymentDueAt;
      if (o.status != OrderStatus.awaiting_payment || due == null) continue;
      if (due.isAfter(now) && (next == null || due.isBefore(next))) next = due;
    }
    if (next == null) return;
    _expiryTimer = Timer(
      next.difference(now) + const Duration(milliseconds: 50),
      () {
        if (!mounted) return;
        setState(() {});
        _scheduleExpiry();
      },
    );
  }

  /// Compare the latest repository state against what we've seen and ring
  /// (one chime per tick) for new work, with a plain snackbar per order.
  /// Then update the bookkeeping so nothing rings twice.
  void _onRepoChanged() {
    if (!mounted) return;
    final repo = OrderRepository.instance;
    final now = widget.now();
    final toAnnounce = <Order>[];
    for (final o in repo.orders) {
      if (!_seenIds.contains(o.id)) {
        // A new id rings when it is work for staff right now.
        if (o.status == OrderStatus.preparing ||
            (o.status == OrderStatus.awaiting_payment && !_isLapsed(o, now))) {
          toAnnounce.add(o);
        }
      } else if (_awaitingUnrung.contains(o.id)) {
        // Known transfer order that never rang: paid -> rings once.
        if (o.status == OrderStatus.preparing) {
          toAnnounce.add(o);
          _awaitingUnrung.remove(o.id);
        } else if (o.status != OrderStatus.awaiting_payment) {
          _awaitingUnrung.remove(o.id);
        }
      }
    }
    if (toAnnounce.isNotEmpty) widget.chime();
    for (final order in toAnnounce) {
      final waiting = order.status == OrderStatus.awaiting_payment
          ? ' — chờ chuyển khoản'
          : '';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('New order from ${order.customerName}$waiting'),
            duration: const Duration(seconds: 5),
          ),
        );
    }
    _seenIds.addAll(repo.orders.map((o) => o.id));
    _scheduleExpiry();
    setState(() {});
  }

  /// Asks the backend to move order [id] to [status]. On success the
  /// repository (and the live stream) update the card. On failure staff
  /// see a short fixed message; the order keeps its old status, because the
  /// cache only changes after the server says yes.
  Future<void> _changeStatus(String id, OrderStatus status) async {
    try {
      await OrderRepository.instance.updateStatus(id, status);
    } on OrderRequestException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text("Couldn't update the order. Try again."),
          ),
        );
    }
  }

  /// Runs one payment action with the given credentials and turns every
  /// failure into a fixed outcome. Never shows or logs the server's text.
  Future<_PayOutcome> _sendPaymentAction(
    String id,
    PaymentAction action,
    StaffCredentials credentials,
  ) async {
    try {
      switch (action) {
        case PaymentAction.confirm:
          await OrderRepository.instance.confirmPayment(
            id,
            staffHeaders: credentials.headers,
          );
        case PaymentAction.switchToCash:
          await OrderRepository.instance.staffSwitchToCash(
            id,
            staffHeaders: credentials.headers,
          );
      }
      return _PayOutcome.ok;
    } on OrderRequestException catch (e) {
      return switch (e.statusCode) {
        401 => throw const _WrongCredentials(),
        403 => _PayOutcome.disabled,
        429 => _PayOutcome.tooManyTries,
        409 => _PayOutcome.conflict,
        _ => _PayOutcome.other,
      };
    }
  }

  /// Confirms a transfer or switches an order to cash. Uses the remembered
  /// staff ID and password when they are usable, asking only when needed; a
  /// wrong answer (401) forgets them and asks again. Every other failure
  /// shows a short fixed message, and a 409 also re-reads the repository
  /// (the customer or another staff device may have already changed it).
  Future<void> _doPaymentAction(String id, PaymentAction action) async {
    setState(() => _busyPaymentIds.add(id));
    try {
      var credentials = StaffCredentialsHolder.instance.value;
      String? promptError;
      while (true) {
        if (credentials == null || !credentials.isSendable) {
          if (!mounted) return;
          final entered = await showStaffLoginDialog(
            context,
            initialError: promptError,
          );
          if (entered == null) return; // staff cancelled
          credentials = entered;
        }
        _PayOutcome outcome;
        try {
          outcome = await _sendPaymentAction(id, action, credentials);
        } on _WrongCredentials {
          StaffCredentialsHolder.instance.clear();
          credentials = null;
          promptError = 'Wrong staff ID or password';
          continue;
        }
        if (outcome == _PayOutcome.ok) {
          StaffCredentialsHolder.instance.value = credentials;
          return;
        }
        if (outcome == _PayOutcome.conflict) {
          // Awaited, not fire-and-forget: the refresh's own merge can ring
          // the new-work chime and show its own snackbar (e.g. the order
          // really did move on, paid by someone else) *before* this one, so
          // ours — the direct answer to the tap — is the one staff see
          // last, not silently replaced by it.
          await OrderRepository.instance.refresh();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(_payOutcomeText(outcome))));
        return;
      }
    } finally {
      if (mounted) setState(() => _busyPaymentIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = OrderRepository.instance;
    final orders = repo.orders;
    final now = widget.now();
    // PAY10: unpaid transfers and orders being prepared need attention.
    final activeCount = orders
        .where(
          (o) =>
              o.status == OrderStatus.preparing ||
              (o.status == OrderStatus.awaiting_payment && !_isLapsed(o, now)),
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Orders'),
        actions: [
          IconButton(
            tooltip: 'Export month',
            icon: const Icon(Icons.download),
            onPressed: () => showExportMonthDialog(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Badge(
                label: Text('$activeCount'),
                isLabelVisible: activeCount > 0,
                child: Icon(
                  activeCount > 0
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                ),
              ),
            ),
          ),
        ],
      ),
      body: orders.isEmpty
          ? const Center(child: Text('No orders yet. Waiting for customers…'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _OrderCard(
                order: orders[i],
                now: now,
                onChangeStatus: (next) => _changeStatus(orders[i].id, next),
                onPaymentAction: (action) =>
                    _doPaymentAction(orders[i].id, action),
                busy: _busyPaymentIds.contains(orders[i].id),
              ),
            ),
    );
  }
}

/// Single order row with the status chip, the payment method, the
/// next-action button and, for a transfer order still owed money, the two
/// staff payment buttons.
///
/// The button text and target status come from a small state machine
/// driven by the current status: `preparing` and `ready` have a button;
/// `awaiting_payment`, expired and terminal orders have none here.
///
/// Payment buttons follow the order's current status: a live waiting order
/// gets "Đã nhận chuyển khoản" and "Chuyển sang tiền mặt"; an expired one
/// (cancelled by the 5-minute window) gets only "Chuyển sang tiền mặt", with
/// no time limit for staff — a late transfer is checked and refunded by
/// hand. Any other order (cash, being prepared, ready, delivered, or
/// cancelled on purpose) gets neither.
class _OrderCard extends StatelessWidget {
  final Order order;

  /// Called with the next status when the action button is pressed; the
  /// page does the request and reports a failure.
  final void Function(OrderStatus next) onChangeStatus;

  /// Called when a staff payment button is pressed; the page asks for
  /// credentials if needed, sends the request and reports the result.
  final void Function(PaymentAction action) onPaymentAction;

  /// True while a payment action for this order is in flight, so both
  /// payment buttons disable instead of allowing a second tap.
  final bool busy;

  /// The clock, to treat a lapsed deadline as expired.
  final DateTime now;

  const _OrderCard({
    required this.order,
    required this.onChangeStatus,
    required this.onPaymentAction,
    required this.busy,
    required this.now,
  });

  OrderStatus? get _nextStatus => switch (order.status) {
    OrderStatus.preparing => OrderStatus.ready,
    OrderStatus.ready => OrderStatus.delivered,
    _ => null,
  };

  String get _actionLabel => switch (order.status) {
    OrderStatus.preparing => 'Mark ready',
    OrderStatus.ready => 'Mark delivered',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final next = _nextStatus;
    final expired = _isExpired(order, now);
    final awaiting = order.status == OrderStatus.awaiting_payment && !expired;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #${order.id.length > 4 ? order.id.substring(order.id.length - 4) : order.id} — ${order.customerName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            // Status and payment: status chip, method chip, and for an unpaid transfer the content
            // to look for in the bank app. Wraps on narrow screens.
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(
                    (expired ? OrderStatus.cancelled : order.status).label,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(order.paymentMethod.label),
                  visualDensity: VisualDensity.compact,
                ),
                if (awaiting) ...[
                  const Text('Chưa thanh toán'),
                  Text('Nội dung chuyển khoản: ${transferReference(order.id)}'),
                ],
                if (expired)
                  Text(
                    'Hết hạn thanh toán',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Long names and topping lists wrap instead of pushing
                    // the price off a narrow screen; the kitchen needs the
                    // whole text, so nothing is cut.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.quantity}× ${item.name}'),
                          if (item.toppings.isNotEmpty)
                            Text(
                              [for (final t in item.toppings) '+ ${t.name}']
                                  .join(', '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Already includes the toppings (OrderItem.subtotal).
                    Text(formatVnd(item.subtotal)),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total: ${formatVnd(order.total)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (next != null && !expired)
                  FilledButton(
                    onPressed: () => onChangeStatus(next),
                    child: Text(_actionLabel),
                  ),
              ],
            ),
            if (awaiting || expired) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  // Not for an expired order: a late transfer is checked and
                  // refunded by hand, outside the app (PAY5).
                  if (awaiting)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => onPaymentAction(PaymentAction.confirm),
                      child: const Text('Đã nhận chuyển khoản'),
                    ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => onPaymentAction(PaymentAction.switchToCash),
                    child: const Text('Chuyển sang tiền mặt'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
