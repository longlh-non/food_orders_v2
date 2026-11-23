import 'package:flutter/material.dart';

import '../../shared/api/order_api_client.dart';
import '../../shared/api/order_repository.dart';
import '../../shared/l10n.dart';
import '../../shared/models/order.dart';
import '../../shared/money.dart';
import '../api/payment_client.dart';
import '../../shared/localized_labels.dart';
import '../state/cart.dart';
import '../state/my_orders.dart';
import 'payment_qr_page.dart';

/// Review-and-checkout page for the customer's current [Cart].
///
/// Shows editable quantities for each line item, takes the customer's name,
/// and submits via [OrderRepository.placeOrder]. It waits for the server:
/// only when the order is accepted is the id registered with [MyOrders], the
/// cart emptied and the page closed. A failure keeps everything and says so.
class CartPage extends StatefulWidget {
  const CartPage({super.key, this.paymentClient});

  /// Asks the server whether bank transfer is set up. Tests pass a fake with
  /// a mock HTTP client; the app leaves it null and the page makes its own.
  final PaymentClient? paymentClient;

  @override
  State<CartPage> createState() => _CartPageState();
}

/// State for [CartPage]: the name field, the chosen payment method, and the
/// sending / failed flags that drive the button and the error line.
class _CartPageState extends State<CartPage> {
  /// Holds the customer's name; released in [dispose].
  final _nameController = TextEditingController();

  /// True while an order is on its way to the server: the button is
  /// disabled and shows a spinner, which also stops a double tap.
  var _sending = false;

  /// True after the last try failed: shows the error under the total.
  /// Shown inline, not as a SnackBar, because a SnackBar would cover the
  /// button the customer needs to tap to try again.
  var _failed = false;

  /// What the customer picked. Cash is the default, so nobody pays by
  /// transfer by accident.
  var _method = PaymentMethod.cash;

  /// Null while the "is transfer set up?" check runs; then true or false.
  /// A failed check counts as false. It never blocks cash.
  bool? _transferEnabled;

  PaymentClient? _ownClient;

  /// On the failure line, so it can be scrolled into view after a failure.
  final _failureKey = GlobalKey();

  /// Starts the "is bank transfer set up?" check as soon as the page opens.
  @override
  void initState() {
    super.initState();
    _checkTransfer();
  }

  /// Asks the server (network call) whether bank transfer is set up, then
  /// redraws. Any failure counts as "not set up", which falls back to cash.
  Future<void> _checkTransfer() async {
    var enabled = false;
    try {
      final client = widget.paymentClient ?? (_ownClient = PaymentClient());
      enabled = (await client.fetchInfo()).transferEnabled;
    } catch (_) {
      // Any failure (no answer, wrong shape) just leaves transfer off.
    }
    if (!mounted) return;
    setState(() {
      _transferEnabled = enabled;
      if (!enabled) _method = PaymentMethod.cash;
    });
  }

  /// Releases the name controller and, if the page made its own
  /// [PaymentClient], closes it so no HTTP client is left open.
  @override
  void dispose() {
    _ownClient?.close();
    _nameController.dispose();
    super.dispose();
  }

  /// Checks the name, builds the order and sends it to the server, then waits
  /// for the answer. On failure it keeps the cart and shows an error line.
  /// On success it tracks the id in [MyOrders] and empties the cart. A
  /// transfer order then replaces this page with the payment QR page; a cash
  /// order shows a thank-you SnackBar and closes the page.
  Future<void> _placeOrder() async {
    final cart = Cart.instance;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.customerNameRequired),
        ),
      );
      return;
    }
    if (cart.isEmpty) return;

    // A new order (and id) per tap: a failed one never reached the server or
    // was rejected, so a retry starts fresh.
    final transfer = _method == PaymentMethod.bank_transfer;
    final order = Order(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerName: name,
      items: cart.toOrderItems(),
      status: transfer ? OrderStatus.awaiting_payment : OrderStatus.preparing,
      paymentMethod: transfer
          ? PaymentMethod.bank_transfer
          : PaymentMethod.cash,
      placedAt: DateTime.now(),
    );
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      await OrderRepository.instance.placeOrder(order);
    } on OrderRequestException {
      // Keep the cart and the name so the customer can just try again.
      // Never show the exception text: it's for developers.
      if (!mounted) return;
      setState(() {
        _sending = false;
        _failed = true;
      });
      // At large text the new line can land just below the fold: bring it
      // into view once it has been laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _failureKey.currentContext;
        if (mounted && target != null) Scrollable.ensureVisible(target);
      });
      return;
    }

    // Accepted. Track it only now, so a failed order never shows up in the
    // "Đơn của bạn" banner. This happens even if the customer left the page
    // meanwhile: the order exists either way.
    MyOrders.instance.track(order.id);
    cart.clear();
    if (!mounted) return;
    _nameController.clear();
    setState(() => _sending = false);
    if (transfer) {
      // Hand over to the QR page, replacing the cart (it is empty now).
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PaymentQrPage(orderId: order.id),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.customerOrderPlaced(order.customerName),
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  /// The cart screen: one card per line with minus and plus buttons, then the
  /// name field, payment choice, total and order button. The list rebuilds
  /// when the cart changes (`ListenableBuilder`); an empty cart shows a note.
  @override
  Widget build(BuildContext context) {
    final cart = Cart.instance;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.customerCartTitle)),
      body: ListenableBuilder(
        listenable: cart,
        builder: (context, _) {
          if (cart.isEmpty) {
            return Center(child: Text(l10n.customerCartEmpty));
          }
          // One scrollable list for everything (lines, name, total, button,
          // failure text), so nothing can overflow at large text sizes. The
          // button is not pinned: with many lines the customer scrolls to it.
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final MapEntry(key: line, value: qty) in cart.lines.entries)
                Card(
                  child: ListTile(
                    title: Text(line.item.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (line.toppings.isNotEmpty)
                          Text(
                            line.toppings.map((t) => '+ ${t.name}').join('   '),
                          ),
                        Text(
                          l10n.customerPricePerItem(formatVnd(line.unitPrice)),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () => cart.remove(line),
                        ),
                        Text('$qty'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () =>
                              cart.add(line.item, toppings: line.toppings),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.customerNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _paymentChoice(),
              const SizedBox(height: 12),
              // Total above a full-width button (not side by side): at large
              // text "Đặt hàng" alone is wider than a phone.
              Text(
                l10n.customerCartTotal(formatVnd(cart.total)),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  // A live region, so screen readers announce it like
                  // they would a SnackBar.
                  child: Semantics(
                    key: _failureKey,
                    liveRegion: true,
                    child: Text(
                      l10n.customerOrderFailed,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              FilledButton(
                onPressed: _sending ? null : _placeOrder,
                child: _sending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.customerPlaceOrder),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The two choices. Transfer is disabled until the server says it is set up.
  Widget _paymentChoice() {
    final l10n = AppLocalizations.of(context)!;
    final enabled = _transferEnabled == true;
    return RadioGroup<PaymentMethod>(
      groupValue: _method,
      onChanged: (value) {
        if (value == null || _sending) return;
        setState(() => _method = value);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioListTile<PaymentMethod>(
            value: PaymentMethod.cash,
            title: Text(PaymentMethod.cash.localized(l10n)),
          ),
          RadioListTile<PaymentMethod>(
            value: PaymentMethod.bank_transfer,
            enabled: enabled,
            title: Text(PaymentMethod.bank_transfer.localized(l10n)),
            subtitle: _transferEnabled == false
                ? Text(l10n.customerTransferOff)
                : null,
          ),
        ],
      ),
    );
  }
}
