import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../shared/api/order_api_client.dart';
import '../../shared/api/order_repository.dart';
import '../../shared/l10n.dart';
import '../../shared/models/order.dart';
import '../../shared/money.dart';
import '../api/payment_client.dart';

/// The end of an expired order's renew / switch-to-cash window, or null when
/// the order isn't expired or the date is out of range (then it counts as not
/// renewable). Shared with the menu banner.
DateTime? safeRenewableUntil(Order order) {
  try {
    return order.renewableUntil;
  } catch (_) {
    // DateTime.add throws for dates past the supported range.
    return null;
  }
}

/// The bank-transfer page for one order.
///
/// It watches the order in [OrderRepository] and picks a view from it (see
/// the `_body` method). The QR is only on screen while the order is
/// `awaiting_payment` and the deadline hasn't passed: a QR already scanned
/// can't be revoked at the bank, so the page never keeps one longer.
///
/// Leaving the page never changes the order.
class PaymentQrPage extends StatefulWidget {
  /// [paymentClient] and [now] are for tests; the app uses a real client and
  /// the phone's clock.
  const PaymentQrPage({
    super.key,
    required this.orderId,
    this.paymentClient,
    this.now = DateTime.now,
  });

  final String orderId;
  final PaymentClient? paymentClient;
  final DateTime Function() now;

  @override
  State<PaymentQrPage> createState() => _PaymentQrPageState();
}

/// What the last customer action said, shown above the buttons.
enum _Notice { failed, unavailable, changed }

class _PaymentQrPageState extends State<PaymentQrPage> {
  /// A hung request must not leave the customer on a spinner.
  static const _requestTimeout = Duration(seconds: 15);

  /// Wait before the one-shot re-read after the deadline.
  static const _recheckDelay = Duration(seconds: 2);

  /// How far the QR's deadline may differ from the order's before the QR
  /// counts as belonging to another payment window.
  static const _dueTolerance = Duration(seconds: 5);

  final _repo = OrderRepository.instance;
  PaymentClient? _ownClient;
  late final PaymentClient _client =
      widget.paymentClient ?? (_ownClient = PaymentClient());

  Timer? _timer;

  /// One-shot re-read after the deadline passed with no news from the server.
  Timer? _recheckTimer;

  /// The deadline we already scheduled (or did) a re-read for.
  DateTime? _recheckedDue;

  PaymentQr? _qr;
  bool _qrFailed = false;

  /// The deadline the current QR (or the request for it) is for. A different
  /// deadline in the repository (a renewal) means a new QR is needed.
  DateTime? _qrDue;

  /// Drops answers of requests that were replaced or cleared meanwhile.
  int _qrToken = 0;

  bool _busy = false;
  _Notice? _notice;

  /// The server answered 409: it is too late, whatever the phone clock says.
  bool _serverSaysTooLate = false;

  /// What the order looked like at the last notification, to notice changes.
  (OrderStatus, PaymentMethod, DateTime?)? _snapshot;

  Order? get _order {
    for (final order in _repo.orders) {
      if (order.id == widget.orderId) return order;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _snapshot = _snapshotOf(_order);
    _repo.addListener(_onRepoChanged);
    _sync();
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChanged);
    _timer?.cancel();
    _recheckTimer?.cancel();
    _qrToken++;
    _ownClient?.close();
    super.dispose();
  }

  (OrderStatus, PaymentMethod, DateTime?)? _snapshotOf(Order? order) =>
      order == null
      ? null
      : (order.status, order.paymentMethod, order.paymentDueAt);

  void _onRepoChanged() {
    if (!mounted) return;
    final snapshot = _snapshotOf(_order);
    if (snapshot != _snapshot) {
      _snapshot = snapshot;
      // Something new happened to the order: an old 409 no longer applies.
      _serverSaysTooLate = false;
      _notice = null;
    }
    setState(_sync);
  }

  bool _isPayable(Order? order, DateTime now) =>
      order != null &&
      order.status == OrderStatus.awaiting_payment &&
      order.paymentMethod == PaymentMethod.bank_transfer &&
      order.paymentDueAt != null &&
      now.isBefore(order.paymentDueAt!);

  bool _isRenewable(Order? order, DateTime now) {
    if (order == null || !order.expiredUnpaid) return false;
    final until = safeRenewableUntil(order);
    return until != null && !now.isAfter(until);
  }

