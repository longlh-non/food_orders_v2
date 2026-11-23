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

/// What happened to a [MenuAdminState.setPrice] / [MenuAdminState.setAvailable]
/// call.
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
  String? _saveError;
  bool _disposed = false;

  /// The menu as last loaded or saved (empty until the first load).
  List<MenuItem> get items => _items;
  bool get isLoading => _isLoading;

  /// True once a load has succeeded; tells "not loaded yet" from "empty".
  bool get hasLoaded => _hasLoaded;

  /// True when the last [load] failed (and nothing was loaded before).
  bool get loadFailed => _loadFailed;

  /// A short Vietnamese message for the last failed save, or null.
  String? get saveError => _saveError;

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
    _notify();
  }

  /// Saves a new [price] (VND, whole number 0 to [maxMenuPrice]) for [id].
  Future<MenuSaveResult> setPrice(String id, int price) {
    if (price < 0 || price > maxMenuPrice) {
      _saveError = _messageInvalid;
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
          _saveError = 'Sai mã nhân viên hoặc mật khẩu';
          return MenuSaveResult.needsCredentials;
        case MenuAdminFailure.editingDisabled:
          _saveError = 'Chức năng sửa thực đơn đang tắt trên máy chủ';
        case MenuAdminFailure.tooManyTries:
          final wait = e.retryAfterSeconds;
          _saveError = wait == null
              ? 'Thử sai quá nhiều lần. Vui lòng thử lại sau.'
              : 'Thử sai quá nhiều lần. Thử lại sau $wait giây.';
        case MenuAdminFailure.notFound:
          _saveError = 'Không tìm thấy món này. Hãy tải lại trang.';
        case MenuAdminFailure.invalid:
          _saveError = _messageInvalid;
        case MenuAdminFailure.other:
          _saveError = _messageOther;
      }
      return MenuSaveResult.failed;
    } on Object {
      // Anything else (e.g. credentials the client refuses to send): the row
      // must not stay stuck disabled. No exception text is kept.
      _saveError = _messageOther;
      return MenuSaveResult.failed;
    } finally {
      _saving.remove(id);
      _notify();
    }
  }

  static const _messageInvalid =
      'Giá không hợp lệ. Nhập số nguyên từ 0 đến 1.000.000';
  static const _messageOther = 'Không lưu được. Thử lại.';

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
