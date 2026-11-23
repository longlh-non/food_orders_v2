// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitleCustomer => 'Commande de repas';

  @override
  String get appTitleRestaurant => 'Commande de repas — Restaurant';

  @override
  String get statusAwaitingPayment => 'En attente de paiement';

  @override
  String get statusPreparing => 'En préparation';

  @override
  String get statusReady => 'Prêt à être retiré';

  @override
  String get statusDelivered => 'Livré';

  @override
  String get statusCancelled => 'Annulé';

  @override
  String get paymentCash => 'Espèces';

  @override
  String get paymentBankTransfer => 'Virement bancaire';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonDownload => 'Télécharger';

  @override
  String get staffLoginTitle => 'Connexion du personnel';

  @override
  String get staffIdLabel => 'Identifiant du personnel';

  @override
  String get staffPasswordLabel => 'Mot de passe du personnel';

  @override
  String get staffPlainCharsError =>
      'Utilisez uniquement des lettres sans accents, des chiffres et des symboles courants';

  @override
  String get staffWrongCredentials =>
      'Identifiant ou mot de passe du personnel incorrect';

  @override
  String get tooManyTriesLater =>
      'Trop de tentatives échouées. Réessayez plus tard.';

  @override
  String tooManyTriesWait(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Trop de tentatives échouées. Réessayez dans $seconds secondes.',
      one: 'Trop de tentatives échouées. Réessayez dans $seconds seconde.',
    );
    return '$_temp0';
  }

  @override
  String get exportTitle => 'Exporter les commandes du mois';

  @override
  String get exportMonthLabel => 'Mois';

  @override
  String get exportReportLabel => 'Type de rapport';

  @override
  String get exportSummaryOption => 'Rapport récapitulatif quotidien (Excel)';

  @override
  String get exportDetailOption => 'Détail de chaque commande du mois (Excel)';

  @override
  String get exportLinesOption => 'Liste des lignes de commande (CSV)';

  @override
  String get exportDisabled => 'L\'exportation est désactivée sur le serveur';

  @override
  String get exportNotConfigured =>
      'Les informations du commerce ne sont pas configurées sur le serveur';

  @override
  String get exportFailed => 'Impossible d\'exporter les données. Réessayez.';

  @override
  String get ordersTitle => 'Commandes entrantes';

  @override
  String get ordersEmpty =>
      'Aucune commande pour l\'instant. En attente de clients…';

  @override
  String get ordersEditMenuTooltip => 'Modifier le menu';

  @override
  String get ordersExportTooltip => 'Exporter les commandes du mois';

  @override
  String orderNewFrom(String customerName) {
    return 'Nouvelle commande de $customerName';
  }

  @override
  String orderNewFromWaitingTransfer(String customerName) {
    return 'Nouvelle commande de $customerName — en attente de virement';
  }

  @override
  String get orderUpdateFailed =>
      'Impossible de mettre à jour la commande. Réessayez.';

  @override
  String orderCardTitle(String shortId, String customerName) {
    return 'Commande #$shortId — $customerName';
  }

  @override
  String orderTotal(String total) {
    return 'Total : $total';
  }

  @override
  String get orderMarkReady => 'Marquer comme prêt';

  @override
  String get orderMarkDelivered => 'Marquer comme livré';

  @override
  String get orderUnpaid => 'Non payé';

  @override
  String orderTransferContent(String reference) {
    return 'Référence du virement : $reference';
  }

  @override
  String get orderPaymentExpired => 'Paiement expiré';

  @override
  String get orderConfirmTransferReceived => 'Virement reçu';

  @override
  String get orderSwitchToCash => 'Passer en espèces';

  @override
  String get payDisabled => 'Cette fonction est désactivée sur le serveur';

  @override
  String get payTryLater => 'Réessayez plus tard.';

  @override
  String get payConflict => 'Cette commande a déjà été traitée';

  @override
  String get payFailed => 'Impossible de mettre à jour. Réessayez.';

  @override
  String get menuEditTitle => 'Modifier le menu';

  @override
  String get menuLoadFailed => 'Impossible de charger le menu.';

  @override
  String get menuEmpty => 'Le menu est vide.';

  @override
  String get menuInStock => 'En stock';

  @override
  String get menuSoldOut => 'Épuisé';

  @override
  String menuItemSubtitle(String price, String stock) {
    return '$price · $stock';
  }

  @override
  String menuEditPriceTooltip(String name) {
    return 'Modifier le prix de $name';
  }

  @override
  String menuInStockSemantics(String name) {
    return 'En stock : $name';
  }

  @override
  String menuEditPriceTitle(String name) {
    return 'Modifier le prix de $name';
  }

  @override
  String get menuPriceLabel => 'Prix (VND)';

  @override
  String get menuPriceRangeError =>
      'Saisissez un nombre entier de 0 à 1 000 000';

  @override
  String get menuPriceInvalid =>
      'Prix invalide. Saisissez un nombre entier de 0 à 1 000 000';

  @override
  String get menuEditingDisabled =>
      'La modification du menu est désactivée sur le serveur';

  @override
  String get menuItemNotFound => 'Article introuvable. Rechargez la page.';

  @override
  String get menuSaveFailed => 'Enregistrement impossible. Réessayez.';
}
