import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/restaurant/api/menu_admin_client.dart';
import 'package:food_orders/restaurant/state/menu_admin_state.dart';
import 'package:food_orders/restaurant/state/staff_credentials.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/models/menu_item.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Obviously fake test values.
const staffId = 'test-staff';
const password = 'test-password-1234';
const creds = StaffCredentials(id: staffId, password: password);

Map<String, Object?> item(
  String id,
  String name, {
  num price = 4000,
  bool available = true,
}) => {
  'id': id,
  'name': name,
  'description': '',
  'price': price,
  'category': 'drink',
  'allowToppings': false,
  'image': null,
  'available': available,
};

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late List<http.Request> patches;
  late Future<http.Response> Function(http.Request) onGet;
  late Future<http.Response> Function(http.Request) onPatch;

  MenuAdminState build() {
    final mock = MockClient((r) {
      if (r.method == 'GET') return onGet(r);
      patches.add(r);
      return onPatch(r);
    });
    return MenuAdminState(
      api: OrderApiClient(client: mock),
      admin: MenuAdminClient(client: mock),
    );
  }

  setUp(() {
    patches = [];
    onGet = (_) async => json([item('a', 'Trà đá'), item('b', 'Cà phê')]);
    onPatch = (r) async => json(item('a', 'Trà đá', price: 5000));
    StaffCredentialsHolder.instance.value = creds;
  });
  tearDown(StaffCredentialsHolder.instance.clear);

  test('parseMenuPrice accepts whole numbers 0..1.000.000 only', () {
    expect(parseMenuPrice('25000'), 25000);
    expect(parseMenuPrice(' 0 '), 0);
    expect(parseMenuPrice('1000000'), 1000000);
    for (final bad in [
      '',
      ' ',
      'abc',
      '-1',
      '1000001',
      '12.5',
      '1,5',
      '25.000',
      '1e3',
      '99999999',
    ]) {
      expect(parseMenuPrice(bad), isNull, reason: bad);
    }
  });

  test('loading -> loaded', () async {
    final state = build();
    addTearDown(state.dispose);
    final seen = <bool>[];
    state.addListener(() => seen.add(state.isLoading));
    expect(state.hasLoaded, isFalse);
    await state.load();
    expect(seen, [true, false]);
    expect(state.hasLoaded, isTrue);
    expect(state.loadFailed, isFalse);
    expect(state.items.map((i) => i.name), ['Trà đá', 'Cà phê']);
  });

  test('loading -> error -> retry', () async {
    onGet = (_) async => http.Response('x', 500);
    final state = build();
    addTearDown(state.dispose);
    await state.load();
    expect(state.loadFailed, isTrue);
    expect(state.hasLoaded, isFalse);
    onGet = (_) async => json([item('a', 'Trà đá')]);
    await state.load();
    expect(state.loadFailed, isFalse);
    expect(state.hasLoaded, isTrue);
    expect(state.items, hasLength(1));
  });

  test('a second load while loading is ignored', () async {
    final gate = Completer<http.Response>();
    var gets = 0;
    onGet = (_) {
      gets++;
      return gate.future;
    };
    final state = build();
    addTearDown(state.dispose);
    final first = state.load();
    await state.load();
    gate.complete(json([item('a', 'Trà đá')]));
    await first;
    expect(gets, 1);
  });

  test(
    'setPrice replaces the item from the reply and sends credentials',
    () async {
      final state = build();
      addTearDown(state.dispose);
      await state.load();
      final result = await state.setPrice('a', 5000);
      expect(result, MenuSaveResult.saved);
      expect(state.items.first.price, 5000);
      expect(state.items.last.name, 'Cà phê');
      expect(state.saveError, isNull);
      expect(patches.single.url.path, '/api/menu/a');
      expect(jsonDecode(patches.single.body), {'price': 5000});
      expect(patches.single.headers['X-Staff-Id'], staffId);
    },
  );

  test('setAvailable sends only the flag', () async {
    onPatch = (_) async => json(item('a', 'Trà đá', available: false));
    final state = build();
    addTearDown(state.dispose);
    await state.load();
    expect(await state.setAvailable('a', false), MenuSaveResult.saved);
    expect(state.items.first.available, isFalse);
    expect(jsonDecode(patches.single.body), {'available': false});
  });

  test('a price outside 0..1.000.000 is not sent', () async {
    final state = build();
    addTearDown(state.dispose);
    await state.load();
    expect(await state.setPrice('a', 1000001), MenuSaveResult.failed);
    expect(await state.setPrice('a', -1), MenuSaveResult.failed);
    expect(patches, isEmpty);
    expect(state.saveError, MenuSaveError.invalid);
  });

  test('failure keeps the old value and shows an error', () async {
    onPatch = (_) async => http.Response('x', 500);
    final state = build();
    addTearDown(state.dispose);
    await state.load();
    expect(await state.setPrice('a', 5000), MenuSaveResult.failed);
    expect(state.items.first.price, 4000);
    expect(state.saveError, MenuSaveError.other);
    expect(state.isSaving('a'), isFalse);
  });

  test('401 clears the credentials and asks again', () async {
    onPatch = (_) async => http.Response('x', 401);
    final state = build();
    addTearDown(state.dispose);
    await state.load();
    expect(await state.setPrice('a', 5000), MenuSaveResult.needsCredentials);
    expect(StaffCredentialsHolder.instance.value, isNull);
    expect(state.saveError, MenuSaveError.wrongCredentials);
    expect(state.items.first.price, 4000);
    // Without credentials nothing is sent.
    patches.clear();
    expect(await state.setPrice('a', 5000), MenuSaveResult.needsCredentials);
    expect(patches, isEmpty);
  });

  test('403 says editing is disabled', () async {
    onPatch = (_) async => http.Response('x', 403);
    final state = build();
    addTearDown(state.dispose);
    await state.load();
    expect(await state.setAvailable('a', false), MenuSaveResult.failed);
    expect(state.saveError, MenuSaveError.editingDisabled);
    expect(StaffCredentialsHolder.instance.value, isNotNull);
  });

  test('429 says too many tries, with the wait when given', () async {
    onPatch = (_) async =>
        http.Response('x', 429, headers: {'retry-after': '42'});
    final state = build();
    addTearDown(state.dispose);
    await state.load();
    await state.setAvailable('a', false);
    expect(state.saveError, MenuSaveError.tooManyTries);
    expect(state.saveErrorWaitSeconds, 42);
    onPatch = (_) async => http.Response('x', 429);
    await state.setAvailable('a', false);
    expect(state.saveError, MenuSaveError.tooManyTries);
    expect(state.saveErrorWaitSeconds, isNull);
  });

  test('no message contains the staff ID or password', () async {
    final state = build();
    addTearDown(state.dispose);
    await state.load();
    for (final status in [400, 401, 403, 404, 429, 500]) {
      onPatch = (_) async => http.Response('$staffId $password', status);
      StaffCredentialsHolder.instance.value = creds;
      await state.setAvailable('a', false);
      final shown = '${state.saveError} ${state.saveErrorWaitSeconds}';
      expect(shown, isNot(contains(staffId)));
      expect(shown, isNot(contains(password)));
    }
  });

  test(
    'a second save on a saving row is ignored; the row is disabled',
    () async {
      final gate = Completer<http.Response>();
      onPatch = (_) => gate.future;
      final state = build();
      addTearDown(state.dispose);
      await state.load();
      final first = state.setPrice('a', 5000);
      expect(state.isSaving('a'), isTrue);
      expect(state.isSaving('b'), isFalse);
      expect(await state.setPrice('a', 6000), MenuSaveResult.ignored);
      gate.complete(json(item('a', 'Trà đá', price: 5000)));
      expect(await first, MenuSaveResult.saved);
      expect(patches, hasLength(1));
      expect(state.isSaving('a'), isFalse);
    },
  );

  test('a reply after dispose does not notify or throw', () async {
    final gate = Completer<http.Response>();
    onPatch = (_) => gate.future;
    final state = build();
    await state.load();
    final pending = state.setPrice('a', 5000);
    state.dispose();
    gate.complete(json(item('a', 'Trà đá', price: 5000)));
    await pending;
  });

  group('addItem', () {
    const draft = NewMenuItem(
      name: 'Cam vắt',
      price: 20000,
      category: MenuCategory.drink,
    );
    late List<http.Request> posts;
    late Future<http.Response> Function(http.Request) onPost;

    MenuAdminState buildAdd() {
      final mock = MockClient((r) {
        if (r.method == 'GET') return onGet(r);
        posts.add(r);
        return onPost(r);
      });
      return MenuAdminState(
        api: OrderApiClient(client: mock),
        admin: MenuAdminClient(client: mock),
      );
    }

    setUp(() {
      posts = [];
      onPost = (_) async => json(item('cam-vat', 'Cam vắt'), 201);
    });

    test('success appends the server item and keeps order', () async {
      final state = buildAdd();
      addTearDown(state.dispose);
      await state.load();
      expect(await state.addItem(draft), MenuSaveResult.saved);
      expect(state.items.map((i) => i.id), ['a', 'b', 'cam-vat']);
      expect(state.saveError, isNull);
      expect(state.isAdding, isFalse);
      expect(posts.single.url.path, '/api/menu');
      expect(posts.single.headers['X-Staff-Id'], staffId);
    });

    test('a reply that repeats a known id replaces that row', () async {
      onPost = (_) async => json(item('a', 'Cam vắt'), 201);
      final state = buildAdd();
      addTearDown(state.dispose);
      await state.load();
      expect(await state.addItem(draft), MenuSaveResult.saved);
      expect(state.items.map((i) => i.id), ['a', 'b']);
      expect(state.items.first.name, 'Cam vắt');
    });

    for (final (status, error) in [
      (400, MenuSaveError.invalid),
      (403, MenuSaveError.editingDisabled),
      (409, MenuSaveError.duplicate),
      (413, MenuSaveError.invalid),
      (429, MenuSaveError.tooManyTries),
      (500, MenuSaveError.other),
      (503, MenuSaveError.menuFull),
    ]) {
      test('$status keeps the list and sets $error', () async {
        onPost = (_) async => http.Response('$staffId $password', status);
        final state = buildAdd();
        addTearDown(state.dispose);
        await state.load();
        expect(await state.addItem(draft), MenuSaveResult.failed);
        expect(state.items, hasLength(2));
        expect(state.saveError, error);
        expect(state.isAdding, isFalse);
        expect(StaffCredentialsHolder.instance.value, isNotNull);
      });
    }

    test('429 keeps the Retry-After wait', () async {
      onPost = (_) async =>
          http.Response('x', 429, headers: {'retry-after': '42'});
      final state = buildAdd();
      addTearDown(state.dispose);
      await state.addItem(draft);
      expect(state.saveErrorWaitSeconds, 42);
    });

    test('401 clears the holder and needs credentials', () async {
      onPost = (_) async => http.Response('x', 401);
      final state = buildAdd();
      addTearDown(state.dispose);
      await state.load();
      expect(await state.addItem(draft), MenuSaveResult.needsCredentials);
      expect(StaffCredentialsHolder.instance.value, isNull);
      expect(state.saveError, MenuSaveError.wrongCredentials);
      expect(state.items, hasLength(2));
    });

    test('no credentials: nothing is sent', () async {
      StaffCredentialsHolder.instance.clear();
      final state = buildAdd();
      addTearDown(state.dispose);
      expect(await state.addItem(draft), MenuSaveResult.needsCredentials);
      expect(posts, isEmpty);
    });

    test('a second add while adding is ignored; isAdding is true', () async {
      final gate = Completer<http.Response>();
      onPost = (_) => gate.future;
      final state = buildAdd();
      addTearDown(state.dispose);
      await state.load();
      final first = state.addItem(draft);
      expect(state.isAdding, isTrue);
      expect(await state.addItem(draft), MenuSaveResult.ignored);
      gate.complete(json(item('cam-vat', 'Cam vắt'), 201));
      expect(await first, MenuSaveResult.saved);
      expect(posts, hasLength(1));
      expect(state.isAdding, isFalse);
    });

    test('a reply after dispose does not notify or throw', () async {
      final gate = Completer<http.Response>();
      onPost = (_) => gate.future;
      final state = buildAdd();
      await state.load();
      final pending = state.addItem(draft);
      state.dispose();
      gate.complete(json(item('cam-vat', 'Cam vắt'), 201));
      await pending;
    });
  });

  group('validateNewItem', () {
    NewItemProblem? check({
      String name = 'Xôi',
      String description = '',
      String price = '1000',
      MenuCategory category = MenuCategory.food,
      bool toppings = false,
      String? image,
    }) => validateNewItem(
      name: name,
      description: description,
      priceText: price,
      category: category,
      allowToppings: toppings,
      image: image,
    );

    test('a good item has no problem', () {
      expect(check(), isNull);
      expect(check(toppings: true, image: 'xoi-1.webp'), isNull);
    });

    test('name limits: trimmed, 1 to 100 units', () {
      expect(check(name: ''), NewItemProblem.nameEmpty);
      expect(check(name: '  \t '), NewItemProblem.nameEmpty);
      expect(check(name: ' ${'a' * 100} '), isNull);
      expect(check(name: 'a' * 101), NewItemProblem.nameTooLong);
      expect(check(name: 'a\nb'), NewItemProblem.nameBadCharacters);
      expect(check(name: 'a\u0085b'), NewItemProblem.nameBadCharacters);
    });

    test('an emoji counts as 2 units', () {
      expect(check(name: '😀' * 50), isNull);
      expect(check(name: '😀' * 50 + 'a'), NewItemProblem.nameTooLong);
    });

    test('description limits: 500 units, newline allowed', () {
      expect(check(description: 'a' * 500), isNull);
      expect(check(description: 'a' * 501), NewItemProblem.descriptionTooLong);
      expect(check(description: 'a\nb'), isNull);
      expect(
        check(description: 'a\tb'),
        NewItemProblem.descriptionBadCharacters,
      );
    });

    test('price edges', () {
      expect(check(price: '0'), isNull);
      expect(check(price: '1000000'), isNull);
      expect(check(price: '1000001'), NewItemProblem.priceInvalid);
      expect(check(price: '-1'), NewItemProblem.priceInvalid);
      expect(check(price: '1.5'), NewItemProblem.priceInvalid);
      expect(check(price: ''), NewItemProblem.priceInvalid);
    });

    test('toppings only for food', () {
      expect(check(toppings: true), isNull);
      for (final c in [
        MenuCategory.snack,
        MenuCategory.drink,
        MenuCategory.nibble,
      ]) {
        expect(
          check(category: c, toppings: true),
          NewItemProblem.toppingsNeedFood,
        );
        expect(check(category: c), isNull);
      }
    });

    test('image rule', () {
      expect(check(image: 'a.jpg'), isNull);
      for (final bad in [
        'A.jpg',
        'a.gif',
        'a/b.png',
        '../a.png',
        'a b.png',
        '',
      ]) {
        expect(check(image: bad), NewItemProblem.imageInvalid, reason: bad);
      }
    });

    test('reports the first problem', () {
      expect(check(name: '', price: 'x'), NewItemProblem.nameEmpty);
    });
  });
}
