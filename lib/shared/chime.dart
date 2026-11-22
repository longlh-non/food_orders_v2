/// Audio chime for new-order notifications.
///
/// Conditional export so `flutter test` (which runs on the VM) uses the stub
/// and doesn't try to compile `package:web`, while web builds use the real
/// Web Audio API implementation.
///
/// Call [playChime] from UI code; it is a no-op on non-web platforms.
library;

export 'chime_stub.dart' if (dart.library.js_interop) 'chime_web.dart';
