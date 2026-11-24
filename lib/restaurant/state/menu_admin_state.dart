import 'package:flutter/foundation.dart';

import '../../shared/api/order_api_client.dart';
import '../../shared/models/menu_item.dart';
import '../api/menu_admin_client.dart';
import 'staff_credentials.dart';

/// The highest price the server accepts (VND), same as the backend's rule.
const maxMenuPrice = 1000000;

/// Turns what staff typed in the price field into a price in VND, or null
/// when it isn't one. Only a whole number written with digits is accepted
/// (no sign, no decimals, no separators), from 0 to [maxMenuPrice]. The
/// server checks again; this keeps obviously bad input from being sent.
int? parseMenuPrice(String text) {
  final trimmed = text.trim();
  if (!RegExp(r'^[0-9]{1,7}$').hasMatch(trimmed)) return null;
  final value = int.parse(trimmed);
  return value <= maxMenuPrice ? value : null;
}

/// The most characters (UTF-16 units) of a new item's name, after trimming.
/// Keep in step with `maxMenuNameUnits` in `backend/lib/menu_api.dart`.
const maxMenuNameUnits = 100;

/// The most characters (UTF-16 units) of a new item's description. Keep in
/// step with `maxMenuDescriptionUnits` in `backend/lib/menu_api.dart`.
const maxMenuDescriptionUnits = 500;

/// The first thing wrong with a new item, found without asking the server.
/// The form turns it into text in the user's language.
enum NewItemProblem {
  nameEmpty,
  nameTooLong,
  nameBadCharacters,
  descriptionTooLong,
  descriptionBadCharacters,
  priceInvalid,
  toppingsNeedFood,
  imageInvalid,
}

bool _hasControl(String text, {bool allowNewline = false}) {
  for (final unit in text.codeUnits) {
    if (allowNewline && unit == 0x0A) continue;
    if (unit < 0x20 || (unit >= 0x7F && unit <= 0x9F)) return true;
  }
  return false;
}

