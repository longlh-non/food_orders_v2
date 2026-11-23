// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitleCustomer => 'Food Orders';

  @override
  String get appTitleRestaurant => 'Food Orders — Restaurant';

  @override
  String get statusAwaitingPayment => 'Awaiting payment';

  @override
  String get statusPreparing => 'Preparing';

  @override
  String get statusReady => 'Ready for pickup';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentBankTransfer => 'Bank transfer';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonDownload => 'Download';

  @override
  String get staffLoginTitle => 'Staff login';

  @override
  String get staffIdLabel => 'Staff ID';

  @override
  String get staffPasswordLabel => 'Staff password';

  @override
  String get staffPlainCharsError =>
      'Use plain letters, digits and symbols, no accents';

  @override
  String get staffWrongCredentials => 'Wrong staff ID or password';

  @override
  String get tooManyTriesLater => 'Too many wrong tries. Try again later.';

  @override
  String tooManyTriesWait(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Too many wrong tries. Try again in $seconds seconds.',
      one: 'Too many wrong tries. Try again in $seconds second.',
    );
    return '$_temp0';
  }

  @override
  String get exportTitle => 'Export month';

  @override
  String get exportMonthLabel => 'Month';

  @override
  String get exportReportLabel => 'Report type';

  @override
  String get exportSummaryOption => 'Daily summary report (Excel)';

  @override
  String get exportDetailOption =>
      'Details of every order in the month (Excel)';

  @override
  String get exportLinesOption => 'List of order lines (CSV)';

  @override
  String get exportDisabled => 'Export is turned off on the server';

  @override
  String get exportNotConfigured => 'Shop details are not set up on the server';

  @override
  String get exportFailed => 'Could not export the data. Try again.';

  @override
  String get ordersTitle => 'Incoming Orders';

  @override
  String get ordersEmpty => 'No orders yet. Waiting for customers…';

  @override
  String get ordersEditMenuTooltip => 'Edit menu';

  @override
  String get ordersExportTooltip => 'Export month';

  @override
  String orderNewFrom(String customerName) {
    return 'New order from $customerName';
  }

  @override
  String orderNewFromWaitingTransfer(String customerName) {
    return 'New order from $customerName — awaiting bank transfer';
  }

  @override
  String get orderUpdateFailed => 'Couldn\'t update the order. Try again.';

  @override
  String orderCardTitle(String shortId, String customerName) {
    return 'Order #$shortId — $customerName';
  }

  @override
  String orderTotal(String total) {
    return 'Total: $total';
  }

  @override
  String get orderMarkReady => 'Mark ready';

  @override
  String get orderMarkDelivered => 'Mark delivered';

  @override
  String get orderUnpaid => 'Not paid yet';

  @override
  String orderTransferContent(String reference) {
    return 'Transfer reference: $reference';
  }

  @override
  String get orderPaymentExpired => 'Payment expired';

  @override
  String get orderConfirmTransferReceived => 'Transfer received';

  @override
  String get orderSwitchToCash => 'Switch to cash';

  @override
  String get payDisabled => 'This function is turned off on the server';

  @override
  String get payTryLater => 'Try again later.';

  @override
  String get payConflict => 'This order has already been handled';

  @override
  String get payFailed => 'Could not update. Try again.';

  @override
  String get menuEditTitle => 'Edit menu';

  @override
  String get menuLoadFailed => 'Could not load the menu.';

  @override
  String get menuEmpty => 'The menu is empty.';

  @override
  String get menuInStock => 'In stock';

  @override
  String get menuSoldOut => 'Sold out';

  @override
  String menuItemSubtitle(String price, String stock) {
    return '$price · $stock';
  }

  @override
  String menuEditPriceTooltip(String name) {
    return 'Edit price of $name';
  }

  @override
  String menuInStockSemantics(String name) {
    return 'In stock: $name';
  }

  @override
  String menuEditPriceTitle(String name) {
    return 'Edit price of $name';
  }

  @override
  String get menuPriceLabel => 'Price (VND)';

  @override
  String get menuPriceRangeError => 'Enter a whole number from 0 to 1,000,000';

  @override
  String get menuPriceInvalid =>
      'Invalid price. Enter a whole number from 0 to 1,000,000';

  @override
  String get menuEditingDisabled => 'Menu editing is turned off on the server';

  @override
  String get menuItemNotFound => 'Could not find this item. Reload the page.';

  @override
  String get menuSaveFailed => 'Could not save. Try again.';
}
