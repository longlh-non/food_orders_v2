import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Hands [bytes] to the browser as a download named [fileName]: a `Blob`,
/// a temporary hidden link that is clicked once, then cleaned up.
void saveFile(List<int> bytes, String fileName, String mimeType) {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.append(link);
  link.click();
  link.remove();
  // Released a moment later: some Safari versions cancel the download when
  // the address disappears right after the click.
  Timer(const Duration(seconds: 10), () => web.URL.revokeObjectURL(url));
}
