import 'dart:convert';

import 'package:devizpro_ultra/core/auth/field_auth_models.dart';
import 'package:devizpro_ultra/core/auth/field_auth_service.dart';
import 'package:devizpro_ultra/core/auth/field_local_auth_repository.dart';
import 'package:devizpro_ultra/core/auth/local_password_hasher.dart';
import 'package:devizpro_ultra/features/auth/field_auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parole FICTIVE pentru teste; parola implicită e referită doar prin constantă.
const _seed = FieldLocalAuthRepository.devSeedPassword;
const _admin = FieldLocalAuthRepository.defaultAdminEmail;
const _newPw = 'Parola-Noua-QA-2026';

String _legacy(String p) => base64Encode(utf8.encode(p));

/// Starea unui dispozitiv cu o versiune veche: contul de dezvoltare există
/// cu parola implicită în format vechi, plus un utilizator obișnuit.
void _oldDeviceState() {
  final users = [
    FieldAuthUser(
        id: 'admin-legacy',
        name: 'Admin local',
        email: _admin,
        role: FieldUserRole.admin,
        active: true,
        passwordHash: _legacy(_seed)),
    FieldAuthUser(
        id: 'u2',
        name: 'Birou',
        email: 'birou@test.qa',
        role: FieldUserRole.employee,
        active: true,
        passwordHash: _legacy('Birou-QA-123')),
  ];
  SharedPreferences.setMockInitialValues({
    'field_auth_users_v1': jsonEncode(users.map((u) => u.toMap()).toList()),
  });
}

FieldLocalAuthRepository _release() => FieldLocalAuthRepository(
    seedDefaultAdmin: false, hasher: LocalPasswordHasher(iterations: 2000));

void main() {
  group('repository', () {
    test('release + parola implicită: login PERMIS, schimbare obligatorie',
        () async {
      _oldDeviceState();
      final repo = _release();
      final user = await repo.login(email: _admin, password: _seed);
      expect(user, isNotNull, reason: 'accesul legitim nu e blocat');
      expect(await repo.mustChangePassword('admin-legacy'), isTrue);
      expect(await repo.loadSession(), isNotNull);
    });

    test('marcajul persistă la restart (instanță nouă)', () async {
      _oldDeviceState();
      await _release().login(email: _admin, password: _seed);
      expect(await _release().mustChangePassword('admin-legacy'), isTrue);
    });

    test('alți utilizatori nu sunt afectați', () async {
      _oldDeviceState();
      final repo = _release();
      expect(await repo.login(email: 'birou@test.qa', password: 'Birou-QA-123'),
          isNotNull);
      expect(await repo.mustChangePassword('u2'), isFalse);
    });

    test('non-release: fără marcaj (cont de dezvoltare)', () async {
      _oldDeviceState();
      final repo = FieldLocalAuthRepository(
          seedDefaultAdmin: true, hasher: LocalPasswordHasher(iterations: 2000));
      await repo.login(email: _admin, password: _seed);
      expect(await repo.mustChangePassword('admin-legacy'), isFalse);
    });

    test('schimbare: validări (parolă curentă, lungime, reutilizare)', () async {
      _oldDeviceState();
      final repo = _release();
      await repo.login(email: _admin, password: _seed);
      expect(
          await repo.changeLocalPassword(
              userId: 'admin-legacy',
              currentPassword: 'gresita-QA',
              newPassword: _newPw),
          isNotNull);
      expect(
          await repo.changeLocalPassword(
              userId: 'admin-legacy', currentPassword: _seed, newPassword: 'scurt'),
          isNotNull);
      expect(
          await repo.changeLocalPassword(
              userId: 'admin-legacy', currentPassword: _seed, newPassword: _seed),
          isNotNull);
      expect(await repo.mustChangePassword('admin-legacy'), isTrue);
    });

    test('schimbare reușită: marcaj șters, parola nouă merge, cea veche nu',
        () async {
      _oldDeviceState();
      final repo = _release();
      await repo.login(email: _admin, password: _seed);
      expect(
          await repo.changeLocalPassword(
              userId: 'admin-legacy', currentPassword: _seed, newPassword: _newPw),
          isNull);
      expect(await repo.mustChangePassword('admin-legacy'), isFalse);
      await repo.logout();
      expect(await repo.login(email: _admin, password: _seed), isNull);
      final again = await repo.login(email: _admin, password: _newPw);
      expect(again, isNotNull);
      expect(again!.role, FieldUserRole.admin);
      expect(await repo.mustChangePassword('admin-legacy'), isFalse);
    });
  });

  group('FieldAuthGate', () {
    testWidgets('după login cu parola implicită -> ecran schimbare, apoi aplicația',
        (tester) async {
      _oldDeviceState();
      final service = FieldAuthService(_release());
      await tester.pumpWidget(MaterialApp(
        home: FieldAuthGate(
          authService: service,
          authenticatedBuilder: (_) => const Text('APLICATIE'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(await service.login(email: _admin, password: _seed), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Schimbă parola'), findsWidgets);
      expect(find.text('APLICATIE'), findsNothing);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Parola curentă'), _seed);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Parola nouă'), _newPw);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmă parola nouă'), _newPw);
      await tester.tap(find.widgetWithText(FilledButton, 'Schimbă parola'));
      await tester.pumpAndSettle();
      expect(find.text('APLICATIE'), findsOneWidget);
    });

    testWidgets('restart cu sesiune restaurată și marcaj -> tot ecranul de schimbare',
        (tester) async {
      _oldDeviceState();
      await _release().login(email: _admin, password: _seed);
      final service = FieldAuthService(_release());
      await tester.pumpWidget(MaterialApp(
        home: FieldAuthGate(
          authService: service,
          authenticatedBuilder: (_) => const Text('APLICATIE'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('APLICATIE'), findsNothing);
      expect(find.text('Deconectare'), findsOneWidget);
      await tester.tap(find.text('Deconectare'));
      await tester.pumpAndSettle();
      expect(service.isAuthenticated, isFalse);
    });
  });
}
