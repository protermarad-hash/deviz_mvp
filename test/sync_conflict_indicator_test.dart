// RC 120: indicatorul minim de conflicte de sincronizare.
import 'package:devizpro_ultra/core/cloud/cloud_sync_models.dart';
import 'package:devizpro_ultra/core/cloud/local_cloud_sync_repository.dart';
import 'package:devizpro_ultra/core/cloud/offline_sync_runtime.dart';
import 'package:devizpro_ultra/core/cloud/revision_sync.dart';
import 'package:devizpro_ultra/core/cloud/sync_conflict_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SyncConflict conflict(String id, {String kind = 'concurrent_edit', String name = 'Client QA'}) => SyncConflict(
      entityType: CloudEntityType.clients,
      entityId: id,
      kind: kind,
      localPayload: {'id': id, 'name': name},
      serverPayload: {'id': id, 'name': '$name (server)'},
      baseRev: 1,
      serverRev: 2,
      detectedAt: DateTime(2026, 10, 16, 9, 30),
    );

Widget host() => const MaterialApp(home: Scaffold(body: Column(children: [SyncConflictBanner()])));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SyncConflictStore.openCount.value = 0;
  });

  testWidgets('fără conflicte: indicatorul nu apare', (tester) async {
    await SyncConflictStore.refreshOpenCount();
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('sync-conflict-banner')), findsNothing);
  });

  testWidgets('conflict deschis: numărul și mesajul că modificarea nu a ajuns pe server', (tester) async {
    await tester.pumpWidget(host());
    await tester.runAsync(() => SyncConflictStore().add(conflict('c1')));
    await tester.pump();
    expect(find.byKey(const Key('sync-conflict-banner')), findsOneWidget);
    expect(find.textContaining('1 modificare nu a ajuns pe server'), findsOneWidget);

    await tester.runAsync(() => SyncConflictStore().add(conflict('c2', name: 'Al doilea')));
    await tester.pump();
    expect(find.textContaining('2 modificări nu au ajuns pe server'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sync-conflict-banner')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Conflicte de sincronizare (2)'), findsOneWidget);
    expect(find.text('Client: Client QA'), findsOneWidget);
    expect(find.text('Client: Al doilea'), findsOneWidget);
    expect(find.textContaining('modificat între timp pe alt dispozitiv'), findsNWidgets(2));
  });

  testWidgets('persistență: după repornire indicatorul reapare din conflictele salvate', (tester) async {
    await tester.runAsync(() => SyncConflictStore().add(conflict('c1')));
    SyncConflictStore.openCount.value = 0; // proces nou: contorul pornește de la zero
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('sync-conflict-banner')), findsNothing);
    await tester.runAsync(SyncConflictStore.refreshOpenCount); // bootstrap
    await tester.pump();
    expect(find.textContaining('1 modificare nu a ajuns pe server'), findsOneWidget);
  });

  testWidgets('eroare temporară (în coadă, se reîncearcă) NU este conflict; epuizarea DA', (tester) async {
    final queue = LocalCloudSyncRepository();
    await tester.runAsync(() => queue.upsertItem(CloudSyncItem(
          id: 'clients_t1_1', entityType: CloudEntityType.clients, entityId: 't1',
          payload: const {'id': 't1', 'name': 'Temporar'}, updatedAt: DateTime(2026, 10, 16),
          retryCount: 3, lastError: 'unavailable',
        )));
    await tester.runAsync(() => OfflineSyncRuntime.instance.cleanupQueue());
    await tester.runAsync(SyncConflictStore.refreshOpenCount);
    await tester.pumpWidget(host());
    expect(find.byKey(const Key('sync-conflict-banner')), findsNothing,
        reason: 'eroarea temporară rămâne în coadă și se reîncearcă');
    expect((await tester.runAsync(queue.listItems))!.single.entityId, 't1');

    await tester.runAsync(() => queue.upsertItem(CloudSyncItem(
          id: 'clients_t1_2', entityType: CloudEntityType.clients, entityId: 't1',
          payload: const {'id': 't1', 'name': 'Temporar'}, updatedAt: DateTime(2026, 10, 16),
          retryCount: 10, lastError: 'unavailable',
        )));
    await tester.runAsync(() => OfflineSyncRuntime.instance.cleanupQueue());
    await tester.pump();
    expect(find.textContaining('1 modificare nu a ajuns pe server'), findsOneWidget,
        reason: 'după reîncercări epuizate devine conflict, cu payload-ul păstrat');
  });

  testWidgets('conflict rezolvat → indicatorul dispare; istoricul rămâne în arhivă', (tester) async {
    await tester.runAsync(() => SyncConflictStore().add(conflict('c1')));
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byKey(const Key('sync-conflict-banner')), findsOneWidget);
    await tester.runAsync(() => SyncConflictStore().resolve(CloudEntityType.clients, 'c1'));
    await tester.pump();
    expect(find.byKey(const Key('sync-conflict-banner')), findsNothing);
    expect((await tester.runAsync(SyncConflictStore().listArchived))!.length, 1);
  });

  test('stocările de test (namespace) nu modifică indicatorul aplicației', () async {
    await SyncConflictStore(namespace: 'A').add(conflict('x'));
    expect(SyncConflictStore.openCount.value, 0);
  });
}
