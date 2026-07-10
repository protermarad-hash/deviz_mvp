import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/cloud/firestore_auth_warning_banner.dart';

void main() {
  group('shouldShowReloginAction', () {
    test('afișează CTA la fallback local autenticat fără permission-denied',
        () {
      expect(
        shouldShowReloginAction(
          isAuthenticated: true,
          authSourceLabel: 'local',
          permissionDenied: false,
        ),
        isTrue,
      );
    });

    test('afișează CTA la permission-denied', () {
      expect(
        shouldShowReloginAction(
          isAuthenticated: false,
          authSourceLabel: 'cloud',
          permissionDenied: true,
        ),
        isTrue,
      );
    });

    test('nu afișează CTA când utilizatorul nu este autentificat', () {
      expect(
        shouldShowReloginAction(
          isAuthenticated: false,
          authSourceLabel: 'local',
          permissionDenied: false,
        ),
        isFalse,
      );
    });

    test('nu afișează CTA când sesiunea este deja în cloud', () {
      expect(
        shouldShowReloginAction(
          isAuthenticated: true,
          authSourceLabel: 'cloud',
          permissionDenied: false,
        ),
        isFalse,
      );
    });
  });
}
