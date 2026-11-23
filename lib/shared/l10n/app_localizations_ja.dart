// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitleCustomer => 'フードオーダー';

  @override
  String get appTitleRestaurant => 'フードオーダー — レストラン';

  @override
  String get statusAwaitingPayment => '支払い待ち';

  @override
  String get statusPreparing => '準備中';

  @override
  String get statusReady => 'お受け取り可能';

  @override
  String get statusDelivered => 'お渡し済み';

  @override
  String get statusCancelled => 'キャンセル済み';

  @override
  String get paymentCash => '現金';

  @override
  String get paymentBankTransfer => '銀行振込';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonSave => '保存';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonDownload => 'ダウンロード';

  @override
  String get staffLoginTitle => 'スタッフログイン';

  @override
  String get staffIdLabel => 'スタッフID';

  @override
  String get staffPasswordLabel => 'スタッフパスワード';

  @override
  String get staffPlainCharsError => 'アクセントのない通常の文字、数字、記号のみ使用してください';

  @override
  String get staffWrongCredentials => 'スタッフIDまたはパスワードが正しくありません';

  @override
  String get tooManyTriesLater => '試行の失敗が多すぎます。しばらくしてからもう一度お試しください。';

  @override
  String tooManyTriesWait(int seconds) {
    return '試行の失敗が多すぎます。$seconds秒後にもう一度お試しください。';
  }

  @override
  String get exportTitle => '月別の注文をエクスポート';

  @override
  String get exportMonthLabel => '月';

  @override
  String get exportReportLabel => 'レポートの種類';

  @override
  String get exportSummaryOption => '日別サマリーレポート（Excel）';

  @override
  String get exportDetailOption => '月内の各注文の詳細（Excel）';

  @override
  String get exportLinesOption => '注文明細の一覧（CSV）';

  @override
  String get exportDisabled => 'サーバーでエクスポートが無効になっています';

  @override
  String get exportNotConfigured => 'サーバーに店舗情報が設定されていません';

  @override
  String get exportFailed => 'データをエクスポートできませんでした。もう一度お試しください。';

  @override
  String get ordersTitle => '受信した注文';

  @override
  String get ordersEmpty => 'まだ注文はありません。お客様をお待ちしています…';

  @override
  String get ordersEditMenuTooltip => 'メニューを編集';

  @override
  String get ordersExportTooltip => '月別の注文をエクスポート';

  @override
  String orderNewFrom(String customerName) {
    return '$customerName様からの新しい注文';
  }

  @override
  String orderNewFromWaitingTransfer(String customerName) {
    return '$customerName様からの新しい注文 — 振込待ち';
  }

  @override
  String get orderUpdateFailed => '注文を更新できませんでした。もう一度お試しください。';

  @override
  String orderCardTitle(String shortId, String customerName) {
    return '注文 #$shortId — $customerName';
  }

  @override
  String orderTotal(String total) {
    return '合計：$total';
  }

  @override
  String get orderMarkReady => '準備完了にする';

  @override
  String get orderMarkDelivered => 'お渡し済みにする';

  @override
  String get orderUnpaid => '未払い';

  @override
  String orderTransferContent(String reference) {
    return '振込内容：$reference';
  }

  @override
  String get orderPaymentExpired => '支払い期限切れ';

  @override
  String get orderConfirmTransferReceived => '振込を確認済み';

  @override
  String get orderSwitchToCash => '現金払いに変更';

  @override
  String get payDisabled => 'この機能はサーバーで無効になっています';

  @override
  String get payTryLater => 'しばらくしてからもう一度お試しください。';

  @override
  String get payConflict => 'この注文はすでに処理されています';

  @override
  String get payFailed => '更新できませんでした。もう一度お試しください。';

  @override
  String get menuEditTitle => 'メニューを編集';

  @override
  String get menuLoadFailed => 'メニューを読み込めませんでした。';

  @override
  String get menuEmpty => 'メニューは空です。';

  @override
  String get menuInStock => '在庫あり';

  @override
  String get menuSoldOut => '売り切れ';

  @override
  String menuItemSubtitle(String price, String stock) {
    return '$price · $stock';
  }

  @override
  String menuEditPriceTooltip(String name) {
    return '$nameの価格を編集';
  }

  @override
  String menuInStockSemantics(String name) {
    return '在庫あり：$name';
  }

  @override
  String menuEditPriceTitle(String name) {
    return '$nameの価格を編集';
  }

  @override
  String get menuPriceLabel => '価格（VND）';

  @override
  String get menuPriceRangeError => '0から1,000,000までの整数を入力してください';

  @override
  String get menuPriceInvalid => '価格が正しくありません。0から1,000,000までの整数を入力してください';

  @override
  String get menuEditingDisabled => 'サーバーでメニュー編集が無効になっています';

  @override
  String get menuItemNotFound => 'この商品が見つかりません。ページを再読み込みしてください。';

  @override
  String get menuSaveFailed => '保存できませんでした。もう一度お試しください。';
}
