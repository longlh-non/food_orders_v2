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
}
