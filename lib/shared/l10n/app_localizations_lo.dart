// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Lao (`lo`).
class AppLocalizationsLo extends AppLocalizations {
  AppLocalizationsLo([String locale = 'lo']) : super(locale);

  @override
  String get appTitleCustomer => 'ສັ່ງອາຫານ';

  @override
  String get appTitleRestaurant => 'ສັ່ງອາຫານ — ຮ້ານອາຫານ';

  @override
  String get statusAwaitingPayment => 'ລໍຖ້າການຊຳລະເງິນ';

  @override
  String get statusPreparing => 'ກຳລັງກະກຽມ';

  @override
  String get statusReady => 'ພ້ອມໃຫ້ມາຮັບ';

  @override
  String get statusDelivered => 'ສົ່ງແລ້ວ';

  @override
  String get statusCancelled => 'ຍົກເລີກແລ້ວ';

  @override
  String get paymentCash => 'ເງິນສົດ';

  @override
  String get paymentBankTransfer => 'ໂອນເງິນຜ່ານທະນາຄານ';

  @override
  String get commonCancel => 'ຍົກເລີກ';

  @override
  String get commonConfirm => 'ຢືນຢັນ';

  @override
  String get commonSave => 'ບັນທຶກ';

  @override
  String get commonRetry => 'ລອງໃໝ່';

  @override
  String get commonDownload => 'ດາວໂຫຼດ';

  @override
  String get staffLoginTitle => 'ເຂົ້າສູ່ລະບົບພະນັກງານ';

  @override
  String get staffIdLabel => 'ລະຫັດພະນັກງານ';

  @override
  String get staffPasswordLabel => 'ລະຫັດຜ່ານພະນັກງານ';

  @override
  String get staffPlainCharsError =>
      'ໃຊ້ສະເພາະຕົວອັກສອນທຳມະດາທີ່ບໍ່ມີວັນນະຍຸດ, ຕົວເລກ ແລະ ສັນຍາລັກທົ່ວໄປ';

  @override
  String get staffWrongCredentials => 'ລະຫັດພະນັກງານ ຫຼື ລະຫັດຜ່ານບໍ່ຖືກຕ້ອງ';

  @override
  String get tooManyTriesLater => 'ລອງຜິດຫຼາຍເກີນໄປ. ກະລຸນາລອງໃໝ່ພາຍຫຼັງ.';

  @override
  String tooManyTriesWait(int seconds) {
    return 'ລອງຜິດຫຼາຍເກີນໄປ. ລອງໃໝ່ອີກຄັ້ງໃນ $seconds ວິນາທີ.';
  }

  @override
  String get exportTitle => 'ສົ່ງອອກຄຳສັ່ງຊື້ຕາມເດືອນ';

  @override
  String get exportMonthLabel => 'ເດືອນ';

  @override
  String get exportReportLabel => 'ປະເພດລາຍງານ';

  @override
  String get exportSummaryOption => 'ລາຍງານສະຫຼຸບລາຍວັນ (Excel)';

  @override
  String get exportDetailOption => 'ລາຍລະອຽດທຸກຄຳສັ່ງຊື້ໃນເດືອນ (Excel)';

  @override
  String get exportLinesOption => 'ລາຍການແຖວອາຫານ (CSV)';

  @override
  String get exportDisabled => 'ຟັງຊັນສົ່ງອອກຖືກປິດຢູ່ເທິງເຊີບເວີ';

  @override
  String get exportNotConfigured => 'ຍັງບໍ່ໄດ້ຕັ້ງຄ່າຂໍ້ມູນຮ້ານຢູ່ເທິງເຊີບເວີ';

  @override
  String get exportFailed => 'ບໍ່ສາມາດສົ່ງອອກຂໍ້ມູນໄດ້. ລອງໃໝ່.';

  @override
  String get ordersTitle => 'ລາຍການຄຳສັ່ງຊື້';

  @override
  String get ordersEmpty => 'ຍັງບໍ່ມີຄຳສັ່ງຊື້. ກຳລັງລໍຖ້າລູກຄ້າ…';

  @override
  String get ordersEditMenuTooltip => 'ແກ້ໄຂເມນູ';

  @override
  String get ordersExportTooltip => 'ສົ່ງອອກຄຳສັ່ງຊື້ຕາມເດືອນ';

  @override
  String orderNewFrom(String customerName) {
    return 'ມີຄຳສັ່ງຊື້ໃໝ່ຈາກ $customerName';
  }

  @override
  String orderNewFromWaitingTransfer(String customerName) {
    return 'ມີຄຳສັ່ງຊື້ໃໝ່ຈາກ $customerName — ລໍຖ້າການໂອນເງິນ';
  }

