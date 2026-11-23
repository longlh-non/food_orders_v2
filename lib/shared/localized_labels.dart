import 'l10n.dart';
import 'models/order.dart';

/// Translated names for order statuses and payment methods, read at the UI
/// layer. (`OrderStatus.label` in `lib/shared/models/order.dart` is the old
/// Vietnamese-only text; neither app uses it any more.)
extension OrderStatusText on OrderStatus {
  /// The status in the language of [l10n].
  String localized(AppLocalizations l10n) => switch (this) {
    OrderStatus.awaiting_payment => l10n.statusAwaitingPayment,
    OrderStatus.preparing => l10n.statusPreparing,
    OrderStatus.ready => l10n.statusReady,
    OrderStatus.delivered => l10n.statusDelivered,
    OrderStatus.cancelled => l10n.statusCancelled,
  };
}

/// The payment method in the language of [l10n].
extension PaymentMethodText on PaymentMethod {
  String localized(AppLocalizations l10n) => switch (this) {
    PaymentMethod.cash => l10n.paymentCash,
    PaymentMethod.bank_transfer => l10n.paymentBankTransfer,
  };
}
