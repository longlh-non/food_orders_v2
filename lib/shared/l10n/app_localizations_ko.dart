// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitleCustomer => '음식 주문';

  @override
  String get appTitleRestaurant => '음식 주문 — 레스토랑';

  @override
  String get statusAwaitingPayment => '결제 대기 중';

  @override
  String get statusPreparing => '준비 중';

  @override
  String get statusReady => '수령 가능';

  @override
  String get statusDelivered => '전달 완료';

  @override
  String get statusCancelled => '취소됨';

  @override
  String get paymentCash => '현금';

  @override
  String get paymentBankTransfer => '계좌 이체';

  @override
  String get commonCancel => '취소';

  @override
  String get commonConfirm => '확인';

  @override
  String get commonSave => '저장';

  @override
  String get commonRetry => '다시 시도';

  @override
  String get commonDownload => '다운로드';

  @override
  String get staffLoginTitle => '직원 로그인';

  @override
  String get staffIdLabel => '직원 ID';

  @override
  String get staffPasswordLabel => '직원 비밀번호';

  @override
  String get staffPlainCharsError => '악센트 없는 일반 문자, 숫자, 기호만 사용하세요';

  @override
  String get staffWrongCredentials => '직원 ID 또는 비밀번호가 올바르지 않습니다';

  @override
  String get tooManyTriesLater => '잘못된 시도가 너무 많습니다. 나중에 다시 시도하세요.';

  @override
  String tooManyTriesWait(int seconds) {
    return '잘못된 시도가 너무 많습니다. $seconds초 후에 다시 시도하세요.';
  }

  @override
  String get exportTitle => '월별 주문 내보내기';

  @override
  String get exportMonthLabel => '월';

  @override
  String get exportReportLabel => '보고서 유형';

  @override
  String get exportSummaryOption => '일별 요약 보고서 (Excel)';

  @override
  String get exportDetailOption => '해당 월의 주문별 상세 내역 (Excel)';

  @override
  String get exportLinesOption => '주문 항목 목록 (CSV)';

  @override
  String get exportDisabled => '서버에서 내보내기가 꺼져 있습니다';

  @override
  String get exportNotConfigured => '서버에 매장 정보가 설정되어 있지 않습니다';

  @override
  String get exportFailed => '데이터를 내보낼 수 없습니다. 다시 시도하세요.';

  @override
  String get ordersTitle => '들어온 주문';

  @override
  String get ordersEmpty => '아직 주문이 없습니다. 손님을 기다리는 중…';

  @override
  String get ordersEditMenuTooltip => '메뉴 편집';

  @override
  String get ordersExportTooltip => '월별 주문 내보내기';

  @override
  String orderNewFrom(String customerName) {
    return '$customerName님의 새 주문';
  }

  @override
  String orderNewFromWaitingTransfer(String customerName) {
    return '$customerName님의 새 주문 — 계좌 이체 대기 중';
  }

  @override
  String get orderUpdateFailed => '주문을 업데이트할 수 없습니다. 다시 시도하세요.';

  @override
  String orderCardTitle(String shortId, String customerName) {
    return '주문 #$shortId — $customerName';
  }

  @override
  String orderTotal(String total) {
    return '합계: $total';
  }

  @override
  String get orderMarkReady => '준비 완료로 표시';

  @override
  String get orderMarkDelivered => '전달 완료로 표시';

  @override
  String get statusFinished => '서빙 완료';

  @override
  String get orderMarkFinished => '서빙 완료로 표시';

  @override
  String get orderCheckPaidNote => '주문이 결제되었는지 확인해 주세요';

  @override
  String get orderCancel => '주문 취소';

  @override
  String get orderCancelConfirm => '이 주문을 취소할까요?';

  @override
  String get orderCancelPaidNote => '고객이 이미 결제했을 수 있습니다. 환불은 앱 밖에서 직접 처리하세요.';

  @override
  String get orderCancelFinalNote => '취소된 주문은 되돌릴 수 없습니다.';

  @override
  String get orderChangeStatus => '상태 변경';

  @override
  String get orderChangeStatusFinishedNote => '월간 보고서가 변경됩니다.';

  @override
  String get orderChangeStatusNotAllowed => '이 주문의 상태는 변경할 수 없습니다.';

  @override
  String get orderChangeStatusCancelled => '주문이 취소되어 변경할 수 없습니다.';

  @override
  String get orderUnpaid => '미결제';

  @override
  String orderTransferContent(String reference) {
    return '이체 내용: $reference';
  }

  @override
  String get orderPaymentExpired => '결제 기한 만료';

  @override
  String get orderConfirmTransferReceived => '이체 확인됨';

  @override
  String get orderSwitchToCash => '현금으로 변경';

  @override
  String get payDisabled => '서버에서 이 기능이 꺼져 있습니다';

  @override
  String get payTryLater => '나중에 다시 시도하세요.';

  @override
  String get payConflict => '이 주문은 이미 처리되었습니다';

  @override
  String get payFailed => '업데이트할 수 없습니다. 다시 시도하세요.';

  @override
  String get menuEditTitle => '메뉴 편집';

  @override
  String get menuLoadFailed => '메뉴를 불러올 수 없습니다.';

  @override
  String get menuEmpty => '메뉴가 비어 있습니다.';

  @override
  String get menuInStock => '재고 있음';

  @override
  String get menuSoldOut => '품절';

  @override
  String menuItemSubtitle(String price, String stock) {
    return '$price · $stock';
  }

  @override
  String menuEditPriceTooltip(String name) {
    return '$name 가격 수정';
  }

  @override
  String menuInStockSemantics(String name) {
    return '재고 있음: $name';
  }

  @override
  String menuEditPriceTitle(String name) {
    return '$name 가격 수정';
  }

  @override
  String get menuPriceLabel => '가격 (VND)';

  @override
  String get menuPriceRangeError => '0에서 1,000,000 사이의 정수를 입력하세요';

  @override
  String get menuPriceInvalid => '가격이 올바르지 않습니다. 0에서 1,000,000 사이의 정수를 입력하세요';

  @override
  String get menuEditingDisabled => '서버에서 메뉴 편집이 꺼져 있습니다';

  @override
  String get menuItemNotFound => '이 항목을 찾을 수 없습니다. 페이지를 새로 고치세요.';

  @override
  String get menuSaveFailed => '저장할 수 없습니다. 다시 시도하세요.';

  @override
  String get customerMenuTitle => '메뉴';

  @override
  String customerCartPriceChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '장바구니에 있는 $count개 상품의 가격이 변경되었습니다.',
    );
    return '$_temp0';
  }

  @override
  String customerCartRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 상품이 메뉴에서 없어져 장바구니에서 삭제되었습니다.',
    );
    return '$_temp0';
  }

  @override
  String customerOrderStatusSnack(String shortId, String status) {
    return '주문 #$shortId: $status';
  }

  @override
  String customerOrderExpiredSnack(String shortId) {
    return '주문 #$shortId: 결제 시간이 만료되었습니다';
  }

  @override
  String get customerMenuLoadFailed => '메뉴를 불러오지 못했습니다';

  @override
  String get customerCartTooltip => '장바구니';

  @override
  String get customerCategoryFood => '음식';

  @override
  String get customerCategoryDrink => '음료';

  @override
  String get customerCategorySnack => '가벼운 식사';

  @override
  String get customerCategoryNibble => '군것질';

  @override
  String get customerCategoryEmpty => '이 카테고리에는 아직 상품이 없습니다';

  @override
  String get customerYourOrders => '내 주문';

  @override
  String get customerOrderExpired => '결제 시간 만료';

  @override
  String customerAddItem(String name) {
    return '$name 추가';
  }

  @override
  String customerAdded(String names) {
    return '$names 추가됨';
  }

  @override
  String get customerSoldOut => '품절';

  @override
  String get customerCartTitle => '내 장바구니';

  @override
  String get customerCartEmpty => '장바구니가 비어 있습니다.';

  @override
  String customerPricePerItem(String price) {
    return '$price / 개';
  }

  @override
  String get customerNameLabel => '이름';

  @override
  String get customerNameRequired => '이름을 입력해 주세요';

  @override
  String customerCartTotal(String total) {
    return '합계: $total';
  }

  @override
  String get customerOrderFailed => '주문할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get customerPlaceOrder => '주문하기';

  @override
  String get customerTransferOff => '계좌 이체가 켜져 있지 않습니다';

  @override
  String customerOrderPlaced(String name) {
    return '주문이 완료되었습니다, $name님!';
  }

  @override
  String get customerAddToppings => '토핑 추가';

  @override
  String get customerAddDrink => '음료 추가';

  @override
  String get customerChooseDrink => '음료 선택';

  @override
  String get customerBack => '뒤로';

  @override
  String get customerNext => '다음';

  @override
  String get customerAddButton => '추가';

  @override
  String customerDishPrice(String name, String price) {
    return '$name: $price';
  }

  @override
  String get customerPayNotFound => '주문을 찾을 수 없습니다.';

  @override
  String get customerPayChecking => '결제를 확인하는 중…';

  @override
  String get customerPayCancelled => '주문이 취소되었습니다.';

  @override
  String get customerPayReceived => '결제가 확인되었습니다. 감사합니다!';

  @override
  String get customerPayCashOrder => '주문은 현금으로 결제됩니다.';

  @override
  String get customerPayRecheck => '다시 확인';

  @override
  String get customerBackToMenu => '메뉴로 돌아가기';

  @override
  String get customerSwitchToCash => '현금 결제로 변경';

  @override
  String get customerPayInstruction => '주문을 유지하려면 5분 안에 이체해 주세요.';

  @override
  String customerCountdown(String time) {
    return '남은 시간 $time';
  }

  @override
  String get customerBank => '은행';

  @override
  String get customerAccountNumber => '계좌번호';

  @override
  String get customerAccountName => '예금주';

  @override
  String get customerAmount => '금액';

  @override
  String get customerTransferContent => '이체 내용';

  @override
  String get customerQrLoadFailed => 'QR 코드를 불러오지 못했습니다.';

  @override
  String get customerCashHint => '지금 결제하지 않으려면 현금 결제로 변경하세요';

  @override
  String get customerPayChanged => '주문이 방금 변경되어 다시 확인하는 중입니다';

  @override
  String get customerPayActionFailed => '실행하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get customerPayTooLate => '15분이 지났습니다. 다시 주문하시거나 매장에 알려 주세요.';

  @override
  String get customerPayExpired => '주문의 결제 시간이 만료되었습니다. 현금 결제로 변경하시겠어요?';

  @override
  String get customerPayTransferUnavailable => '계좌 이체를 일시적으로 사용할 수 없습니다';

  @override
  String get customerNewQr => '새 QR 코드 만들기';

  @override
  String get customerQrSemantics => '계좌 이체 QR 코드';

  @override
  String get menuAddTooltip => '메뉴 추가';

  @override
  String get menuAddTitle => '새 메뉴 추가';

  @override
  String get menuAddAction => '추가';

  @override
  String get menuAddNameLabel => '이름';

  @override
  String get menuAddDescriptionLabel => '설명 (선택)';

  @override
  String get menuAddCategoryLabel => '분류';

  @override
  String get menuAddCategoryRequired => '분류를 선택하세요';

  @override
  String get menuAddAllowToppingsLabel => '토핑 허용';

  @override
  String get menuAddImageLabel => '사진 파일 이름 (선택)';

  @override
  String get menuAddImageHelp => '파일은 서버의 이미지 폴더에 이미 있어야 합니다.';

  @override
  String get menuAddNameError => '이름을 입력하세요 (최대 100자)';

  @override
  String get menuAddDescriptionError => '설명은 최대 500자입니다';

  @override
  String get menuAddImageError =>
      '파일 이름이 올바르지 않습니다. 소문자, 숫자, -만 사용하고 .jpg, .jpeg, .png 또는 .webp로 끝나야 합니다';

  @override
  String get menuAddDuplicate => '이 분류에 같은 이름의 메뉴가 이미 있습니다';

  @override
  String get menuFull => '메뉴가 가득 차서 더 추가할 수 없습니다';

  @override
  String menuAddedSnack(String name) {
    return '추가됨: $name';
  }
}
