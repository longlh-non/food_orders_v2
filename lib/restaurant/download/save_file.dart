/// Saves bytes as a file in the browser's downloads.
///
/// Conditional export, like `lib/shared/chime.dart`: tests on the VM get a
/// stub, web builds use the real browser download.
library;

export 'save_file_stub.dart' if (dart.library.js_interop) 'save_file_web.dart';
