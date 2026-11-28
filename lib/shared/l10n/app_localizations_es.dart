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
  String get statusFinished => 'Servido';

  @override
  String get orderMarkFinished => 'Marcar como servido';

  @override
  String get orderCheckPaidNote =>
      'Por favor, compruebe si el pedido ha sido pagado';

  @override
  String get orderCancel => 'Cancelar pedido';

  @override
  String get orderCancelConfirm => '¿Cancelar este pedido?';

  @override
  String get orderCancelPaidNote =>
      'Es posible que el cliente ya haya pagado. Gestione cualquier reembolso manualmente, fuera de la aplicación.';

  @override
  String get orderCancelFinalNote =>
      'Un pedido cancelado no se puede restaurar.';

  @override
  String get orderChangeStatus => 'Cambiar estado';

  @override
  String get orderChangeStatusFinishedNote => 'Esto cambia el informe mensual.';

  @override
  String get orderChangeStatusNotAllowed =>
      'No se puede cambiar el estado de este pedido.';

  @override
  String get orderChangeStatusCancelled =>
      'El pedido está cancelado y no se puede cambiar.';

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

  @override
  String get customerMenuTitle => 'Menú';

  @override
  String customerCartPriceChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Los precios de $count artículos del carrito han cambiado.',
      one: 'El precio de $count artículo del carrito ha cambiado.',
    );
    return '$_temp0';
  }

  @override
  String customerCartRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count artículos ya no están en el menú y se quitaron del carrito.',
      one: '$count artículo ya no está en el menú y se quitó del carrito.',
    );
    return '$_temp0';
  }

  @override
  String customerOrderStatusSnack(String shortId, String status) {
    return 'Pedido #$shortId: $status';
  }

  @override
  String customerOrderExpiredSnack(String shortId) {
    return 'Pedido #$shortId: el pago ha caducado';
  }

  @override
  String get customerMenuLoadFailed => 'No se pudo cargar el menú';

  @override
  String get customerCartTooltip => 'Carrito';

  @override
  String get customerCategoryFood => 'Comida';

  @override
  String get customerCategoryDrink => 'Bebidas';

  @override
  String get customerCategorySnack => 'Para picar';

  @override
  String get customerCategoryNibble => 'Tentempiés';

  @override
  String get customerCategoryEmpty => 'Aún no hay artículos en esta categoría';

  @override
  String get customerYourOrders => 'Tus pedidos';

  @override
  String get customerOrderExpired => 'Pago caducado';

  @override
  String customerAddItem(String name) {
    return 'Añadir $name';
  }

  @override
  String customerAdded(String names) {
    return 'Añadido: $names';
  }

  @override
  String get customerSoldOut => 'Agotado';

  @override
  String get customerCartTitle => 'Tu carrito';

  @override
  String get customerCartEmpty => 'Tu carrito está vacío.';

  @override
  String customerPricePerItem(String price) {
    return '$price / unidad';
  }

  @override
  String get customerNameLabel => 'Tu nombre';

  @override
  String get customerNameRequired => 'Introduce tu nombre';

  @override
  String customerCartTotal(String total) {
    return 'Total: $total';
  }

  @override
  String get customerOrderFailed =>
      'No se pudo realizar el pedido. Inténtalo de nuevo.';

  @override
  String get customerPlaceOrder => 'Hacer pedido';

  @override
  String get customerTransferOff =>
      'La transferencia bancaria no está activada';

  @override
  String customerOrderPlaced(String name) {
    return '¡Pedido realizado, $name!';
  }

  @override
  String get customerAddToppings => 'Añadir ingredientes extra';

  @override
  String get customerAddDrink => 'Añadir una bebida';

  @override
  String get customerChooseDrink => 'Elige una bebida';

  @override
  String get customerBack => 'Atrás';

  @override
  String get customerNext => 'Siguiente';

  @override
  String get customerAddButton => 'Añadir';

  @override
  String customerDishPrice(String name, String price) {
    return '$name: $price';
  }

  @override
  String get customerPayNotFound => 'No se encontró el pedido.';

  @override
  String get customerPayChecking => 'Comprobando el pago…';

  @override
  String get customerPayCancelled => 'Tu pedido fue cancelado.';

  @override
  String get customerPayReceived => 'Pago recibido. ¡Gracias!';

  @override
  String get customerPayCashOrder => 'Tu pedido se pagará en efectivo.';

  @override
  String get customerPayRecheck => 'Comprobar de nuevo';

  @override
  String get customerBackToMenu => 'Volver al menú';

  @override
  String get customerSwitchToCash => 'Cambiar a efectivo';

  @override
  String get customerPayInstruction =>
      'Haz la transferencia en 5 minutos para conservar tu pedido.';

  @override
  String customerCountdown(String time) {
    return 'Quedan $time';
  }

  @override
  String get customerBank => 'Banco';

  @override
  String get customerAccountNumber => 'Número de cuenta';

  @override
  String get customerAccountName => 'Titular de la cuenta';

  @override
  String get customerAmount => 'Importe';

  @override
  String get customerTransferContent => 'Concepto de la transferencia';

  @override
  String get customerQrLoadFailed => 'No se pudo cargar el código QR.';

  @override
  String get customerCashHint => 'Cambia a efectivo si no quieres pagar ahora';

  @override
  String get customerPayChanged =>
      'Tu pedido acaba de cambiar, comprobando de nuevo';

  @override
  String get customerPayActionFailed =>
      'No se pudo completar. Inténtalo de nuevo.';

  @override
  String get customerPayTooLate =>
      'Han pasado más de 15 minutos. Haz el pedido de nuevo o avisa al local.';

  @override
  String get customerPayExpired =>
      'El plazo de pago de tu pedido ha terminado. ¿Quieres pagar en efectivo?';

  @override
  String get customerPayTransferUnavailable =>
      'La transferencia bancaria no está disponible por ahora';

  @override
  String get customerNewQr => 'Crear un código QR nuevo';

  @override
  String get customerQrSemantics => 'Código QR de transferencia bancaria';

  @override
  String get menuAddTooltip => 'Añadir plato';

  @override
  String get menuAddTitle => 'Añadir un plato nuevo';

  @override
  String get menuAddAction => 'Añadir';

  @override
  String get menuAddNameLabel => 'Nombre';

  @override
  String get menuAddDescriptionLabel => 'Descripción (opcional)';

  @override
  String get menuAddCategoryLabel => 'Categoría';

  @override
  String get menuAddCategoryRequired => 'Elige una categoría';

  @override
  String get menuAddAllowToppingsLabel => 'Permitir extras';

  @override
  String get menuAddImageLabel => 'Nombre del archivo de imagen (opcional)';

  @override
  String get menuAddImageHelp =>
      'El archivo ya debe estar en la carpeta de imágenes del servidor.';

  @override
  String get menuAddNameError => 'Escribe un nombre, de hasta 100 caracteres';

  @override
  String get menuAddDescriptionError =>
      'La descripción admite hasta 500 caracteres';

  @override
  String get menuAddImageError =>
      'Nombre de archivo no válido. Usa minúsculas, dígitos y -, y termina en .jpg, .jpeg, .png o .webp';

  @override
  String get menuAddDuplicate =>
      'Ya existe un plato con ese nombre en esta categoría';

  @override
  String get menuFull => 'El menú está lleno, no se pueden añadir más platos';

  @override
  String menuAddedSnack(String name) {
    return 'Añadido: $name';
  }
}
