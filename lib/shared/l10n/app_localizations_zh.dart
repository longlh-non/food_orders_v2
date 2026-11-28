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
  String get statusFinished => '已上菜';

  @override
  String get orderMarkFinished => '标记为已上菜';

  @override
  String get orderCheckPaidNote => '请检查订单是否已付款';

  @override
  String get orderCancel => '取消订单';

  @override
  String get orderCancelConfirm => '取消此订单？';

  @override
  String get orderCancelPaidNote => '顾客可能已经付款。如需退款，请在应用之外手动处理。';

  @override
  String get orderCancelFinalNote => '已取消的订单无法恢复。';

  @override
  String get orderChangeStatus => '更改状态';

  @override
  String get orderChangeStatusFinishedNote => '这会改变月度报表。';

  @override
  String get orderChangeStatusNotAllowed => '无法更改此订单的状态。';

  @override
  String get orderChangeStatusCancelled => '订单已取消，无法更改。';

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

  @override
  String get customerMenuTitle => '菜单';

  @override
  String customerCartPriceChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '购物车中 $count 件商品的价格已变更。',
    );
    return '$_temp0';
  }

  @override
  String customerCartRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件商品已不在菜单中，并已从购物车移除。',
    );
    return '$_temp0';
  }

  @override
  String customerOrderStatusSnack(String shortId, String status) {
    return '订单 #$shortId：$status';
  }

  @override
  String customerOrderExpiredSnack(String shortId) {
    return '订单 #$shortId：支付已超时';
  }

  @override
  String get customerMenuLoadFailed => '无法加载菜单';

  @override
  String get customerCartTooltip => '购物车';

  @override
  String get customerCategoryFood => '主食';

  @override
  String get customerCategoryDrink => '饮品';

  @override
  String get customerCategorySnack => '轻食';

  @override
  String get customerCategoryNibble => '零食';

  @override
  String get customerCategoryEmpty => '此分类下暂无商品';

  @override
  String get customerYourOrders => '你的订单';

  @override
  String get customerOrderExpired => '支付已超时';

  @override
  String customerAddItem(String name) {
    return '添加 $name';
  }

  @override
  String customerAdded(String names) {
    return '已添加 $names';
  }

  @override
  String get customerSoldOut => '已售罄';

  @override
  String get customerCartTitle => '你的购物车';

  @override
  String get customerCartEmpty => '购物车是空的。';

  @override
  String customerPricePerItem(String price) {
    return '$price / 件';
  }

  @override
  String get customerNameLabel => '你的姓名';

  @override
  String get customerNameRequired => '请输入你的姓名';

  @override
  String customerCartTotal(String total) {
    return '合计：$total';
  }

  @override
  String get customerOrderFailed => '无法下单，请重试。';

  @override
  String get customerPlaceOrder => '下单';

  @override
  String get customerTransferOff => '尚未开通银行转账';

  @override
  String customerOrderPlaced(String name) {
    return '下单成功，$name！';
  }

  @override
  String get customerAddToppings => '添加配料';

  @override
  String get customerAddDrink => '添加饮品';

  @override
  String get customerChooseDrink => '选择饮品';

  @override
  String get customerBack => '返回';

  @override
  String get customerNext => '下一步';

  @override
  String get customerAddButton => '添加';

  @override
  String customerDishPrice(String name, String price) {
    return '$name: $price';
  }

  @override
  String get customerPayNotFound => '找不到订单。';

  @override
  String get customerPayChecking => '正在确认付款…';

  @override
  String get customerPayCancelled => '你的订单已被取消。';

  @override
  String get customerPayReceived => '已收到付款，谢谢！';

  @override
  String get customerPayCashOrder => '你的订单将以现金支付。';

  @override
  String get customerPayRecheck => '重新检查';

  @override
  String get customerBackToMenu => '返回菜单';

  @override
  String get customerSwitchToCash => '改为现金支付';

  @override
  String get customerPayInstruction => '请在 5 分钟内转账以保留订单。';

  @override
  String customerCountdown(String time) {
    return '剩余 $time';
  }

  @override
  String get customerBank => '银行';

  @override
  String get customerAccountNumber => '账号';

  @override
  String get customerAccountName => '账户名';

  @override
  String get customerAmount => '金额';

  @override
  String get customerTransferContent => '转账内容';

  @override
  String get customerQrLoadFailed => '无法加载二维码。';

  @override
  String get customerCashHint => '如果暂时不想付款，可以改为现金支付';

  @override
  String get customerPayChanged => '订单刚刚发生变化，正在重新检查';

  @override
  String get customerPayActionFailed => '操作失败，请重试。';

  @override
  String get customerPayTooLate => '已超过 15 分钟，请重新下单或告知店家。';

  @override
  String get customerPayExpired => '你的订单支付已超时。要改为现金支付吗？';

  @override
  String get customerPayTransferUnavailable => '银行转账暂时不可用';

  @override
  String get customerNewQr => '生成新的二维码';

  @override
  String get customerQrSemantics => '银行转账二维码';

  @override
  String get menuAddTooltip => '添加菜品';

  @override
  String get menuAddTitle => '添加新菜品';

  @override
  String get menuAddAction => '添加';

  @override
  String get menuAddNameLabel => '名称';

  @override
  String get menuAddDescriptionLabel => '描述（可选）';

  @override
  String get menuAddCategoryLabel => '分类';

  @override
  String get menuAddCategoryRequired => '请选择分类';

  @override
  String get menuAddAllowToppingsLabel => '允许加配料';

  @override
  String get menuAddImageLabel => '图片文件名（可选）';

  @override
  String get menuAddImageHelp => '该文件必须已在服务器的图片文件夹中。';

  @override
  String get menuAddNameError => '请输入名称，最多100个字符';

  @override
  String get menuAddDescriptionError => '描述最多500个字符';

  @override
  String get menuAddImageError =>
      '文件名无效。只能使用小写字母、数字和 -，以 .jpg、.jpeg、.png 或 .webp 结尾';

  @override
  String get menuAddDuplicate => '该分类中已有同名菜品';

  @override
  String get menuFull => '菜单已满，无法再添加菜品';

  @override
  String menuAddedSnack(String name) {
    return '已添加：$name';
  }
}
