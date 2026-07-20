import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:devizpro_ultra/features/asociere/lucrare_asociere_cloud_repository.dart';
import 'package:devizpro_ultra/features/asociere/lucrare_asociere_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 7, 20);

  LucrareAsociereRecord record(String id, String number, {int revision = 1}) =>
      LucrareAsociereRecord(
        id: id,
        numar: number,
        denumire: 'Proiect $number',
        partnerId: 'partner',
        partnerNameSnapshot: 'Partener',
        dataInceput: now,
        createdAt: now,
        updatedAt: now,
        revision: revision,
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('CRUD local și listMerged offline nu pierd proiecte', () async {
    final repository = LucrareAsociereCloudRepository.instance;
    await repository.create(record('p1', 'AS-1'));
    expect(await repository.listLocal(), hasLength(1));
    expect(await repository.listMerged(), hasLength(1));
    await repository.update(record('p1', 'AS-1', revision: 2),
        expectedRevision: 1);
    expect((await repository.listLocal()).single.revision, 2);
    await repository.archive('p1', actor: 'admin');
    final archived = (await repository.listLocal()).single;
    expect(archived.arhivat, isTrue);
    expect(archived.active, isFalse);
  });

  test('protecție duplicate număr', () async {
    final repository = LucrareAsociereCloudRepository.instance;
    await repository.create(record('p1', 'AS-1'));
    expect(() => repository.create(record('p2', 'as-1')), throwsStateError);
  });

  test('control optimist de revizie nu este last-write-wins orb', () async {
    final repository = LucrareAsociereCloudRepository.instance;
    await repository.create(record('p1', 'AS-1'));
    expect(
      () => repository.update(record('p1', 'AS-1', revision: 2),
          expectedRevision: 99),
      throwsStateError,
    );
  });
}
