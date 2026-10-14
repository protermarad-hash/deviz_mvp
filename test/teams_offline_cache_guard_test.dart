import 'package:devizpro_ultra/features/master/master_local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pre = MasterTeam(id: 't-pre', name: 'Echipa existenta', notes: '', memberIds: []);
const _nou = MasterTeam(id: 't-nou', name: 'Echipa noua', notes: '', memberIds: []);

Future<List<String>> _ids() async =>
    (await MasterLocalStore.readTeams()).map((t) => t.id).toList();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cache offline gol NU golește echipele locale', () async {
    await MasterLocalStore.writeTeams(const [_pre]);
    final r = await MasterLocalStore.replaceTeamsFromCloud(const [], fromCache: true);
    expect(r.map((t) => t.id), ['t-pre']);
    expect(await _ids(), ['t-pre']);
  });

  test('cache incomplet (doar scrierea în așteptare) se îmbină', () async {
    await MasterLocalStore.writeTeams(const [_pre]);
    final r = await MasterLocalStore.replaceTeamsFromCloud(const [_nou], fromCache: true);
    expect(r.map((t) => t.id).toSet(), {'t-pre', 't-nou'});
    expect((await _ids()).toSet(), {'t-pre', 't-nou'});
  });

  test('cache: versiunea din cache câștigă la același ID', () async {
    await MasterLocalStore.writeTeams(const [_pre]);
    const updated = MasterTeam(id: 't-pre', name: 'Redenumita', notes: '', memberIds: []);
    final r = await MasterLocalStore.replaceTeamsFromCloud(const [updated], fromCache: true);
    expect(r.single.name, 'Redenumita');
  });

  test('răspuns de la server (inclusiv gol) rămâne autoritativ', () async {
    await MasterLocalStore.writeTeams(const [_pre]);
    expect(await MasterLocalStore.replaceTeamsFromCloud(const [_nou], fromCache: false),
        hasLength(1));
    expect(await _ids(), ['t-nou']);
    expect(await MasterLocalStore.replaceTeamsFromCloud(const [], fromCache: false), isEmpty);
    expect(await _ids(), isEmpty);
  });
}
