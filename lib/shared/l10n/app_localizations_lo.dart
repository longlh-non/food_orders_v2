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
}
