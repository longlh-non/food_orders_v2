// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitleCustomer => 'Essensbestellung';

  @override
  String get appTitleRestaurant => 'Essensbestellung — Restaurant';

  @override
  String get statusAwaitingPayment => 'Zahlung ausstehend';

  @override
  String get statusPreparing => 'In Zubereitung';

  @override
  String get statusReady => 'Abholbereit';

  @override
  String get statusDelivered => 'Ausgeliefert';

  @override
  String get statusCancelled => 'Storniert';

  @override
  String get paymentCash => 'Bargeld';

  @override
  String get paymentBankTransfer => 'Banküberweisung';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonDownload => 'Herunterladen';

  @override
  String get staffLoginTitle => 'Mitarbeiter-Anmeldung';

  @override
  String get staffIdLabel => 'Mitarbeiter-ID';

  @override
  String get staffPasswordLabel => 'Mitarbeiter-Passwort';

  @override
  String get staffPlainCharsError =>
      'Nur einfache Buchstaben ohne Akzente, Ziffern und Symbole verwenden';

  @override
  String get staffWrongCredentials => 'Mitarbeiter-ID oder Passwort falsch';

  @override
  String get tooManyTriesLater =>
      'Zu viele Fehlversuche. Bitte später erneut versuchen.';

  @override
  String tooManyTriesWait(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Zu viele Fehlversuche. In $seconds Sekunden erneut versuchen.',
      one: 'Zu viele Fehlversuche. In $seconds Sekunde erneut versuchen.',
    );
    return '$_temp0';
  }

  @override
  String get exportTitle => 'Bestellungen des Monats exportieren';

  @override
  String get exportMonthLabel => 'Monat';

  @override
  String get exportReportLabel => 'Berichtstyp';

  @override
  String get exportSummaryOption => 'Tageszusammenfassung (Excel)';

  @override
  String get exportDetailOption => 'Details jeder Bestellung im Monat (Excel)';

  @override
  String get exportLinesOption => 'Liste der Bestellpositionen (CSV)';

  @override
  String get exportDisabled => 'Der Export ist auf dem Server deaktiviert';

  @override
  String get exportNotConfigured =>
      'Die Geschäftsdaten sind auf dem Server nicht eingerichtet';

  @override
  String get exportFailed =>
      'Daten konnten nicht exportiert werden. Bitte erneut versuchen.';

  @override
  String get ordersTitle => 'Eingehende Bestellungen';

  @override
  String get ordersEmpty => 'Noch keine Bestellungen. Warten auf Kunden …';

  @override
  String get ordersEditMenuTooltip => 'Speisekarte bearbeiten';

  @override
  String get ordersExportTooltip => 'Bestellungen des Monats exportieren';

  @override
  String orderNewFrom(String customerName) {
    return 'Neue Bestellung von $customerName';
  }

  @override
  String orderNewFromWaitingTransfer(String customerName) {
    return 'Neue Bestellung von $customerName — wartet auf Überweisung';
  }

  @override
  String get orderUpdateFailed =>
      'Bestellung konnte nicht aktualisiert werden. Bitte erneut versuchen.';

  @override
  String orderCardTitle(String shortId, String customerName) {
    return 'Bestellung #$shortId — $customerName';
  }

  @override
  String orderTotal(String total) {
    return 'Gesamt: $total';
  }

  @override
  String get orderMarkReady => 'Als bereit markieren';

  @override
  String get orderMarkDelivered => 'Als ausgeliefert markieren';

  @override
  String get orderUnpaid => 'Noch nicht bezahlt';

  @override
  String orderTransferContent(String reference) {
    return 'Verwendungszweck: $reference';
  }

  @override
  String get orderPaymentExpired => 'Zahlungsfrist abgelaufen';

  @override
  String get orderConfirmTransferReceived => 'Überweisung erhalten';

  @override
  String get orderSwitchToCash => 'Auf Bargeld umstellen';

  @override
  String get payDisabled => 'Diese Funktion ist auf dem Server deaktiviert';

  @override
  String get payTryLater => 'Bitte später erneut versuchen.';

  @override
  String get payConflict => 'Diese Bestellung wurde bereits bearbeitet';

  @override
  String get payFailed =>
      'Aktualisierung fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get menuEditTitle => 'Speisekarte bearbeiten';

  @override
  String get menuLoadFailed => 'Die Speisekarte konnte nicht geladen werden.';

  @override
  String get menuEmpty => 'Die Speisekarte ist leer.';

  @override
  String get menuInStock => 'Verfügbar';

  @override
  String get menuSoldOut => 'Ausverkauft';

  @override
  String menuItemSubtitle(String price, String stock) {
    return '$price · $stock';
  }

  @override
  String menuEditPriceTooltip(String name) {
    return 'Preis von $name ändern';
  }

  @override
  String menuInStockSemantics(String name) {
    return 'Verfügbar: $name';
  }

  @override
  String menuEditPriceTitle(String name) {
    return 'Preis von $name ändern';
  }

  @override
  String get menuPriceLabel => 'Preis (VND)';

  @override
  String get menuPriceRangeError => 'Ganze Zahl von 0 bis 1.000.000 eingeben';

  @override
  String get menuPriceInvalid =>
      'Ungültiger Preis. Ganze Zahl von 0 bis 1.000.000 eingeben';

  @override
  String get menuEditingDisabled =>
      'Das Bearbeiten der Speisekarte ist auf dem Server deaktiviert';

  @override
  String get menuItemNotFound =>
      'Dieser Artikel wurde nicht gefunden. Seite neu laden.';

  @override
  String get menuSaveFailed =>
      'Speichern fehlgeschlagen. Bitte erneut versuchen.';
}
