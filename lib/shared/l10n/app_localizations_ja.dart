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

  @override
  String get customerMenuTitle => 'メニュー';

  @override
  String customerCartPriceChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'カート内の$count品の価格が変更されました。',
    );
    return '$_temp0';
  }

  @override
  String customerCartRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count品がメニューから外れたため、カートから削除されました。',
    );
    return '$_temp0';
  }

  @override
  String customerOrderStatusSnack(String shortId, String status) {
    return '注文 #$shortId: $status';
  }

  @override
  String customerOrderExpiredSnack(String shortId) {
    return '注文 #$shortId: 支払い期限が切れました';
  }

  @override
  String get customerMenuLoadFailed => 'メニューを読み込めませんでした';

  @override
  String get customerCartTooltip => 'カート';

  @override
  String get customerCategoryFood => '料理';

  @override
  String get customerCategoryDrink => 'ドリンク';

  @override
  String get customerCategorySnack => '軽食';

  @override
  String get customerCategoryNibble => 'おやつ';

  @override
  String get customerCategoryEmpty => 'このカテゴリにはまだ商品がありません';

  @override
  String get customerYourOrders => 'ご注文';

  @override
  String get customerOrderExpired => '支払い期限切れ';

  @override
  String customerAddItem(String name) {
    return '$nameを追加';
  }

  @override
  String customerAdded(String names) {
    return '$namesを追加しました';
  }

  @override
  String get customerSoldOut => '売り切れ';

  @override
  String get customerCartTitle => 'カート';

  @override
  String get customerCartEmpty => 'カートは空です。';

  @override
  String customerPricePerItem(String price) {
    return '$price / 品';
  }

  @override
  String get customerNameLabel => 'お名前';

  @override
  String get customerNameRequired => 'お名前を入力してください';

  @override
  String customerCartTotal(String total) {
    return '合計: $total';
  }

  @override
  String get customerOrderFailed => '注文できませんでした。もう一度お試しください。';

  @override
  String get customerPlaceOrder => '注文する';

  @override
  String get customerTransferOff => '銀行振込は有効になっていません';

  @override
  String customerOrderPlaced(String name) {
    return 'ご注文ありがとうございます、$nameさん！';
  }

  @override
  String get customerAddToppings => 'トッピングを追加';

  @override
  String get customerAddDrink => 'ドリンクを追加';

  @override
  String get customerChooseDrink => 'ドリンクを選択';

  @override
  String get customerBack => '戻る';

  @override
  String get customerNext => '次へ';

  @override
  String get customerAddButton => '追加';

  @override
  String customerDishPrice(String name, String price) {
    return '$name: $price';
  }

  @override
  String get customerPayNotFound => '注文が見つかりません。';

  @override
  String get customerPayChecking => '支払いを確認しています…';

  @override
  String get customerPayCancelled => 'ご注文はキャンセルされました。';

  @override
  String get customerPayReceived => 'お支払いを確認しました。ありがとうございます！';

  @override
  String get customerPayCashOrder => 'ご注文は現金でのお支払いになります。';

  @override
  String get customerPayRecheck => '再確認';

  @override
  String get customerBackToMenu => 'メニューに戻る';

  @override
  String get customerSwitchToCash => '現金払いに変更';

  @override
  String get customerPayInstruction => 'ご注文を保持するため、5分以内にお振込みください。';

  @override
  String customerCountdown(String time) {
    return '残り $time';
  }

  @override
  String get customerBank => '銀行';

  @override
  String get customerAccountNumber => '口座番号';

  @override
  String get customerAccountName => '口座名義';

  @override
  String get customerAmount => '金額';

  @override
  String get customerTransferContent => '振込内容';

  @override
  String get customerQrLoadFailed => 'QRコードを読み込めませんでした。';

  @override
  String get customerCashHint => '今すぐ支払わない場合は現金払いに変更してください';

  @override
  String get customerPayChanged => '注文が更新されました。再確認しています';

  @override
  String get customerPayActionFailed => '実行できませんでした。もう一度お試しください。';

  @override
  String get customerPayTooLate => '15分以上経過しました。もう一度注文するか、お店にお知らせください。';

  @override
  String get customerPayExpired => 'ご注文の支払い期限が切れました。現金払いに変更しますか？';

  @override
  String get customerPayTransferUnavailable => '銀行振込は一時的にご利用いただけません';

  @override
  String get customerNewQr => '新しいQRコードを作成';

  @override
  String get customerQrSemantics => '銀行振込のQRコード';

  @override
  String get menuAddTooltip => 'メニューを追加';

  @override
  String get menuAddTitle => '新しいメニューを追加';

  @override
  String get menuAddAction => '追加';

  @override
  String get menuAddNameLabel => '名前';

  @override
  String get menuAddDescriptionLabel => '説明（任意）';

  @override
  String get menuAddCategoryLabel => 'カテゴリ';

  @override
  String get menuAddCategoryRequired => 'カテゴリを選んでください';

  @override
  String get menuAddAllowToppingsLabel => 'トッピングを許可';

  @override
  String get menuAddImageLabel => '画像ファイル名（任意）';

  @override
  String get menuAddImageHelp => 'ファイルはサーバーの画像フォルダーにすでに置いてある必要があります。';

  @override
  String get menuAddNameError => '名前を入力してください（100文字まで）';

  @override
  String get menuAddDescriptionError => '説明は500文字までです';

  @override
  String get menuAddImageError =>
      'ファイル名が正しくありません。小文字、数字、- のみで、末尾は .jpg、.jpeg、.png、.webp にしてください';

  @override
  String get menuAddDuplicate => 'このカテゴリには同じ名前のメニューがすでにあります';

  @override
  String get menuFull => 'メニューがいっぱいで、これ以上追加できません';

  @override
  String menuAddedSnack(String name) {
    return '追加しました：$name';
  }
}
