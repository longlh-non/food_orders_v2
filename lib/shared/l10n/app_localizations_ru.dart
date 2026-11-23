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
}
