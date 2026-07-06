import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/core/cloud/firestore_auth_warning_service.dart';

void main() {
  late FirestoreAuthWarningService svc;

  setUp(() {
    svc = FirestoreAuthWarningService.instance;
    svc.clear();
  });

  group('reportCloudError — detecție permission-denied', () {
    test('FirebaseException permission-denied ridică avertismentul', () {
      final err = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
      expect(svc.reportCloudError(err), isTrue);
      expect(svc.activeNotifier.value, isTrue);
      expect(svc.permissionDeniedNotifier.value, isTrue);
    });

    test('mesaj text "Missing or insufficient permissions" este detectat', () {
      expect(
        svc.reportCloudError(
            Exception('[cloud_firestore/permission-denied] '
                'Missing or insufficient permissions.')),
        isTrue,
      );
      expect(svc.permissionDeniedNotifier.value, isTrue);
    });

    test('unauthenticated este tratat ca permission-denied', () {
      final err = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
      );
      expect(svc.reportCloudError(err), isTrue);
    });

    test('eroare de rețea NU ridică permission-denied', () {
      final err = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'The service is currently unavailable.',
      );
      expect(svc.reportCloudError(err), isFalse);
      expect(svc.activeNotifier.value, isFalse);
      expect(svc.permissionDeniedNotifier.value, isFalse);
    });

    test('eroare generică (timeout) NU ridică avertismentul', () {
      expect(svc.reportCloudError(Exception('TimeoutException after 8s')),
          isFalse);
      expect(svc.activeNotifier.value, isFalse);
    });
  });

  group('fallback auth local și clear', () {
    test('reportLocalAuthFallback ridică active dar NU permission-denied', () {
      svc.reportLocalAuthFallback();
      expect(svc.activeNotifier.value, isTrue);
      expect(svc.permissionDeniedNotifier.value, isFalse);
    });

    test('clear resetează ambii notificatori', () {
      svc.reportCloudError(FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      ));
      expect(svc.activeNotifier.value, isTrue);
      svc.clear();
      expect(svc.activeNotifier.value, isFalse);
      expect(svc.permissionDeniedNotifier.value, isFalse);
      expect(svc.lastPermissionError, isNull);
    });
  });
}
