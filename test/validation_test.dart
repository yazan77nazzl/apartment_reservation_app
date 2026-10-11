import 'package:flutter_test/flutter_test.dart';
import 'package:apartment_reservation_app/core/utils/validation.dart';
import 'package:apartment_reservation_app/core/routing/app_router.dart';

void main() {
  test('authentication validates email password and phone', () {
    expect(Validation.email('wrong'), isNotNull);
    expect(Validation.email('student@example.test'), isNull);
    expect(Validation.password('short'), isNotNull);
    expect(Validation.password('SafePassword!'), isNull);
    expect(Validation.phone('abc'), isNotNull);
    expect(Validation.phone('0590000000'), isNull);
  });
  test('session and role redirects protect owner screens and student checkout',
      () {
    expect(
        roleRedirect(
            loading: true, authenticated: false, role: null, path: '/'),
        '/loading');
    expect(
        roleRedirect(
            loading: false,
            authenticated: false,
            role: null,
            path: '/owner/calendar'),
        '/login');
    expect(
        roleRedirect(
            loading: false, authenticated: true, role: null, path: '/'),
        '/complete');
    expect(
        roleRedirect(
            loading: false,
            authenticated: true,
            role: 'student',
            path: '/owner/calendar'),
        '/');
    expect(
        roleRedirect(
            loading: false,
            authenticated: true,
            role: 'owner',
            path: '/reservations/r/payment'),
        '/');
    expect(
        roleRedirect(
            loading: false,
            authenticated: true,
            role: 'owner',
            path: '/owner/calendar'),
        isNull);
  });
}