  @override
  String get orderUpdateFailed => 'ບໍ່ສາມາດອັບເດດຄຳສັ່ງຊື້ໄດ້. ລອງໃໝ່.';

  @override
  String orderCardTitle(String shortId, String customerName) {
    return 'ຄຳສັ່ງຊື້ #$shortId — $customerName';
  }

  @override
  String orderTotal(String total) {
    return 'ລວມ: $total';
  }

  @override
  String get orderMarkReady => 'ໝາຍວ່າພ້ອມແລ້ວ';

  @override
  String get orderMarkDelivered => 'ໝາຍວ່າສົ່ງແລ້ວ';

  @override
  String get statusFinished => 'ເສີບແລ້ວ';

  @override
  String get orderMarkFinished => 'ໝາຍວ່າເສີບແລ້ວ';

  @override
  String get orderCheckPaidNote => 'ກະລຸນາກວດເບິ່ງວ່າອໍເດີໄດ້ຊຳລະແລ້ວຫຼືບໍ່';

  @override
  String get orderCancel => 'ຍົກເລີກອໍເດີ';

  @override
  String get orderCancelConfirm => 'ຍົກເລີກອໍເດີນີ້ບໍ?';

  @override
  String get orderCancelPaidNote =>
      'ລູກຄ້າອາດຈະຊຳລະແລ້ວ. ການຄືນເງິນໃຫ້ເຮັດດ້ວຍມື ນອກແອັບ.';

  @override
  String get orderCancelFinalNote => 'ອໍເດີທີ່ຍົກເລີກແລ້ວປ່ຽນກັບຄືນບໍ່ໄດ້.';

  @override
  String get orderChangeStatus => 'ປ່ຽນສະຖານະ';

  @override
  String get orderChangeStatusFinishedNote =>
      'ການດຳເນີນການນີ້ຈະປ່ຽນລາຍງານປະຈຳເດືອນ.';

  @override
  String get orderChangeStatusNotAllowed => 'ບໍ່ສາມາດປ່ຽນສະຖານະຂອງອໍເດີນີ້ໄດ້.';

  @override
  String get orderChangeStatusCancelled =>
      'ອໍເດີຖືກຍົກເລີກແລ້ວ ແລະ ປ່ຽນບໍ່ໄດ້.';

  @override
  String get orderUnpaid => 'ຍັງບໍ່ໄດ້ຊຳລະ';

  @override
  String orderTransferContent(String reference) {
    return 'ເນື້ອໃນການໂອນ: $reference';
  }

  @override
  String get orderPaymentExpired => 'ໝົດເວລາຊຳລະເງິນ';

  @override
  String get orderConfirmTransferReceived => 'ໄດ້ຮັບເງິນໂອນແລ້ວ';

  @override
  String get orderSwitchToCash => 'ປ່ຽນເປັນເງິນສົດ';

  @override
  String get payDisabled => 'ຟັງຊັນນີ້ຖືກປິດຢູ່ເທິງເຊີບເວີ';

  @override
  String get payTryLater => 'ລອງໃໝ່ພາຍຫຼັງ.';

  @override
  String get payConflict => 'ຄຳສັ່ງຊື້ນີ້ໄດ້ຖືກດຳເນີນການແລ້ວ';

  @override
  String get payFailed => 'ບໍ່ສາມາດອັບເດດໄດ້. ລອງໃໝ່.';

  @override
  String get menuEditTitle => 'ແກ້ໄຂເມນູ';

  @override
  String get menuLoadFailed => 'ບໍ່ສາມາດໂຫຼດເມນູໄດ້.';

  @override
  String get menuEmpty => 'ເມນູຫວ່າງເປົ່າ.';

  @override
  String get menuInStock => 'ມີສິນຄ້າ';

  @override
  String get menuSoldOut => 'ໝົດແລ້ວ';

  @override
  String menuItemSubtitle(String price, String stock) {
    return '$price · $stock';
  }

  @override
  String menuEditPriceTooltip(String name) {
    return 'ແກ້ໄຂລາຄາ $name';
  }

  @override
  String menuInStockSemantics(String name) {
    return 'ມີສິນຄ້າ: $name';
  }

  @override
  String menuEditPriceTitle(String name) {
    return 'ແກ້ໄຂລາຄາ $name';
  }

  @override
  String get menuPriceLabel => 'ລາຄາ (VNĐ)';

  @override
  String get menuPriceRangeError => 'ປ້ອນຈຳນວນເຕັມຕັ້ງແຕ່ 0 ຫາ 1,000,000';

  @override
  String get menuPriceInvalid =>
      'ລາຄາບໍ່ຖືກຕ້ອງ. ປ້ອນຈຳນວນເຕັມຕັ້ງແຕ່ 0 ຫາ 1,000,000';

