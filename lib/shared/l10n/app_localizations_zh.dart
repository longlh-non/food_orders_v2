// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitleCustomer => '点餐';

  @override
  String get appTitleRestaurant => '点餐 — 餐厅';

  @override
  String get statusAwaitingPayment => '等待付款';

  @override
  String get statusPreparing => '准备中';

  @override
  String get statusReady => '可取餐';

  @override
  String get statusDelivered => '已送达';

  @override
  String get statusCancelled => '已取消';

  @override
  String get paymentCash => '现金';

  @override
  String get paymentBankTransfer => '银行转账';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonSave => '保存';

  @override
  String get commonRetry => '重试';

  @override
  String get commonDownload => '下载';

  @override
  String get staffLoginTitle => '员工登录';

  @override
  String get staffIdLabel => '员工编号';

  @override
  String get staffPasswordLabel => '员工密码';

  @override
  String get staffPlainCharsError => '仅使用无重音的普通字母、数字和常用符号';

  @override
  String get staffWrongCredentials => '员工编号或密码错误';

  @override
  String get tooManyTriesLater => '错误尝试次数过多，请稍后再试。';

  @override
  String tooManyTriesWait(int seconds) {
    return '错误尝试次数过多，请在 $seconds 秒后重试。';
  }

  @override
  String get exportTitle => '按月导出订单';

  @override
  String get exportMonthLabel => '月份';

  @override
  String get exportReportLabel => '报表类型';

  @override
  String get exportSummaryOption => '每日汇总报表（Excel）';

  @override
  String get exportDetailOption => '本月每笔订单明细（Excel）';

  @override
  String get exportLinesOption => '订单行列表（CSV）';

  @override
  String get exportDisabled => '服务器已关闭导出功能';

  @override
  String get exportNotConfigured => '服务器上尚未设置店铺信息';

  @override
  String get exportFailed => '无法导出数据，请重试。';

  @override
  String get ordersTitle => '订单列表';

  @override
  String get ordersEmpty => '还没有订单，正在等待顾客…';

  @override
  String get ordersEditMenuTooltip => '编辑菜单';

  @override
  String get ordersExportTooltip => '按月导出订单';

  @override
  String orderNewFrom(String customerName) {
    return '来自 $customerName 的新订单';
  }

  @override
  String orderNewFromWaitingTransfer(String customerName) {
    return '来自 $customerName 的新订单 — 等待银行转账';
  }

  @override
  String get orderUpdateFailed => '无法更新订单，请重试。';

  @override
  String orderCardTitle(String shortId, String customerName) {
    return '订单 #$shortId — $customerName';
  }

  @override
  String orderTotal(String total) {
    return '合计：$total';
  }

  @override
  String get orderMarkReady => '标记为可取餐';

  @override
  String get orderMarkDelivered => '标记为已送达';

  @override
  String get orderUnpaid => '未付款';

  @override
  String orderTransferContent(String reference) {
    return '转账备注：$reference';
  }

  @override
  String get orderPaymentExpired => '付款已过期';

  @override
  String get orderConfirmTransferReceived => '已收到转账';

  @override
  String get orderSwitchToCash => '改为现金支付';

  @override
  String get payDisabled => '服务器已关闭此功能';

  @override
  String get payTryLater => '请稍后再试。';

  @override
  String get payConflict => '此订单已处理';

  @override
  String get payFailed => '无法更新，请重试。';

  @override
  String get menuEditTitle => '编辑菜单';

  @override
  String get menuLoadFailed => '无法加载菜单。';

  @override
  String get menuEmpty => '菜单为空。';

  @override
  String get menuInStock => '有货';

  @override
  String get menuSoldOut => '售罄';

  @override
  String menuItemSubtitle(String price, String stock) {
    return '$price · $stock';
  }

  @override
  String menuEditPriceTooltip(String name) {
    return '修改 $name 的价格';
  }

  @override
  String menuInStockSemantics(String name) {
    return '有货：$name';
  }

  @override
  String menuEditPriceTitle(String name) {
    return '修改 $name 的价格';
  }

  @override
  String get menuPriceLabel => '价格（越南盾）';

  @override
  String get menuPriceRangeError => '请输入 0 到 1,000,000 之间的整数';

  @override
  String get menuPriceInvalid => '价格无效，请输入 0 到 1,000,000 之间的整数';

  @override
  String get menuEditingDisabled => '服务器已关闭菜单编辑功能';

  @override
  String get menuItemNotFound => '找不到该菜品，请重新加载页面。';

  @override
  String get menuSaveFailed => '无法保存，请重试。';
}