/// Checks a new item against the same limits as the server and returns the
/// first problem, or null when it looks fine. [priceText] is what staff typed
/// (see [parseMenuPrice]); [image] is a picture file name or null. The
/// server checks again.
NewItemProblem? validateNewItem({
  required String name,
  required String description,
  required String priceText,
  required MenuCategory category,
  required bool allowToppings,
  required String? image,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return NewItemProblem.nameEmpty;
  if (trimmed.length > maxMenuNameUnits) return NewItemProblem.nameTooLong;
  if (_hasControl(trimmed)) return NewItemProblem.nameBadCharacters;
  if (description.length > maxMenuDescriptionUnits) {
    return NewItemProblem.descriptionTooLong;
  }
  if (_hasControl(description, allowNewline: true)) {
    return NewItemProblem.descriptionBadCharacters;
  }
  if (parseMenuPrice(priceText) == null) return NewItemProblem.priceInvalid;
  if (allowToppings && category != MenuCategory.food) {
    return NewItemProblem.toppingsNeedFood;
  }
  if (image != null && !menuImageName.hasMatch(image)) {
    return NewItemProblem.imageInvalid;
  }
  return null;
}

/// What happened to a [MenuAdminState.setPrice] / [MenuAdminState.setAvailable]
/// / [MenuAdminState.addItem] call.
enum MenuSaveResult {
  /// The server accepted it and the item was replaced by its reply.
  saved,

  /// It failed; [MenuAdminState.saveError] says why and the item is unchanged.
  failed,

  /// There are no (or no longer valid) staff credentials. Ask staff for them
  /// and call again. Nothing was changed.
  needsCredentials,

  /// Ignored: that row is already saving, or the state was disposed.
  ignored,
}

/// Why the last save failed. The page turns it into text in the user's
/// language (this class has no `BuildContext` and holds no wording).
enum MenuSaveError {
  /// The server refused the staff ID or password (401).
  wrongCredentials,

  /// Menu editing is switched off on the server (403).
  editingDisabled,

  /// Too many wrong attempts (429); see [MenuAdminState.saveErrorWaitSeconds].
  tooManyTries,

  /// The item is not on the server's menu (404).
  notFound,

  /// The price is not valid (or, when adding, the server refused the item).
  invalid,

  /// Adding: an item with that name already exists in that category (409).
  duplicate,

  /// Adding: the menu is full (503).
  menuFull,

  /// Anything else.
  other,
}

/// The restaurant app's copy of the menu for the editing screen.
///
/// Loads the menu with `GET /api/menu` and changes a price or the sold-out
/// switch through [MenuAdminClient]. The staff ID and password come from
/// [StaffCredentialsHolder] (memory only); this class never keeps, prints or
/// shows them. Notifies listeners on every change; the page rebuilds from it.
/// Restaurant-only: it is not shared with the customer's `MenuState`.
class MenuAdminState extends ChangeNotifier {
  MenuAdminState({
    required this._api,
    required this._admin,
    StaffCredentialsHolder? holder,
  }) : _holder = holder ?? StaffCredentialsHolder.instance;

  final OrderApiClient _api;
  final MenuAdminClient _admin;
  final StaffCredentialsHolder _holder;

  List<MenuItem> _items = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _loadFailed = false;
  final _saving = <String>{};
  MenuSaveError? _saveError;
  int? _saveErrorWaitSeconds;
  bool _adding = false;
  bool _disposed = false;

  /// True while a new item is being added; the form should be disabled.
  bool get isAdding => _adding;

  /// The menu as last loaded or saved (empty until the first load).
  List<MenuItem> get items => _items;
  bool get isLoading => _isLoading;

  /// True once a load has succeeded; tells "not loaded yet" from "empty".
  bool get hasLoaded => _hasLoaded;

  /// True when the last [load] failed (and nothing was loaded before).
  bool get loadFailed => _loadFailed;

  /// Why the last save failed, or null. The page shows the matching text.
  MenuSaveError? get saveError => _saveError;

  /// For [MenuSaveError.tooManyTries]: seconds to wait, when the server said.
  int? get saveErrorWaitSeconds => _saveErrorWaitSeconds;

  /// True while item [id] is being saved; its row should be disabled.
  bool isSaving(String id) => _saving.contains(id);

  /// Fetches the menu. Safe to call again to retry. A call made while a load
  /// is running does nothing. Keeps no error text, only [loadFailed].
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _loadFailed = false;
    _notify();
    try {
      _items = List.unmodifiable(await _api.fetchMenu());
      _hasLoaded = true;
    } on Object {
      // Boundary between the network and the UI: whatever went wrong, the
      // page shows an error with a Retry button.
      _loadFailed = true;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Hides the current save error (e.g. when staff start another action).
  void clearSaveError() {
    if (_saveError == null) return;
    _saveError = null;
    _saveErrorWaitSeconds = null;
    _notify();
  }

  /// Saves a new [price] (VND, whole number 0 to [maxMenuPrice]) for [id].
  Future<MenuSaveResult> setPrice(String id, int price) {
    if (price < 0 || price > maxMenuPrice) {
      _saveError = MenuSaveError.invalid;
      _notify();
      return Future.value(MenuSaveResult.failed);
    }
    return _save(id, price: price.toDouble());
  }

  /// Saves the sold-out switch for [id]: [available] false means sold out.
  Future<MenuSaveResult> setAvailable(String id, bool available) =>
      _save(id, available: available);

  /// Shared save: disables the row, sends the PATCH, and replaces the item
  /// from the server's reply. On failure the item keeps its old value.
  Future<MenuSaveResult> _save(
    String id, {
    double? price,
    bool? available,
  }) async {
    if (_disposed || _saving.contains(id)) return MenuSaveResult.ignored;
    final credentials = _holder.value;
    if (credentials == null) return MenuSaveResult.needsCredentials;
    _saving.add(id);
    _saveError = null;
    _saveErrorWaitSeconds = null;
    _notify();
    try {
      final updated = await _admin.updateItem(
        id,
        credentials: credentials,
        price: price,
        available: available,
      );
      _items = List.unmodifiable([
        for (final item in _items) item.id == id ? updated : item,
      ]);
      return MenuSaveResult.saved;
    } on MenuAdminException catch (e) {
      switch (e.failure) {
        case MenuAdminFailure.wrongCredentials:
          // Forget both so wrong ones aren't sent again; the page asks anew.
          _holder.clear();
          _saveError = MenuSaveError.wrongCredentials;
          return MenuSaveResult.needsCredentials;
        case MenuAdminFailure.editingDisabled:
          _saveError = MenuSaveError.editingDisabled;
        case MenuAdminFailure.tooManyTries:
          _saveError = MenuSaveError.tooManyTries;
          _saveErrorWaitSeconds = e.retryAfterSeconds;
        case MenuAdminFailure.notFound:
          _saveError = MenuSaveError.notFound;
        case MenuAdminFailure.invalid:
          _saveError = MenuSaveError.invalid;
        case MenuAdminFailure.duplicate:
        case MenuAdminFailure.menuFull:
        case MenuAdminFailure.other:
          // Duplicate and menuFull only come from adding, never from here.
          _saveError = MenuSaveError.other;
      }
      return MenuSaveResult.failed;
    } on Object {
      // Anything else (e.g. credentials the client refuses to send): the row
      // must not stay stuck disabled. No exception text is kept.
      _saveError = MenuSaveError.other;
      return MenuSaveResult.failed;
    } finally {
      _saving.remove(id);
      _notify();
    }
  }

  /// Adds a new item. On success the server's item is appended to [items].
  /// On failure the list is unchanged and [saveError] says why. Without
  /// credentials nothing is sent. A call while another add runs is ignored.
  Future<MenuSaveResult> addItem(NewMenuItem draft) async {
    if (_disposed || _adding) return MenuSaveResult.ignored;
    final credentials = _holder.value;
    if (credentials == null) return MenuSaveResult.needsCredentials;
    _adding = true;
    _saveError = null;
    _saveErrorWaitSeconds = null;
    _notify();
    try {
      final created = await _admin.addItem(draft, credentials: credentials);
      // A reply that repeats an id already in the list replaces that row, so
      // the list never holds two rows with one id.
      final known = _items.any((i) => i.id == created.id);
      _items = List.unmodifiable(
        known
            ? [for (final i in _items) i.id == created.id ? created : i]
            : [..._items, created],
      );
      return MenuSaveResult.saved;
    } on MenuAdminException catch (e) {
      switch (e.failure) {
        case MenuAdminFailure.wrongCredentials:
          _holder.clear();
          _saveError = MenuSaveError.wrongCredentials;
          return MenuSaveResult.needsCredentials;
        case MenuAdminFailure.editingDisabled:
          _saveError = MenuSaveError.editingDisabled;
        case MenuAdminFailure.tooManyTries:
          _saveError = MenuSaveError.tooManyTries;
          _saveErrorWaitSeconds = e.retryAfterSeconds;
        case MenuAdminFailure.invalid:
          _saveError = MenuSaveError.invalid;
        case MenuAdminFailure.duplicate:
          _saveError = MenuSaveError.duplicate;
        case MenuAdminFailure.menuFull:
          _saveError = MenuSaveError.menuFull;
        case MenuAdminFailure.notFound:
        case MenuAdminFailure.other:
          _saveError = MenuSaveError.other;
      }
      return MenuSaveResult.failed;
    } on Object {
      // e.g. credentials the client refuses to send; keep no exception text.
      _saveError = MenuSaveError.other;
      return MenuSaveResult.failed;
    } finally {
      _adding = false;
      _notify();
    }
  }

  /// Notifies unless the state is already disposed (a save can finish after
  /// the page was closed).
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Marks the state disposed so late replies don't notify, then releases
  /// listeners. Does not close the clients; whoever made them closes them.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