  @override
  String get menuEditingDisabled => 'ຟັງຊັນແກ້ໄຂເມນູຖືກປິດຢູ່ເທິງເຊີບເວີ';

  @override
  String get menuItemNotFound => 'ບໍ່ພົບລາຍການນີ້. ກະລຸນາໂຫຼດໜ້າໃໝ່.';

  @override
  String get menuSaveFailed => 'ບໍ່ສາມາດບັນທຶກໄດ້. ລອງໃໝ່.';

  @override
  String get customerMenuTitle => 'ເມນູ';

  @override
  String customerCartPriceChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ລາຄາຂອງ $count ລາຍການໃນກະຕ່າປ່ຽນແປງແລ້ວ.',
    );
    return '$_temp0';
  }

  @override
  String customerCartRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ລາຍການບໍ່ຢູ່ໃນເມນູແລ້ວ ແລະ ຖືກເອົາອອກຈາກກະຕ່າ.',
    );
    return '$_temp0';
  }

  @override
  String customerOrderStatusSnack(String shortId, String status) {
    return 'ຄຳສັ່ງ #$shortId: $status';
  }

  @override
  String customerOrderExpiredSnack(String shortId) {
    return 'ຄຳສັ່ງ #$shortId: ໝົດເວລາຊຳລະເງິນ';
  }

  @override
  String get customerMenuLoadFailed => 'ບໍ່ສາມາດໂຫຼດເມນູໄດ້';

  @override
  String get customerCartTooltip => 'ກະຕ່າ';

  @override
  String get customerCategoryFood => 'ອາຫານ';

  @override
  String get customerCategoryDrink => 'ເຄື່ອງດື່ມ';

  @override
  String get customerCategorySnack => 'ອາຫານເບົາ';

  @override
  String get customerCategoryNibble => 'ຂອງກິນຫຼິ້ນ';

  @override
  String get customerCategoryEmpty => 'ຍັງບໍ່ມີລາຍການໃນໝວດນີ້';

  @override
  String get customerYourOrders => 'ຄຳສັ່ງຂອງທ່ານ';

  @override
  String get customerOrderExpired => 'ໝົດເວລາຊຳລະເງິນ';

  @override
  String customerAddItem(String name) {
    return 'ເພີ່ມ $name';
  }

  @override
  String customerAdded(String names) {
    return 'ເພີ່ມ $names ແລ້ວ';
  }

  @override
  String get customerSoldOut => 'ໝົດແລ້ວ';

  @override
  String get customerCartTitle => 'ກະຕ່າຂອງທ່ານ';

  @override
  String get customerCartEmpty => 'ກະຕ່າຫວ່າງເປົ່າ.';

  @override
  String customerPricePerItem(String price) {
    return '$price / ລາຍການ';
  }

  @override
  String get customerNameLabel => 'ຊື່ຂອງທ່ານ';

  @override
  String get customerNameRequired => 'ກະລຸນາໃສ່ຊື່ຂອງທ່ານ';

  @override
  String customerCartTotal(String total) {
    return 'ລວມທັງໝົດ: $total';
  }

  @override
  String get customerOrderFailed => 'ບໍ່ສາມາດສັ່ງຊື້ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String get customerPlaceOrder => 'ສັ່ງຊື້';

  @override
  String get customerTransferOff => 'ການໂອນເງິນຍັງບໍ່ໄດ້ເປີດໃຊ້';

  @override
  String customerOrderPlaced(String name) {
    return 'ສັ່ງຊື້ສຳເລັດແລ້ວ, $name!';
  }

  @override
  String get customerAddToppings => 'ເພີ່ມທັອບປິງ';

  @override
  String get customerAddDrink => 'ເພີ່ມເຄື່ອງດື່ມ';

  @override
  String get customerChooseDrink => 'ເລືອກເຄື່ອງດື່ມ';

  @override
  String get customerBack => 'ກັບຄືນ';

  @override
  String get customerNext => 'ຕໍ່ໄປ';

  @override
  String get customerAddButton => 'ເພີ່ມ';

  @override
  String customerDishPrice(String name, String price) {
    return '$name: $price';
  }

  @override
  String get customerPayNotFound => 'ບໍ່ພົບຄຳສັ່ງຊື້.';

  @override
  String get customerPayChecking => 'ກຳລັງກວດສອບການຊຳລະ…';

  @override
  String get customerPayCancelled => 'ຄຳສັ່ງຊື້ຂອງທ່ານຖືກຍົກເລີກແລ້ວ.';

  @override
  String get customerPayReceived => 'ໄດ້ຮັບການຊຳລະແລ້ວ. ຂອບໃຈ!';

  @override
  String get customerPayCashOrder => 'ຄຳສັ່ງຊື້ຂອງທ່ານຈະຊຳລະເປັນເງິນສົດ.';

  @override
  String get customerPayRecheck => 'ກວດສອບອີກຄັ້ງ';

  @override
  String get customerBackToMenu => 'ກັບໄປເມນູ';

  @override
  String get customerSwitchToCash => 'ປ່ຽນເປັນເງິນສົດ';

  @override
  String get customerPayInstruction =>
      'ກະລຸນາໂອນເງິນພາຍໃນ 5 ນາທີ ເພື່ອຮັກສາຄຳສັ່ງຊື້ຂອງທ່ານ.';

  @override
  String customerCountdown(String time) {
    return 'ເຫຼືອ $time';
  }

  @override
  String get customerBank => 'ທະນາຄານ';

  @override
  String get customerAccountNumber => 'ເລກບັນຊີ';

  @override
  String get customerAccountName => 'ເຈົ້າຂອງບັນຊີ';

  @override
  String get customerAmount => 'ຈຳນວນເງິນ';

  @override
  String get customerTransferContent => 'ເນື້ອໃນການໂອນ';

  @override
  String get customerQrLoadFailed => 'ບໍ່ສາມາດໂຫຼດລະຫັດ QR ໄດ້.';

  @override
  String get customerCashHint => 'ປ່ຽນເປັນເງິນສົດ ຖ້າທ່ານຍັງບໍ່ຢາກຊຳລະດຽວນີ້';

  @override
  String get customerPayChanged =>
      'ຄຳສັ່ງຊື້ຂອງທ່ານຫາກໍປ່ຽນແປງ, ກຳລັງກວດສອບອີກຄັ້ງ';

  @override
  String get customerPayActionFailed => 'ບໍ່ສຳເລັດ. ກະລຸນາລອງໃໝ່.';

  @override
  String get customerPayTooLate =>
      'ເກີນ 15 ນາທີແລ້ວ. ກະລຸນາສັ່ງໃໝ່ ຫຼື ແຈ້ງຮ້ານ.';

  @override
  String get customerPayExpired =>
      'ໝົດເວລາຊຳລະເງິນສຳລັບຄຳສັ່ງຊື້ຂອງທ່ານແລ້ວ. ທ່ານຕ້ອງການປ່ຽນເປັນຊຳລະເງິນສົດບໍ?';

  @override
  String get customerPayTransferUnavailable => 'ການໂອນເງິນຊົ່ວຄາວໃຊ້ບໍ່ໄດ້';

  @override
  String get customerNewQr => 'ສ້າງລະຫັດ QR ໃໝ່';

  @override
  String get customerQrSemantics => 'ລະຫັດ QR ສຳລັບໂອນເງິນ';

  @override
  String get menuAddTooltip => 'ເພີ່ມເມນູ';

  @override
  String get menuAddTitle => 'ເພີ່ມເມນູໃໝ່';

  @override
  String get menuAddAction => 'ເພີ່ມ';

  @override
  String get menuAddNameLabel => 'ຊື່';

  @override
  String get menuAddDescriptionLabel => 'ລາຍລະອຽດ (ບໍ່ບັງຄັບ)';

  @override
  String get menuAddCategoryLabel => 'ໝວດ';

  @override
  String get menuAddCategoryRequired => 'ກະລຸນາເລືອກໝວດ';

  @override
  String get menuAddAllowToppingsLabel => 'ອະນຸຍາດໃຫ້ເພີ່ມທ໊ອບປິງ';

  @override
  String get menuAddImageLabel => 'ຊື່ໄຟລ໌ຮູບ (ບໍ່ບັງຄັບ)';

  @override
  String get menuAddImageHelp => 'ໄຟລ໌ຕ້ອງຢູ່ໃນໂຟນເດີຮູບຂອງເຊີບເວີແລ້ວ.';

  @override
  String get menuAddNameError => 'ໃສ່ຊື່, ສູງສຸດ 100 ຕົວອັກສອນ';

  @override
  String get menuAddDescriptionError => 'ລາຍລະອຽດສູງສຸດ 500 ຕົວອັກສອນ';

  @override
  String get menuAddImageError =>
      'ຊື່ໄຟລ໌ບໍ່ຖືກຕ້ອງ. ໃຊ້ແຕ່ຕົວອັກສອນນ້ອຍ, ຕົວເລກ ແລະ - ແລະລົງທ້າຍດ້ວຍ .jpg, .jpeg, .png ຫຼື .webp';

  @override
  String get menuAddDuplicate => 'ມີເມນູຊື່ນີ້ໃນໝວດນີ້ແລ້ວ';

  @override
  String get menuFull => 'ເມນູເຕັມແລ້ວ, ເພີ່ມອີກບໍ່ໄດ້';

  @override
  String menuAddedSnack(String name) {
    return 'ເພີ່ມແລ້ວ: $name';
  }
}
