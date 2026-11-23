import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_lo.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('lo'),
    Locale('ru'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// Title of the customer app (browser tab, task switcher).
  ///
  /// In vi, this message translates to:
  /// **'Đặt Món'**
  String get appTitleCustomer;

  /// Title of the restaurant (staff) app.
  ///
  /// In vi, this message translates to:
  /// **'Đặt Món — Nhà hàng'**
  String get appTitleRestaurant;

  /// Order status chip: waiting for the customer to pay.
  ///
  /// In vi, this message translates to:
  /// **'Chờ thanh toán'**
  String get statusAwaitingPayment;

  /// Order status chip: the kitchen is preparing the order.
  ///
  /// In vi, this message translates to:
  /// **'Đang chuẩn bị'**
  String get statusPreparing;

  /// Order status chip: ready for pickup.
  ///
  /// In vi, this message translates to:
  /// **'Sẵn sàng lấy hàng'**
  String get statusReady;

  /// Order status chip: handed over to the customer.
  ///
  /// In vi, this message translates to:
  /// **'Đã giao'**
  String get statusDelivered;

  /// Order status chip: cancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã hủy'**
  String get statusCancelled;

  /// Payment method label: cash.
  ///
  /// In vi, this message translates to:
  /// **'Tiền mặt'**
  String get paymentCash;

  /// Payment method label: bank transfer.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển khoản'**
  String get paymentBankTransfer;

  /// Button: close a dialog without doing anything.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get commonCancel;

  /// Button: confirm a dialog.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get commonConfirm;

  /// Button: save a change.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get commonSave;

  /// Button: try a failed action again.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get commonRetry;

  /// Button: download the file.
  ///
  /// In vi, this message translates to:
  /// **'Tải xuống'**
  String get commonDownload;

  /// Title of the staff login dialog.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập nhân viên'**
  String get staffLoginTitle;

  /// Field label: staff ID.
  ///
  /// In vi, this message translates to:
  /// **'Mã nhân viên'**
  String get staffIdLabel;

  /// Field label: staff password.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu nhân viên'**
  String get staffPasswordLabel;

  /// Error: the staff ID or password has characters browsers cannot send in a header.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ dùng chữ không dấu, số và ký hiệu thông thường'**
  String get staffPlainCharsError;

  /// Error: wrong staff ID or password.
  ///
  /// In vi, this message translates to:
  /// **'Sai mã nhân viên hoặc mật khẩu'**
  String get staffWrongCredentials;

  /// Error: too many wrong staff logins, no wait time known.
  ///
  /// In vi, this message translates to:
  /// **'Thử sai quá nhiều lần. Vui lòng thử lại sau.'**
  String get tooManyTriesLater;

  /// Error: too many wrong staff logins; {seconds} is how long to wait.
  ///
  /// In vi, this message translates to:
  /// **'Thử sai quá nhiều lần. Thử lại sau {seconds} giây.'**
  String tooManyTriesWait(int seconds);

  /// Title of the export-month dialog.
  ///
  /// In vi, this message translates to:
  /// **'Xuất đơn hàng theo tháng'**
  String get exportTitle;

  /// Field label: month to export.
  ///
  /// In vi, this message translates to:
  /// **'Tháng'**
  String get exportMonthLabel;

  /// Field label: which report to export.
  ///
  /// In vi, this message translates to:
  /// **'Loại báo cáo'**
  String get exportReportLabel;

  /// Report choice: daily summary spreadsheet.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo tổng hợp theo ngày (Excel)'**
  String get exportSummaryOption;

  /// Report choice: one row per order for the month.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết từng đơn trong tháng (Excel)'**
  String get exportDetailOption;

  /// Report choice: one row per order line (CSV).
  ///
  /// In vi, this message translates to:
  /// **'Danh sách dòng món (CSV)'**
  String get exportLinesOption;

  /// Error: the server has staff export switched off.
  ///
  /// In vi, this message translates to:
  /// **'Chức năng xuất dữ liệu đang tắt trên máy chủ'**
  String get exportDisabled;

  /// Error: the shop details are not set up on the server.
  ///
  /// In vi, this message translates to:
  /// **'Chưa cài đặt thông tin quán trên máy chủ'**
  String get exportNotConfigured;

  /// Error: the export failed; try again.
  ///
  /// In vi, this message translates to:
  /// **'Không thể xuất dữ liệu. Thử lại.'**
  String get exportFailed;

  /// Title of the restaurant orders screen.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách đơn hàng'**
  String get ordersTitle;

  /// Message when there are no orders yet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có đơn hàng nào. Đang chờ khách…'**
  String get ordersEmpty;

  /// Tooltip of the app-bar button that opens the menu editor.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa thực đơn'**
  String get ordersEditMenuTooltip;

  /// Tooltip of the app-bar button that opens the export dialog.
  ///
  /// In vi, this message translates to:
  /// **'Xuất đơn hàng theo tháng'**
  String get ordersExportTooltip;

  /// Snackbar: a new order arrived from {customerName}.
  ///
  /// In vi, this message translates to:
  /// **'Đơn mới từ {customerName}'**
  String orderNewFrom(String customerName);

  /// Snackbar: a new order from {customerName} that still waits for a bank transfer.
  ///
  /// In vi, this message translates to:
  /// **'Đơn mới từ {customerName} — chờ chuyển khoản'**
  String orderNewFromWaitingTransfer(String customerName);

  /// Snackbar: changing an order status failed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể cập nhật đơn hàng. Thử lại.'**
  String get orderUpdateFailed;

  /// Title of an order card; {shortId} is the last 4 characters of the order id.
  ///
  /// In vi, this message translates to:
  /// **'Đơn #{shortId} — {customerName}'**
  String orderCardTitle(String shortId, String customerName);

  /// Total of an order; {total} is already formatted money (for example 25.000 VNĐ).
  ///
  /// In vi, this message translates to:
  /// **'Tổng: {total}'**
  String orderTotal(String total);

  /// Button: mark a preparing order as ready.
  ///
  /// In vi, this message translates to:
  /// **'Đánh dấu sẵn sàng'**
  String get orderMarkReady;

  /// Button: mark a ready order as delivered.
  ///
  /// In vi, this message translates to:
  /// **'Đánh dấu đã giao'**
  String get orderMarkDelivered;

  /// Text on an order card that has not been paid yet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thanh toán'**
  String get orderUnpaid;

  /// Text on an unpaid transfer order: the transfer content (reference) the customer must type, for example DH482913.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung chuyển khoản: {reference}'**
  String orderTransferContent(String reference);

  /// Text on an order whose payment window ran out.
  ///
  /// In vi, this message translates to:
  /// **'Hết hạn thanh toán'**
  String get orderPaymentExpired;

  /// Button: staff confirm the bank transfer arrived.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhận chuyển khoản'**
  String get orderConfirmTransferReceived;

  /// Button: staff switch an unpaid transfer order to cash.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển sang tiền mặt'**
  String get orderSwitchToCash;

  /// Snackbar: the payment action is switched off on the server.
  ///
  /// In vi, this message translates to:
  /// **'Chức năng đang tắt trên máy chủ'**
  String get payDisabled;

  /// Snackbar: too many wrong staff logins, try later.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại sau.'**
  String get payTryLater;

  /// Snackbar: another device already handled this order.
  ///
  /// In vi, this message translates to:
  /// **'Đơn này đã được xử lý'**
  String get payConflict;

  /// Snackbar: a payment action failed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể cập nhật. Thử lại.'**
  String get payFailed;

  /// Title of the menu editing screen.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa thực đơn'**
  String get menuEditTitle;

  /// Error: the menu could not be loaded.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được thực đơn.'**
  String get menuLoadFailed;

  /// Message when the menu has no items.
  ///
  /// In vi, this message translates to:
  /// **'Thực đơn đang trống.'**
  String get menuEmpty;

  /// Stock text of a menu item that is available.
  ///
  /// In vi, this message translates to:
  /// **'Còn hàng'**
  String get menuInStock;

  /// Stock text of a menu item that is sold out.
  ///
  /// In vi, this message translates to:
  /// **'Hết hàng'**
  String get menuSoldOut;

  /// Second line of a menu row: {price} is formatted money, {stock} is the stock text.
  ///
  /// In vi, this message translates to:
  /// **'{price} · {stock}'**
  String menuItemSubtitle(String price, String stock);

  /// Tooltip of the edit-price button of the menu item {name}.
  ///
  /// In vi, this message translates to:
  /// **'Sửa giá {name}'**
  String menuEditPriceTooltip(String name);

  /// Screen-reader label of the in-stock switch of the menu item {name}.
  ///
  /// In vi, this message translates to:
  /// **'Còn hàng: {name}'**
  String menuInStockSemantics(String name);

  /// Title of the edit-price dialog for the menu item {name}.
  ///
  /// In vi, this message translates to:
  /// **'Sửa giá {name}'**
  String menuEditPriceTitle(String name);

  /// Field label: price in Vietnamese đồng.
  ///
  /// In vi, this message translates to:
  /// **'Giá (VNĐ)'**
  String get menuPriceLabel;

  /// Error under the price field: not a whole number from 0 to 1,000,000.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số nguyên từ 0 đến 1.000.000'**
  String get menuPriceRangeError;

  /// Error after a save: the server refused the price.
  ///
  /// In vi, this message translates to:
  /// **'Giá không hợp lệ. Nhập số nguyên từ 0 đến 1.000.000'**
  String get menuPriceInvalid;

  /// Error: menu editing is switched off on the server.
  ///
  /// In vi, this message translates to:
  /// **'Chức năng sửa thực đơn đang tắt trên máy chủ'**
  String get menuEditingDisabled;

  /// Error: the menu item no longer exists on the server.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy món này. Hãy tải lại trang.'**
  String get menuItemNotFound;

  /// Error: the menu change could not be saved.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được. Thử lại.'**
  String get menuSaveFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ja',
    'ko',
    'lo',
    'ru',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'lo':
      return AppLocalizationsLo();
    case 'ru':
      return AppLocalizationsRu();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
