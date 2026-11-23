// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitleCustomer => 'Заказ еды';

  @override
  String get appTitleRestaurant => 'Заказ еды — Ресторан';

  @override
  String get statusAwaitingPayment => 'Ожидает оплаты';

  @override
  String get statusPreparing => 'Готовится';

  @override
  String get statusReady => 'Готов к выдаче';

  @override
  String get statusDelivered => 'Выдан';

  @override
  String get statusCancelled => 'Отменён';

  @override
  String get paymentCash => 'Наличные';

  @override
  String get paymentBankTransfer => 'Банковский перевод';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonConfirm => 'Подтвердить';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonDownload => 'Скачать';

  @override
  String get staffLoginTitle => 'Вход для сотрудников';

  @override
  String get staffIdLabel => 'ID сотрудника';

  @override
  String get staffPasswordLabel => 'Пароль сотрудника';

  @override
  String get staffPlainCharsError =>
      'Используйте только обычные буквы без диакритики, цифры и символы';

  @override
  String get staffWrongCredentials => 'Неверный ID сотрудника или пароль';

  @override
  String get tooManyTriesLater =>
      'Слишком много неудачных попыток. Повторите позже.';

  @override
  String tooManyTriesWait(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other:
          'Слишком много неудачных попыток. Повторите через $seconds секунды.',
      many: 'Слишком много неудачных попыток. Повторите через $seconds секунд.',
      few: 'Слишком много неудачных попыток. Повторите через $seconds секунды.',
      one: 'Слишком много неудачных попыток. Повторите через $seconds секунду.',
    );
    return '$_temp0';
  }

  @override
  String get exportTitle => 'Экспорт заказов за месяц';

  @override
  String get exportMonthLabel => 'Месяц';

  @override
  String get exportReportLabel => 'Тип отчёта';

  @override
  String get exportSummaryOption => 'Сводный отчёт по дням (Excel)';

  @override
  String get exportDetailOption =>
      'Подробности по каждому заказу за месяц (Excel)';

  @override
  String get exportLinesOption => 'Список позиций заказов (CSV)';

  @override
  String get exportDisabled => 'Экспорт отключён на сервере';

  @override
  String get exportNotConfigured => 'Данные заведения не настроены на сервере';

  @override
  String get exportFailed =>
      'Не удалось экспортировать данные. Повторите попытку.';

  @override
  String get ordersTitle => 'Входящие заказы';

  @override
  String get ordersEmpty => 'Заказов пока нет. Ждём клиентов…';

  @override
  String get ordersEditMenuTooltip => 'Редактировать меню';

  @override
  String get ordersExportTooltip => 'Экспорт заказов за месяц';

  @override
  String orderNewFrom(String customerName) {
    return 'Новый заказ от $customerName';
  }

  @override
  String orderNewFromWaitingTransfer(String customerName) {
    return 'Новый заказ от $customerName — ожидает банковского перевода';
  }

  @override
  String get orderUpdateFailed =>
      'Не удалось обновить заказ. Повторите попытку.';

  @override
  String orderCardTitle(String shortId, String customerName) {
    return 'Заказ #$shortId — $customerName';
  }

  @override
  String orderTotal(String total) {
    return 'Итого: $total';
  }

  @override
  String get orderMarkReady => 'Отметить готовым';

  @override
  String get orderMarkDelivered => 'Отметить выданным';

  @override
  String get orderUnpaid => 'Не оплачен';

  @override
  String orderTransferContent(String reference) {
    return 'Назначение перевода: $reference';
  }

  @override
  String get orderPaymentExpired => 'Время оплаты истекло';

  @override
  String get orderConfirmTransferReceived => 'Перевод получен';

  @override
  String get orderSwitchToCash => 'Перейти на наличные';

  @override
  String get payDisabled => 'Эта функция отключена на сервере';

  @override
  String get payTryLater => 'Повторите позже.';

  @override
  String get payConflict => 'Этот заказ уже обработан';

  @override
  String get payFailed => 'Не удалось обновить. Повторите попытку.';

  @override
  String get menuEditTitle => 'Редактирование меню';

  @override
  String get menuLoadFailed => 'Меню не удалось загрузить.';

  @override
  String get menuEmpty => 'Меню пусто.';

  @override
  String get menuInStock => 'В наличии';

  @override
  String get menuSoldOut => 'Нет в наличии';

  @override
  String menuItemSubtitle(String price, String stock) {
    return '$price · $stock';
  }

  @override
  String menuEditPriceTooltip(String name) {
    return 'Изменить цену: $name';
  }

  @override
  String menuInStockSemantics(String name) {
    return 'В наличии: $name';
  }

  @override
  String menuEditPriceTitle(String name) {
    return 'Изменить цену: $name';
  }

  @override
  String get menuPriceLabel => 'Цена (VND)';

  @override
  String get menuPriceRangeError => 'Введите целое число от 0 до 1 000 000';

  @override
  String get menuPriceInvalid =>
      'Недопустимая цена. Введите целое число от 0 до 1 000 000';

  @override
  String get menuEditingDisabled => 'Редактирование меню отключено на сервере';

  @override
  String get menuItemNotFound => 'Элемент не найден. Перезагрузите страницу.';

  @override
  String get menuSaveFailed => 'Не удалось сохранить. Повторите попытку.';

  @override
  String get customerMenuTitle => 'Меню';

  @override
  String customerCartPriceChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Цены $count товара в корзине изменились.',
      many: 'Цены $count товаров в корзине изменились.',
      few: 'Цены $count товаров в корзине изменились.',
      one: 'Цена $count товара в корзине изменилась.',
    );
    return '$_temp0';
  }

  @override
  String customerCartRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count блюда больше нет в меню, оно удалено из корзины.',
      many: '$count блюд больше нет в меню, они удалены из корзины.',
      few: '$count блюд больше нет в меню, они удалены из корзины.',
      one: '$count блюда больше нет в меню, оно удалено из корзины.',
    );
    return '$_temp0';
  }

  @override
  String customerOrderStatusSnack(String shortId, String status) {
    return 'Заказ #$shortId: $status';
  }

  @override
  String customerOrderExpiredSnack(String shortId) {
    return 'Заказ #$shortId: время оплаты истекло';
  }

  @override
  String get customerMenuLoadFailed => 'Не удалось загрузить меню';

  @override
  String get customerCartTooltip => 'Корзина';

  @override
  String get customerCategoryFood => 'Еда';

  @override
  String get customerCategoryDrink => 'Напитки';

  @override
  String get customerCategorySnack => 'Закуски';

  @override
  String get customerCategoryNibble => 'Перекусы';

  @override
  String get customerCategoryEmpty => 'В этой категории пока нет блюд';

  @override
  String get customerYourOrders => 'Ваши заказы';

  @override
  String get customerOrderExpired => 'Время оплаты истекло';

  @override
  String customerAddItem(String name) {
    return 'Добавить: $name';
  }

  @override
  String customerAdded(String names) {
    return 'Добавлено: $names';
  }

  @override
  String get customerSoldOut => 'Нет в наличии';

  @override
  String get customerCartTitle => 'Ваша корзина';

  @override
  String get customerCartEmpty => 'Корзина пуста.';

  @override
  String customerPricePerItem(String price) {
    return '$price / шт.';
  }

  @override
  String get customerNameLabel => 'Ваше имя';

  @override
  String get customerNameRequired => 'Пожалуйста, введите ваше имя';

  @override
  String customerCartTotal(String total) {
    return 'Итого: $total';
  }

  @override
  String get customerOrderFailed =>
      'Не удалось оформить заказ. Попробуйте ещё раз.';

  @override
  String get customerPlaceOrder => 'Оформить заказ';

  @override
  String get customerTransferOff => 'Банковский перевод не включён';

  @override
  String customerOrderPlaced(String name) {
    return 'Заказ оформлен, $name!';
  }

  @override
  String get customerAddToppings => 'Добавить топпинги';

  @override
  String get customerAddDrink => 'Добавить напиток';

  @override
  String get customerChooseDrink => 'Выберите напиток';

  @override
  String get customerBack => 'Назад';

  @override
  String get customerNext => 'Далее';

  @override
  String get customerAddButton => 'Добавить';

  @override
  String customerDishPrice(String name, String price) {
    return '$name: $price';
  }

  @override
  String get customerPayNotFound => 'Заказ не найден.';

  @override
  String get customerPayChecking => 'Проверяем оплату…';

  @override
  String get customerPayCancelled => 'Ваш заказ отменён.';

  @override
  String get customerPayReceived => 'Оплата получена. Спасибо!';

  @override
  String get customerPayCashOrder => 'Ваш заказ будет оплачен наличными.';

  @override
  String get customerPayRecheck => 'Проверить снова';

  @override
  String get customerBackToMenu => 'Назад в меню';

  @override
  String get customerSwitchToCash => 'Перейти на оплату наличными';

  @override
  String get customerPayInstruction =>
      'Переведите деньги в течение 5 минут, чтобы сохранить заказ.';

  @override
  String customerCountdown(String time) {
    return 'Осталось $time';
  }

  @override
  String get customerBank => 'Банк';

  @override
  String get customerAccountNumber => 'Номер счёта';

  @override
  String get customerAccountName => 'Владелец счёта';

  @override
  String get customerAmount => 'Сумма';

  @override
  String get customerTransferContent => 'Назначение платежа';

  @override
  String get customerQrLoadFailed => 'Не удалось загрузить QR-код.';

  @override
  String get customerCashHint =>
      'Перейдите на оплату наличными, если не хотите платить сейчас';

  @override
  String get customerPayChanged =>
      'Ваш заказ только что изменился, проверяем снова';

  @override
  String get customerPayActionFailed => 'Не получилось. Попробуйте ещё раз.';

  @override
  String get customerPayTooLate =>
      'Прошло более 15 минут. Оформите заказ заново или сообщите в заведение.';

  @override
  String get customerPayExpired =>
      'Время оплаты вашего заказа истекло. Хотите заплатить наличными?';

  @override
  String get customerPayTransferUnavailable =>
      'Банковский перевод временно недоступен';

  @override
  String get customerNewQr => 'Создать новый QR-код';

  @override
  String get customerQrSemantics => 'QR-код для банковского перевода';
}
