// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitleCustomer => 'Pedir comida';

  @override
  String get appTitleRestaurant => 'Pedir comida — Restaurante';

  @override
  String get statusAwaitingPayment => 'Pendiente de pago';

  @override
  String get statusPreparing => 'En preparación';

  @override
  String get statusReady => 'Listo para recoger';

  @override
  String get statusDelivered => 'Entregado';

  @override
  String get statusCancelled => 'Cancelado';

  @override
  String get paymentCash => 'Efectivo';

  @override
  String get paymentBankTransfer => 'Transferencia bancaria';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonDownload => 'Descargar';

  @override
  String get staffLoginTitle => 'Acceso del personal';

  @override
  String get staffIdLabel => 'ID de personal';

  @override
  String get staffPasswordLabel => 'Contraseña del personal';

  @override
  String get staffPlainCharsError =>
      'Usa solo letras sin acentos, números y símbolos comunes';

  @override
  String get staffWrongCredentials => 'ID de personal o contraseña incorrectos';

  @override
  String get tooManyTriesLater =>
      'Demasiados intentos fallidos. Inténtalo de nuevo más tarde.';

  @override
  String tooManyTriesWait(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other:
          'Demasiados intentos fallidos. Inténtalo de nuevo en $seconds segundos.',
      one:
          'Demasiados intentos fallidos. Inténtalo de nuevo en $seconds segundo.',
    );
    return '$_temp0';
  }

  @override
  String get exportTitle => 'Exportar pedidos del mes';

  @override
  String get exportMonthLabel => 'Mes';

  @override
  String get exportReportLabel => 'Tipo de informe';

  @override
  String get exportSummaryOption => 'Informe resumen diario (Excel)';

  @override
  String get exportDetailOption => 'Detalle de cada pedido del mes (Excel)';

  @override
  String get exportLinesOption => 'Lista de líneas de pedido (CSV)';

  @override
  String get exportDisabled => 'La exportación está desactivada en el servidor';

  @override
  String get exportNotConfigured =>
      'Los datos del local no están configurados en el servidor';

  @override
  String get exportFailed =>
      'No se pudieron exportar los datos. Inténtalo de nuevo.';

  @override
  String get ordersTitle => 'Pedidos entrantes';

  @override
  String get ordersEmpty => 'Aún no hay pedidos. Esperando clientes…';

  @override
  String get ordersEditMenuTooltip => 'Editar menú';

  @override
  String get ordersExportTooltip => 'Exportar pedidos del mes';

  @override
  String orderNewFrom(String customerName) {
    return 'Pedido nuevo de $customerName';
  }

  @override
  String orderNewFromWaitingTransfer(String customerName) {
    return 'Pedido nuevo de $customerName — pendiente de transferencia';
  }

  @override
  String get orderUpdateFailed =>
      'No se pudo actualizar el pedido. Inténtalo de nuevo.';

  @override
  String orderCardTitle(String shortId, String customerName) {
    return 'Pedido #$shortId — $customerName';
  }

  @override
  String orderTotal(String total) {
    return 'Total: $total';
  }

  @override
  String get orderMarkReady => 'Marcar como listo';

  @override
  String get orderMarkDelivered => 'Marcar como entregado';

  @override
  String get orderUnpaid => 'Sin pagar';

  @override
  String orderTransferContent(String reference) {
    return 'Concepto de la transferencia: $reference';
  }

  @override
  String get orderPaymentExpired => 'Pago caducado';

  @override
  String get orderConfirmTransferReceived => 'Transferencia recibida';

  @override
  String get orderSwitchToCash => 'Cambiar a efectivo';

  @override
  String get payDisabled => 'Esta función está desactivada en el servidor';

  @override
  String get payTryLater => 'Inténtalo de nuevo más tarde.';

  @override
  String get payConflict => 'Este pedido ya fue gestionado';

  @override
  String get payFailed => 'No se pudo actualizar. Inténtalo de nuevo.';

  @override
  String get menuEditTitle => 'Editar menú';

  @override
  String get menuLoadFailed => 'No se pudo cargar el menú.';

  @override
  String get menuEmpty => 'El menú está vacío.';

  @override
  String get menuInStock => 'Disponible';

  @override
  String get menuSoldOut => 'Agotado';

  @override
  String menuItemSubtitle(String price, String stock) {
    return '$price · $stock';
  }

  @override
  String menuEditPriceTooltip(String name) {
    return 'Editar precio de $name';
  }

  @override
  String menuInStockSemantics(String name) {
    return 'Disponible: $name';
  }

  @override
  String menuEditPriceTitle(String name) {
    return 'Editar precio de $name';
  }

  @override
  String get menuPriceLabel => 'Precio (VND)';

  @override
  String get menuPriceRangeError =>
      'Introduce un número entero de 0 a 1.000.000';

  @override
  String get menuPriceInvalid =>
      'Precio no válido. Introduce un número entero de 0 a 1.000.000';

  @override
  String get menuEditingDisabled =>
      'La edición del menú está desactivada en el servidor';

  @override
  String get menuItemNotFound =>
      'No se encontró este artículo. Recarga la página.';

  @override
  String get menuSaveFailed => 'No se pudo guardar. Inténtalo de nuevo.';
}