  /// Brings the QR and the timer in line with the order and the clock.
  /// Called after every change of either; never schedules a rebuild itself.
  void _sync() {
    final order = _order;
    final now = widget.now();
    final payable = _isPayable(order, now);
    if (!payable) {
      _dropQr();
    } else if (_qrDue != order!.paymentDueAt) {
      _dropQr();
      unawaited(_fetchQr(order.paymentDueAt!));
    }
    // Past the deadline and still `awaiting_payment`: the stream may be late
    // or down, so ask the server once, 2 s later.
    final checking =
        order != null &&
        order.status == OrderStatus.awaiting_payment &&
        order.paymentDueAt != null &&
        !payable;
    if (!checking) {
      _recheckTimer?.cancel();
      _recheckTimer = null;
    } else if (_recheckTimer == null && _recheckedDue != order.paymentDueAt) {
      _recheckedDue = order.paymentDueAt;
      _recheckTimer = Timer(_recheckDelay, () {
        _recheckTimer = null;
        unawaited(_refresh());
      });
    }
    // The clock only matters while a deadline is ahead of us.
    final needsTimer = payable || _isRenewable(order, now);
    if (needsTimer && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(_sync);
      });
    } else if (!needsTimer) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _dropQr() {
    _qrToken++;
    _qr = null;
    _qrDue = null;
    _qrFailed = false;
  }

  /// Fetches the QR for the window ending at [due]. Callers have already
  /// cleared the old one.
  Future<void> _fetchQr(DateTime due) async {
    final token = ++_qrToken;
    _qrDue = due;
    _qrFailed = false;
    PaymentQr? qr;
    try {
      qr = await _client.fetchQr(widget.orderId).timeout(_requestTimeout);
      // A QR for another window than the one we asked for isn't shown; the
      // repository will bring the matching deadline and trigger a new fetch.
      if (qr.dueAt.difference(due).abs() > _dueTolerance) qr = null;
    } on Exception {
      // PaymentException, TimeoutException: one short message, with Retry.
      qr = null;
    }
    if (!mounted || token != _qrToken) return;
    setState(() {
      _qr = qr;
      _qrFailed = qr == null;
    });
  }

  void _retryQr() {
    final order = _order;
    if (!_isPayable(order, widget.now())) return;
    setState(() {
      _dropQr();
      unawaited(_fetchQr(order!.paymentDueAt!));
    });
  }

  /// Re-reads the order list once; never throws (the repository swallows
  /// errors, and a hung request is cut off by the timeout).
  Future<void> _refresh() async {
    try {
      await _repo.refresh().timeout(_requestTimeout);
    } on Exception {
      // Nothing to do: the page keeps what it has.
    }
  }

  /// The "Kiểm tra lại" button.
  Future<void> _recheck() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sync();
    });
  }

  /// Runs a customer action with the buttons disabled and a timeout.
  Future<void> _act(
    Future<void> Function(String id) call, {
    bool renew = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    _Notice? notice;
    var tooLate = false;
    try {
      await call(widget.orderId).timeout(_requestTimeout);
    } on OrderRequestException catch (e) {
      if (e.statusCode == 409) {
        // The order changed under us, and our copy may be stale (the stream
        // can be late). Re-read it; only an unchanged copy that is expired
        // means "too late", and any other unchanged copy gets a short note.
        final before = _snapshotOf(_order);
        await _refresh();
        if (!mounted) return;
        final after = _order;
        if (_snapshotOf(after) == before) {
          if (after != null && after.expiredUnpaid) {
            tooLate = true;
          } else {
            notice = _Notice.changed;
          }
        }
      } else if (renew && e.statusCode == 503) {
        notice = _Notice.unavailable;
      } else {
        notice = _Notice.failed;
      }
    } on Exception {
      notice = _Notice.failed;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = notice;
      _serverSaysTooLate = tooLate;
      _sync();
    });
  }

  void _switchToCash() => _act(_repo.switchToCash);

  void _renew() => _act(_repo.renewPayment, renew: true);

  void _backToMenu() =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.paymentBankTransfer),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _body(context),
            ),
          ),
        ),
      ),
    );
  }

  /// One view per state of the order. Reads the clock fresh, so a QR can't
  /// outlive its deadline even for the moment before the next timer tick.
  Widget _body(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final order = _order;
    final now = widget.now();
    if (order == null) {
      return _message(context, l10n.customerPayNotFound, withMenuButton: true);
    }
    switch (order.status) {
      case OrderStatus.awaiting_payment:
        if (_isPayable(order, now)) return _qrView(context, order, now);
        // Past the deadline by our clock, or no deadline: the server's event
        // (cancelled) decides what happens next.
        return _message(
          context,
          l10n.customerPayChecking,
          progress: true,
          recheck: true,
          withMenuButton: true,
        );
      case OrderStatus.cancelled:
        if (!order.expiredUnpaid) {
          return _message(
            context,
            l10n.customerPayCancelled,
            withMenuButton: true,
          );
        }
        return _expiredView(context, order, now);
      case OrderStatus.preparing:
      case OrderStatus.ready:
      case OrderStatus.delivered:
      case OrderStatus.finished:
        return _message(
          context,
          order.paymentMethod == PaymentMethod.bank_transfer
              ? l10n.customerPayReceived
              : l10n.customerPayCashOrder,
          icon: Icons.check_circle_outline,
          withMenuButton: true,
        );
    }
  }

  Widget _message(
    BuildContext context,
    String text, {
    bool progress = false,
    IconData? icon,
    bool withMenuButton = false,
    bool recheck = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        if (progress)
          const Center(child: CircularProgressIndicator())
        else if (icon != null)
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (recheck) ...[
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _recheck,
            child: Text(l10n.customerPayRecheck),
          ),
        ],
        if (withMenuButton) ...[
          SizedBox(height: recheck ? 8 : 24),
          if (recheck)
            OutlinedButton(
              onPressed: _backToMenu,
              child: Text(l10n.customerBackToMenu),
            )
          else
            FilledButton(
              onPressed: _backToMenu,
              child: Text(l10n.customerBackToMenu),
            ),
        ],
      ],
    );
  }

  Widget _cashButton(BuildContext context) => FilledButton(
    onPressed: _busy ? null : _switchToCash,
    child: Text(AppLocalizations.of(context)!.customerSwitchToCash),
  );

  Widget _qrView(BuildContext context, Order order, DateTime now) {
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final qr = _qr;
    final remaining = order.paymentDueAt!.difference(now);
    // Round up, so 04:59.4 reads 05:00 and 00:00 only when it is over.
    final seconds = ((remaining.inMilliseconds + 999) ~/ 1000).clamp(0, 86400);
    final countdown =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.customerPayInstruction,
          style: text.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.customerCountdown(countdown),
          key: const Key('payment-countdown'),
          style: text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (qr != null) ...[
          _QrBox(payload: qr.payload),
          const SizedBox(height: 16),
          _detail(l10n.customerBank, qr.bankName),
          _detail(l10n.customerAccountNumber, qr.accountNumber),
          _detail(l10n.customerAccountName, qr.accountName),
          _detail(l10n.customerAmount, formatVnd(qr.amount)),
          _detail(l10n.customerTransferContent, qr.reference),
        ] else if (_qrFailed) ...[
          Text(l10n.customerQrLoadFailed, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _retryQr, child: Text(l10n.commonRetry)),
        ] else
          const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 24),
        Text(l10n.customerCashHint, textAlign: TextAlign.center),
        if (_notice == _Notice.failed) ..._failure(context),
        if (_notice == _Notice.changed) ..._changed(context),
        const SizedBox(height: 8),
        _cashButton(context),
      ],
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        SelectableText(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );

  List<Widget> _changed(BuildContext context) => [
    const SizedBox(height: 8),
    Text(
      AppLocalizations.of(context)!.customerPayChanged,
      textAlign: TextAlign.center,
    ),
  ];

  List<Widget> _failure(BuildContext context) => [
    const SizedBox(height: 8),
    Text(
      AppLocalizations.of(context)!.customerPayActionFailed,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  ];

  /// The order was cancelled by the 5-minute expiry: ask what to do, while
  /// the 15 minutes last.
  Widget _expiredView(BuildContext context, Order order, DateTime now) {
    final l10n = AppLocalizations.of(context)!;
    final until = safeRenewableUntil(order);
    final tooLate = _serverSaysTooLate || until == null || now.isAfter(until);
    if (tooLate) {
      return _message(context, l10n.customerPayTooLate, withMenuButton: true);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.customerPayExpired,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (_notice == _Notice.unavailable) ...[
          const SizedBox(height: 8),
          Text(
            l10n.customerPayTransferUnavailable,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (_notice == _Notice.failed) ..._failure(context),
        const SizedBox(height: 16),
        _cashButton(context),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _renew,
          child: Text(l10n.customerNewQr),
        ),
      ],
    );
  }
}

/// The QR on a white square (scanners need the light margin), as wide as the
/// screen allows up to 240 px.
class _QrBox extends StatelessWidget {
  const _QrBox({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth < 240
              ? constraints.maxWidth
              : 240.0;
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: QrImageView(
              // Keyed by the text, so a new QR is a new widget (and tests
              // can read which text is on screen).
              key: ValueKey<String>(payload),
              data: payload,
              size: side - 16,
              backgroundColor: Colors.white,
              semanticsLabel: AppLocalizations.of(context)!.customerQrSemantics,
            ),
          );
        },
      ),
    );
  }
}
