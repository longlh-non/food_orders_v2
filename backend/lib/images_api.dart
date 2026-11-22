import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'menu_image.dart';

/// Pictures bigger than this are refused (404): the menu needs small photos,
/// and a huge file would be slow on a phone.
const maxImageBytes = 1024 * 1024;

const _contentTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
};

/// `GET /images/{file}`: hands out menu pictures from one folder.
///
/// The owner copies photos into the folder and names them in
/// `menu_items.image`; there is no upload. Only names that pass
/// [isValidImageName] (checked after URL-decoding) are ever turned into a
/// path, so a request can't reach anything outside the folder. Symbolic
/// links, folders and files over [maxImageBytes] answer 404, as does any
/// read error: never a stack trace or a path.
class ImagesApi {
  ImagesApi(this._dir);

  final Directory _dir;

  late final Handler handler = _buildHandler();

  Handler _buildHandler() {
    final router = Router();
    router.get('/images/<file>', _serve);
    return router.call;
  }

  Response _serve(Request req, String file) {
    // shelf_router hands over the still-encoded path segment. A broken
    // escape (`%zz`) throws ArgumentError. Escapes that aren't valid UTF-8
    // (`%FF`, an overlong `%C0%AF`) throw FormatException; shelf already
    // refuses those URLs, so that catch is only a safety net.
    final String name;
    try {
      name = Uri.decodeComponent(file);
    } on ArgumentError {
      return _badName();
    } on FormatException {
      return _badName();
    }
    if (!isValidImageName(name)) return _badName();

    // Only the validated name is joined to the folder; nothing else from
    // the request ever becomes part of a path.
    final path = '${_dir.path}${Platform.pathSeparator}$name';
    // Accepted risk: someone with write access to the folder could swap the
    // file for a link between this check and the read. That's the owner,
    // who can already put any file there. Reads are small (1 MiB at most),
    // so reading synchronously is fine at this scale.
    try {
      if (FileSystemEntity.typeSync(path, followLinks: false) !=
          FileSystemEntityType.file) {
        return _notFound();
      }
      final picture = File(path);
      if (picture.lengthSync() > maxImageBytes) return _notFound();
      final bytes = picture.readAsBytesSync();
      if (bytes.length > maxImageBytes) return _notFound();
      return Response.ok(
        bytes,
        headers: {
          'content-type': _contentTypes[name.split('.').last]!,
          'x-content-type-options': 'nosniff',
          'cache-control': 'public, max-age=300',
        },
      );
    } on FileSystemException {
      return _notFound();
    }
  }
}

// Fixed messages that never echo the request.
Response _badName() => Response.badRequest(body: 'Invalid image name');
Response _notFound() => Response.notFound('Image not found');

/// The pictures folder: `IMAGES_DIR` when set and not empty, otherwise
/// `backend/data/images` next to the database (found from [script], the
/// path of `bin/server.dart`). A compiled binary must set `IMAGES_DIR`.
String imagesDirPath(String? fromEnv, Uri script) =>
    (fromEnv != null && fromEnv.isNotEmpty)
    ? fromEnv
    : File.fromUri(script).parent.parent.uri
          .resolve('data/images')
          .toFilePath();
