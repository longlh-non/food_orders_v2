import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/restaurant/state/staff_credentials.dart';

void main() {
  // Obviously fake test values.
  const creds = StaffCredentials(
    id: 'test-staff',
    password: 'test-password-1234',
  );

  tearDown(StaffCredentialsHolder.instance.clear);

  test('the holder starts empty, remembers, and forgets', () {
    expect(StaffCredentialsHolder.instance.value, isNull);
    StaffCredentialsHolder.instance.value = creds;
    expect(StaffCredentialsHolder.instance.value?.id, 'test-staff');
    expect(
      StaffCredentialsHolder.instance.value?.password,
      'test-password-1234',
    );
    StaffCredentialsHolder.instance.clear();
    expect(StaffCredentialsHolder.instance.value, isNull);
  });

  test('headers are exactly the two staff headers', () {
    expect(creds.headers, {
      'X-Staff-Id': 'test-staff',
      'X-Staff-Password': 'test-password-1234',
    });
  });

  test('isSendable: non-empty printable ASCII only', () {
    expect(creds.isSendable, isTrue);
    expect(const StaffCredentials(id: '', password: 'x').isSendable, isFalse);
    expect(const StaffCredentials(id: 'a', password: '').isSendable, isFalse);
    expect(
      const StaffCredentials(id: 'nhân', password: 'x').isSendable,
      isFalse,
    );
    expect(
      const StaffCredentials(id: 'a', password: 'tab\there').isSendable,
      isFalse,
    );
  });

  test('retryAfterSeconds keeps 1..3600 only', () {
    expect(retryAfterSeconds('60'), 60);
    expect(retryAfterSeconds(' 1 '), 1);
    for (final bad in [null, '', '0', '-5', '3601', 'soon']) {
      expect(retryAfterSeconds(bad), isNull, reason: '$bad');
    }
  });
}
