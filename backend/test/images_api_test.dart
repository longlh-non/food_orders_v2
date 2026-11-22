import 'dart:io';

import 'package:food_orders_backend/images_api.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Bytes that are recognisably ours, so a test can tell which file came back.
List<int> bytesOf(String label) => label.codeUnits;

void main() {
  late Directory root;
  late Directory images;
  late Handler handler;

  setUp(() {
    root = Directory.systemTemp.createTempSync('images_api_test');
    images = Directory('${root.path}/images')..createSync();
    // A secret right next to the folder, and one further up: no request may
    // ever return either.
    File('${root.path}/secret.png').writeAsBytesSync(bytesOf('SECRET'));
    File('${root.path}/orders.db').writeAsBytesSync(bytesOf('DATABASE'));
    handler = ImagesApi(images).handler;
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<Response> get(String rawPath, {String method = 'GET'}) async =>
      await handler(Request(method, Uri.parse('http://localhost$rawPath')));

  group('serves valid pictures', () {
    for (final (name, type) in [
      ('xoi-thit.jpg', 'image/jpeg'),
      ('tra-da.jpeg', 'image/jpeg'),
      ('banh-mi-2.png', 'image/png'),
      ('9.webp', 'image/webp'),
    ]) {
      test('$name -> 200 with $type', () async {
        File('${images.path}/$name').writeAsBytesSync(bytesOf(name));

        final response = await get('/images/$name');

        expect(response.statusCode, 200);
        expect(await response.read().expand((c) => c).toList(), bytesOf(name));
        expect(response.headers['content-type'], type);
        expect(response.headers['x-content-type-options'], 'nosniff');
        expect(response.headers['cache-control'], 'public, max-age=300');
      });
    }

    test('exactly 1 MiB is still served', () async {
      File('${images.path}/big.jpg')
          .writeAsBytesSync(List.filled(maxImageBytes, 7));
      expect((await get('/images/big.jpg')).statusCode, 200);
    });
  });

  group('refuses', () {
    test('a missing file -> 404', () async {
      final response = await get('/images/nope.png');
      expect(response.statusCode, 404);
      expect(await response.readAsString(), 'Image not found');
    });

    test('a file over 1 MiB -> 404', () async {
      File('${images.path}/huge.jpg')
          .writeAsBytesSync(List.filled(maxImageBytes + 1, 7));
      expect((await get('/images/huge.jpg')).statusCode, 404);
    });

    test('a folder named like a picture -> 404', () async {
      Directory('${images.path}/x.png').createSync();
      expect((await get('/images/x.png')).statusCode, 404);
    });

    test('a symbolic link pointing outside the folder -> 404', () async {
      final link = Link('${images.path}/link.png');
      try {
        link.createSync('${root.path}/secret.png');
      } on FileSystemException catch (e) {
        markTestSkipped('cannot create symbolic links here: ${e.message}');
        return;
      }
      final response = await get('/images/link.png');
      expect(response.statusCode, 404);
      expect(await response.readAsString(), isNot(contains('SECRET')));
    });

    for (final method in ['POST', 'PUT', 'DELETE', 'PATCH']) {
      test('$method is not served', () async {
        File('${images.path}/a.png').writeAsBytesSync(bytesOf('a'));
        final response = await get('/images/a.png', method: method);
        expect(response.statusCode, anyOf(404, 405));
        expect(File('${images.path}/a.png').existsSync(), isTrue);
      });
    }
  });

  group('never reads outside the folder', () {
    // Single path segments that decode to a bad name: refused with 400 and a
    // fixed message that doesn't echo the input.
    for (final raw in [
      '..%2Fsecret.png',
      '%2e%2e%2fsecret.png',
      '%2E%2E%2Forders.db',
      '%252e%252e',
      '%2Fetc%2Fpasswd',
      'C%3A%5Cx.png',
      'a%2Fb.png',
      '%00',
      'burger.png%00.txt',
      'burger.png%00',
      'Burger.PNG',
      'burger.gif',
      'burger.svg',
      'burger',
      '.png',
      '.hidden.png',
      'a..b.png',
      '-x.png',
      'a%20b.png',
      '%E1%BA%A3nh.png',
      '%zz.png',
      '${'a' * 100}.png',
    ]) {
      test('/images/$raw -> 400', () async {
        final response = await get('/images/$raw');
        expect(response.statusCode, 400);
        final body = await response.readAsString();
        expect(body, 'Invalid image name');
      });
    }

    // Escapes that aren't valid UTF-8 (`%FF`, an overlong `/` as `%C0%AF`)
    // never reach any handler: shelf refuses to build the Request, and the
    // shelf server answers such requests itself. ImagesApi still maps a
    // FormatException from decoding to 400, as a safety net.
    for (final raw in ['%FF.png', '%C0%AF.png', '%E1.png']) {
      test('/images/$raw is refused by shelf before any handler', () {
        expect(
          () => Request('GET', Uri.parse('http://localhost/images/$raw')),
          throwsArgumentError,
        );
      });
    }

    // Paths with real `..` or `/` segments: the URL is normalised or the
    // one-segment route doesn't match, so these never reach the handler and
    // answer 404 (not 400, see the card's notes). No secret ever comes back.
    for (final raw in [
      '/images/../secret.png',
      '/images/%2e%2e/secret.png',
      '/images/a/b.png',
      '/images//etc/passwd',
      '/images/',
      '/images',
    ]) {
      test('$raw is not served', () async {
        final response = await get(raw);
        expect(response.statusCode, 404);
        final body = await response.readAsString();
        expect(body, isNot(contains('SECRET')));
        expect(body, isNot(contains('DATABASE')));
      });
    }
  });

  group('imagesDirPath', () {
    final script = Uri.file('/srv/food_orders/backend/bin/server.dart');

    test('defaults to backend/data/images next to the script', () {
      expect(
        imagesDirPath(null, script),
        '/srv/food_orders/backend/data/images',
      );
    });

    test('an empty IMAGES_DIR counts as unset', () {
      expect(imagesDirPath('', script), '/srv/food_orders/backend/data/images');
    });

    test('IMAGES_DIR overrides', () {
      expect(imagesDirPath('/var/pictures', script), '/var/pictures');
    });
  });
}
