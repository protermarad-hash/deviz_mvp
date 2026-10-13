import 'package:devizpro_ultra/core/auth/field_auth_models.dart';
import 'package:devizpro_ultra/core/auth/field_local_auth_repository.dart';
import 'package:devizpro_ultra/core/auth/local_password_hasher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parole FICTIVE pentru teste.
const _pw = 'Parola-Locala-QA-1';

FieldLocalAuthRepository _repo() => FieldLocalAuthRepository(
    seedDefaultAdmin: false, hasher: LocalPasswordHasher(iterations: 2000));

FieldAuthUser _cloud(String id, {FieldUserRole role = FieldUserRole.office, bool active = true}) =>
    FieldAuthUser(
      id: id,
      name: 'Din cloud',
      email: 'birou@test.qa',
      role: role,
      active: active,
      // Cloud-ul nu transportă niciodată hash-ul (FieldFirebaseAuthAdapter).
      passwordHash: '',
    );

Future<void> _seedLocal(FieldLocalAuthRepository repo) => repo.saveUser(
      FieldAuthUser(
        id: 'u1',
        name: 'Birou',
        email: 'birou@test.qa',
        role: FieldUserRole.employee,
        active: true,
        passwordHash: repo.hashPasswordForStorage(_pw),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('proiecția din cloud păstrează hash-ul local -> login offline merge',
      () async {
    final repo = _repo();
    await _seedLocal(repo);
    await repo.saveCloudProjection(_cloud('u1'));

    final users = await repo.listUsers();
    expect(users, hasLength(1));
    expect(users.single.passwordHash, isNotEmpty);
    expect(users.single.role, FieldUserRole.office, reason: 'restul vine din cloud');
    expect(await repo.login(email: 'birou@test.qa', password: _pw), isNotNull);
  });

  test('regresie: saveUser simplu cu proiecția cloud ar șterge hash-ul', () async {
    final repo = _repo();
    await _seedLocal(repo);
    await repo.saveUser(_cloud('u1'));
    expect(await repo.login(email: 'birou@test.qa', password: _pw), isNull);
  });

  test('cont dezactivat în cloud: hash păstrat, dar login blocat', () async {
    final repo = _repo();
    await _seedLocal(repo);
    await repo.saveCloudProjection(_cloud('u1', active: false));
    expect(await repo.login(email: 'birou@test.qa', password: _pw), isNull);
  });

  test('utilizator cloud fără cont local: salvat fără hash (fără login local)',
      () async {
    final repo = _repo();
    await repo.saveCloudProjection(_cloud('c9'));
    final users = await repo.listUsers();
    expect(users.single.id, 'c9');
    expect(users.single.passwordHash, isEmpty);
    expect(await repo.login(email: 'birou@test.qa', password: _pw), isNull);
  });

  test('alt id cu același email nu primește hash-ul altui cont', () async {
    final repo = _repo();
    await _seedLocal(repo);
    await repo.saveCloudProjection(_cloud('c9'));
    final byId = {for (final u in await repo.listUsers()) u.id: u};
    expect(byId['c9']!.passwordHash, isEmpty);
    expect(byId['u1']!.passwordHash, isNotEmpty);
    expect(await repo.login(email: 'birou@test.qa', password: _pw), isNotNull);
  });
}
