import 'dart:convert';

import 'package:devizpro_ultra/core/auth/field_auth_models.dart';
import 'package:devizpro_ultra/core/auth/field_local_auth_repository.dart';
import 'package:devizpro_ultra/core/auth/local_password_hasher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parole FICTIVE, doar pentru teste.
const _pw = 'Parola-Test-QA-1';
const _pw2 = 'Alta-Parola-QA-2';

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

String _legacy(String p) => base64Encode(utf8.encode(p));

FieldAuthUser _user(String id, String email, String hash,
        {FieldUserRole role = FieldUserRole.employee, bool active = true}) =>
    FieldAuthUser(
      id: id,
      name: id,
      email: email,
      role: role,
      active: active,
      passwordHash: hash,
    );

Future<void> _seedUsers(List<FieldAuthUser> users) async {
  SharedPreferences.setMockInitialValues({
    'field_auth_users_v1': jsonEncode(users.map((u) => u.toMap()).toList()),
  });
}

Future<List<Map<String, dynamic>>> _storedUsers() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('field_auth_users_v1');
  if (raw == null) return const [];
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

void main() {
  // Iterații reduse DOAR în teste (viteză); producția folosește
  // LocalPasswordHasher.defaultIterations.
  final fastHasher = LocalPasswordHasher(iterations: 2000);

  group('PBKDF2-HMAC-SHA256 (vectori de test publici)', () {
    final p = utf8.encode('password');
    final s = utf8.encode('salt');
    test('c=1', () {
      expect(_hex(LocalPasswordHasher.pbkdf2(p, s, 1, 32)),
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
    });
    test('c=2', () {
      expect(_hex(LocalPasswordHasher.pbkdf2(p, s, 2, 32)),
          'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
    });
    test('c=4096', () {
      expect(_hex(LocalPasswordHasher.pbkdf2(p, s, 4096, 32)),
          'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
    });
  });

  group('LocalPasswordHasher', () {
    test('hash: format documentat, salt diferit la fiecare apel', () {
      final a = fastHasher.hash(_pw);
      final b = fastHasher.hash(_pw);
      expect(a, startsWith('pbkdf2_sha256\$2000\$'));
      expect(a.split('\$'), hasLength(4));
      expect(a, isNot(b));
      expect(a.contains(_pw), isFalse);
      expect(a.contains(_legacy(_pw)), isFalse);
    });
    test('verify: corectă / greșită / goală / coruptă', () {
      final h = fastHasher.hash(_pw);
      expect(fastHasher.verify(_pw, h), isTrue);
      expect(fastHasher.verify(_pw2, h), isFalse);
      expect(fastHasher.verify('', h), isFalse);
      expect(fastHasher.verify(_pw, ''), isFalse);
      expect(fastHasher.verify(_pw, 'pbkdf2_sha256\$x\$y\$z'), isFalse);
      expect(fastHasher.verify(_pw, 'pbkdf2_sha256\$99999999999\$AAAA\$AAAA'),
          isFalse);
    });
    test('parola goală nu poate fi hash-uită', () {
      expect(() => fastHasher.hash(''), throwsArgumentError);
    });
    test('format vechi: recunoscut doar pentru migrare', () {
      expect(LocalPasswordHasher.isLegacy(_legacy(_pw)), isTrue);
      expect(LocalPasswordHasher.verifyLegacy(_pw, _legacy(_pw)), isTrue);
      expect(LocalPasswordHasher.verifyLegacy(_pw2, _legacy(_pw)), isFalse);
      expect(LocalPasswordHasher.verifyLegacy('', ''), isFalse);
      expect(fastHasher.needsRehash(_legacy(_pw)), isTrue);
      expect(LocalPasswordHasher(iterations: 4000)
          .needsRehash(fastHasher.hash(_pw)), isTrue);
      expect(fastHasher.needsRehash(fastHasher.hash(_pw)), isFalse);
    });
    test('cost cu parametrii de producție (informativ)', () {
      final sw = Stopwatch()..start();
      final h = LocalPasswordHasher().hash(_pw);
      sw.stop();
      expect(h, startsWith('pbkdf2_sha256\$${LocalPasswordHasher.defaultIterations}\$'));
      // ignore: avoid_print
      print('PBKDF2 ${LocalPasswordHasher.defaultIterations} iteratii: ${sw.elapsedMilliseconds} ms (host, JIT)');
    });
  });

  group('FieldLocalAuthRepository — instalare nouă', () {
    test('release: niciun administrator implicit creat, login imposibil',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repo = FieldLocalAuthRepository(
          seedDefaultAdmin: false, hasher: fastHasher);
      await repo.ensureSeedUsers();
      expect(await _storedUsers(), isEmpty);
      expect(
          await repo.login(
              email: FieldLocalAuthRepository.defaultAdminEmail, password: _pw),
          isNull);
      expect(await _storedUsers(), isEmpty);
      expect(await repo.loadSession(), isNull);
    });
    test('non-release: contul de dezvoltare are hash PBKDF2, nu base64',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repo =
          FieldLocalAuthRepository(seedDefaultAdmin: true, hasher: fastHasher);
      await repo.ensureSeedUsers();
      final users = await _storedUsers();
      expect(users, hasLength(1));
      expect(users.single['email'], FieldLocalAuthRepository.defaultAdminEmail);
      expect('${users.single['password_hash']}', startsWith('pbkdf2_sha256\$'));
    });
  });

  group('FieldLocalAuthRepository — upgrade cu utilizatori existenți', () {
    test('parolă veche (base64) -> login reușit + migrare la PBKDF2', () async {
      await _seedUsers([_user('u1', 'tehnician@test.qa', _legacy(_pw))]);
      final repo = FieldLocalAuthRepository(
          seedDefaultAdmin: false, hasher: fastHasher);
      final user = await repo.login(email: 'tehnician@test.qa', password: _pw);
      expect(user, isNotNull);
      final stored = '${(await _storedUsers()).single['password_hash']}';
      expect(stored, startsWith('pbkdf2_sha256\$'));
      expect(stored.contains(_legacy(_pw)), isFalse);
      // A doua autentificare folosește formatul nou.
      expect(await repo.login(email: 'tehnician@test.qa', password: _pw),
          isNotNull);
      expect(await repo.login(email: 'tehnician@test.qa', password: _pw2),
          isNull);
    });
    test('parolă greșită pe format vechi -> fără migrare, fără sesiune',
        () async {
      await _seedUsers([_user('u1', 'tehnician@test.qa', _legacy(_pw))]);
      final repo = FieldLocalAuthRepository(
          seedDefaultAdmin: false, hasher: fastHasher);
      expect(await repo.login(email: 'tehnician@test.qa', password: _pw2),
          isNull);
      expect((await _storedUsers()).single['password_hash'], _legacy(_pw));
      expect(await repo.loadSession(), isNull);
    });
    test('utilizatorii existenți NU sunt dezactivați sau șterși la upgrade',
        () async {
      await _seedUsers([
        _user('admin-legacy', FieldLocalAuthRepository.defaultAdminEmail,
            _legacy(_pw),
            role: FieldUserRole.admin),
        _user('u2', 'birou@test.qa', _legacy(_pw2)),
      ]);
      final repo = FieldLocalAuthRepository(
          seedDefaultAdmin: false, hasher: fastHasher);
      await repo.ensureSeedUsers();
      final users = await _storedUsers();
      expect(users, hasLength(2));
      expect(users.every((u) => u['active'] == true), isTrue);
      expect(await repo.login(email: 'birou@test.qa', password: _pw2),
          isNotNull);
    });
  });

  group('FieldLocalAuthRepository — fără ocoliri și fără escaladare', () {
    test('utilizator proiectat din cloud (hash gol) + parolă goală -> respins',
        () async {
      await _seedUsers([
        _user('cloud-1', 'sef@test.qa', '', role: FieldUserRole.admin),
      ]);
      final repo = FieldLocalAuthRepository(
          seedDefaultAdmin: false, hasher: fastHasher);
      expect(await repo.login(email: 'sef@test.qa', password: ''), isNull);
      expect(await repo.login(email: 'sef@test.qa', password: _pw), isNull);
      expect(await repo.loadSession(), isNull);
    });
    test('utilizator inactiv -> respins', () async {
      await _seedUsers([
        _user('u1', 'inactiv@test.qa', fastHasher.hash(_pw), active: false),
      ]);
      final repo = FieldLocalAuthRepository(
          seedDefaultAdmin: false, hasher: fastHasher);
      expect(await repo.login(email: 'inactiv@test.qa', password: _pw), isNull);
    });
    test('rolul sesiunii = rolul stocat (fără escaladare la migrare)',
        () async {
      await _seedUsers([_user('u1', 'tehnician@test.qa', _legacy(_pw))]);
      final repo = FieldLocalAuthRepository(
          seedDefaultAdmin: false, hasher: fastHasher);
      final user = await repo.login(email: 'tehnician@test.qa', password: _pw);
      expect(user!.role, FieldUserRole.employee);
      expect((await repo.loadSession())!.role, FieldUserRole.employee);
      expect((await _storedUsers()).single['role'], FieldUserRole.employee.name);
    });
    test('login/logout repetat', () async {
      await _seedUsers([_user('u1', 'tehnician@test.qa', fastHasher.hash(_pw))]);
      final repo = FieldLocalAuthRepository(
          seedDefaultAdmin: false, hasher: fastHasher);
      for (var i = 0; i < 3; i++) {
        expect(await repo.login(email: 'TEHNICIAN@test.qa ', password: _pw),
            isNotNull);
        expect(await repo.loadSession(), isNotNull);
        await repo.logout();
        expect(await repo.loadSession(), isNull);
      }
      expect(await _storedUsers(), hasLength(1));
    });
  });
}
