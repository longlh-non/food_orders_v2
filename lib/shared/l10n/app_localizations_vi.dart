// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitleCustomer => 'Đặt Món';

  @override
  String get appTitleRestaurant => 'Đặt Món — Nhà hàng';

  @override
  String get statusAwaitingPayment => 'Chờ thanh toán';

  @override
  String get statusPreparing => 'Đang chuẩn bị';

  @override
  String get statusReady => 'Sẵn sàng lấy hàng';

  @override
  String get statusDelivered => 'Đã giao';

  @override
  String get statusCancelled => 'Đã hủy';

  @override
  String get paymentCash => 'Tiền mặt';

  @override
  String get paymentBankTransfer => 'Chuyển khoản';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get commonConfirm => 'Xác nhận';

  @override
  String get commonSave => 'Lưu';

  @override
  String get commonRetry => 'Thử lại';

  @override
  String get commonDownload => 'Tải xuống';

  @override
  String get staffLoginTitle => 'Đăng nhập nhân viên';

  @override
  String get staffIdLabel => 'Mã nhân viên';

  @override
  String get staffPasswordLabel => 'Mật khẩu nhân viên';

  @override
  String get staffPlainCharsError =>
      'Chỉ dùng chữ không dấu, số và ký hiệu thông thường';

  @override
  String get staffWrongCredentials => 'Sai mã nhân viên hoặc mật khẩu';

  @override
  String get tooManyTriesLater =>
      'Thử sai quá nhiều lần. Vui lòng thử lại sau.';

  @override
  String tooManyTriesWait(int seconds) {
    return 'Thử sai quá nhiều lần. Thử lại sau $seconds giây.';
  }

  @override
  String get exportTitle => 'Xuất đơn hàng theo tháng';

  @override
  String get exportMonthLabel => 'Tháng';

  @override
  String get exportReportLabel => 'Loại báo cáo';

  @override
  String get exportSummaryOption => 'Báo cáo tổng hợp theo ngày (Excel)';

  @override
  String get exportDetailOption => 'Chi tiết từng đơn trong tháng (Excel)';

  @override
  String get exportLinesOption => 'Danh sách dòng món (CSV)';

  @override
  String get exportDisabled => 'Chức năng xuất dữ liệu đang tắt trên máy chủ';

  @override
  String get exportNotConfigured => 'Chưa cài đặt thông tin quán trên máy chủ';

  @override
  String get exportFailed => 'Không thể xuất dữ liệu. Thử lại.';

  @override
  String get ordersTitle => 'Danh sách đơn hàng';

  @override
  String get ordersEmpty => 'Chưa có đơn hàng nào. Đang chờ khách…';

  @override
  String get ordersEditMenuTooltip => 'Chỉnh sửa thực đơn';

  @override
  String get ordersExportTooltip => 'Xuất đơn hàng theo tháng';

  @override
  String orderNewFrom(String customerName) {
    return 'Đơn mới từ $customerName';
  }

  @override
  String orderNewFromWaitingTransfer(String customerName) {
    return 'Đơn mới từ $customerName — chờ chuyển khoản';
  }

  @override
  String get orderUpdateFailed => 'Không thể cập nhật đơn hàng. Thử lại.';

  @override
  String orderCardTitle(String shortId, String customerName) {
    return 'Đơn #$shortId — $customerName';
  }

  @override
  String orderTotal(String total) {
    return 'Tổng: $total';
  }

  @override
  String get orderMarkReady => 'Đánh dấu sẵn sàng';

  @override
  String get orderMarkDelivered => 'Đánh dấu đã giao';

  @override
  String get orderUnpaid => 'Chưa thanh toán';

  @override
  String orderTransferContent(String reference) {
    return 'Nội dung chuyển khoản: $reference';
  }

  @override
  String get orderPaymentExpired => 'Hết hạn thanh toán';

  @override
  String get orderConfirmTransferReceived => 'Đã nhận chuyển khoản';

  @override
  String get orderSwitchToCash => 'Chuyển sang tiền mặt';

  @override
  String get payDisabled => 'Chức năng đang tắt trên máy chủ';

  @override
  String get payTryLater => 'Thử lại sau.';

  @override
  String get payConflict => 'Đơn này đã được xử lý';

  @override
  String get payFailed => 'Không thể cập nhật. Thử lại.';

  @override
  String get menuEditTitle => 'Chỉnh sửa thực đơn';

  @override
  String get menuLoadFailed => 'Không tải được thực đơn.';

  @override
  String get menuEmpty => 'Thực đơn đang trống.';

  @override
  String get menuInStock => 'Còn hàng';

  @override
  String get menuSoldOut => 'Hết hàng';

  @override
  String menuItemSubtitle(String price, String stock) {
    return '$price · $stock';
  }

  @override
  String menuEditPriceTooltip(String name) {
    return 'Sửa giá $name';
  }

  @override
  String menuInStockSemantics(String name) {
    return 'Còn hàng: $name';
  }

  @override
  String menuEditPriceTitle(String name) {
    return 'Sửa giá $name';
  }

  @override
  String get menuPriceLabel => 'Giá (VNĐ)';

  @override
  String get menuPriceRangeError => 'Nhập số nguyên từ 0 đến 1.000.000';

  @override
  String get menuPriceInvalid =>
      'Giá không hợp lệ. Nhập số nguyên từ 0 đến 1.000.000';

  @override
  String get menuEditingDisabled =>
      'Chức năng sửa thực đơn đang tắt trên máy chủ';

  @override
  String get menuItemNotFound => 'Không tìm thấy món này. Hãy tải lại trang.';

  @override
  String get menuSaveFailed => 'Không lưu được. Thử lại.';

  @override
  String get customerMenuTitle => 'Thực đơn';

  @override
  String customerCartPriceChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Giá của $count món trong giỏ hàng đã thay đổi.',
    );
    return '$_temp0';
  }

  @override
  String customerCartRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count món không còn trong thực đơn và đã bị xóa khỏi giỏ hàng.',
    );
    return '$_temp0';
  }

  @override
  String customerOrderStatusSnack(String shortId, String status) {
    return 'Đơn #$shortId: $status';
  }

  @override
  String customerOrderExpiredSnack(String shortId) {
    return 'Đơn #$shortId: hết hạn thanh toán';
  }

  @override
  String get customerMenuLoadFailed => 'Không tải được thực đơn';

  @override
  String get customerCartTooltip => 'Giỏ hàng';

  @override
  String get customerCategoryFood => 'Đồ ăn';

  @override
  String get customerCategoryDrink => 'Đồ uống';

  @override
  String get customerCategorySnack => 'Ăn nhẹ';

  @override
  String get customerCategoryNibble => 'Ăn vặt';

  @override
  String get customerCategoryEmpty => 'Chưa có món nào trong mục này';

  @override
  String get customerYourOrders => 'Đơn của bạn';

  @override
  String get customerOrderExpired => 'Hết hạn thanh toán';

  @override
  String customerAddItem(String name) {
    return 'Thêm $name';
  }

  @override
  String customerAdded(String names) {
    return 'Đã thêm $names';
  }

  @override
  String get customerSoldOut => 'Hết hàng';

  @override
  String get customerCartTitle => 'Giỏ hàng của bạn';

  @override
  String get customerCartEmpty => 'Giỏ hàng trống.';

  @override
  String customerPricePerItem(String price) {
    return '$price / món';
  }

  @override
  String get customerNameLabel => 'Tên của bạn';

  @override
  String get customerNameRequired => 'Vui lòng nhập tên của bạn';

  @override
  String customerCartTotal(String total) {
    return 'Tổng cộng: $total';
  }

  @override
  String get customerOrderFailed => 'Không thể đặt hàng. Vui lòng thử lại.';

  @override
  String get customerPlaceOrder => 'Đặt hàng';

  @override
  String get customerTransferOff => 'Chuyển khoản chưa được bật';

  @override
  String customerOrderPlaced(String name) {
    return 'Đặt hàng thành công, $name!';
  }

  @override
  String get customerAddToppings => 'Thêm topping';

  @override
  String get customerAddDrink => 'Thêm đồ uống';

  @override
  String get customerChooseDrink => 'Chọn đồ uống';

  @override
  String get customerBack => 'Quay lại';

  @override
  String get customerNext => 'Tiếp';

  @override
  String get customerAddButton => 'Thêm';

  @override
  String customerDishPrice(String name, String price) {
    return '$name: $price';
  }

  @override
  String get customerPayNotFound => 'Không tìm thấy đơn hàng.';

  @override
  String get customerPayChecking => 'Đang kiểm tra thanh toán…';

  @override
  String get customerPayCancelled => 'Đơn của bạn đã bị hủy.';

  @override
  String get customerPayReceived => 'Đã nhận thanh toán. Cảm ơn bạn!';

  @override
  String get customerPayCashOrder =>
      'Đơn của bạn sẽ được thanh toán bằng tiền mặt.';

  @override
  String get customerPayRecheck => 'Kiểm tra lại';

  @override
  String get customerBackToMenu => 'Về menu';

  @override
  String get customerSwitchToCash => 'Chuyển sang tiền mặt';

  @override
  String get customerPayInstruction =>
      'Hãy chuyển khoản trong vòng 5 phút để giữ đơn.';

  @override
  String customerCountdown(String time) {
    return 'Còn lại $time';
  }

  @override
  String get customerBank => 'Ngân hàng';

  @override
  String get customerAccountNumber => 'Số tài khoản';

  @override
  String get customerAccountName => 'Chủ tài khoản';

  @override
  String get customerAmount => 'Số tiền';

  @override
  String get customerTransferContent => 'Nội dung chuyển khoản';

  @override
  String get customerQrLoadFailed => 'Không tải được mã QR.';

  @override
  String get customerCashHint =>
      'Đổi sang thanh toán tiền mặt nếu bạn chưa muốn thanh toán luôn';

  @override
  String get customerPayChanged => 'Đơn vừa thay đổi, đang kiểm tra lại';

  @override
  String get customerPayActionFailed =>
      'Không thực hiện được. Vui lòng thử lại.';

  @override
  String get customerPayTooLate =>
      'Đã quá 15 phút. Hãy đặt lại đơn hoặc báo cho quán.';

  @override
  String get customerPayExpired =>
      'Đơn của bạn đã hết hạn thanh toán. Bạn có muốn chuyển sang thanh toán tiền mặt không?';

  @override
  String get customerPayTransferUnavailable =>
      'Chuyển khoản tạm thời không dùng được';

  @override
  String get customerNewQr => 'Tạo mã QR mới';

  @override
  String get customerQrSemantics => 'Mã QR chuyển khoản';
}
