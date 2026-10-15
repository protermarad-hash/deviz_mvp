// Regresie F1 (QA Windows izolat 15.10.2026): salvarea clientului / ofertei
// pe un server inaccesibil cu DNS funcțional. `set()` nu se confirmă niciodată;
// înainte, salvarea aștepta la nesfârșit și datele nu ajungeau local.
import 'dart:async';

import 'package:devizpro_ultra/core/cloud/cloud_push.dart';
import 'package:devizpro_ultra/core/cloud/cloud_sync_models.dart';
import 'package:devizpro_ultra/core/cloud/local_cloud_sync_repository.dart';
import 'package:devizpro_ultra/core/repositories/local_app_data_repository.dart';
import 'package:devizpro_ultra/features/clients/client_models.dart';
import 'package:devizpro_ultra/features/oferte/offer_models.dart';
import 'package:devizpro_ultra/features/oferte/services/offer_persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ClientRecord _client(String id, {String notes = ''}) => ClientRecord.fromMap({
      'id': id, 'client_code': 'QA-$id', 'type': 'company', 'name': 'Client $id SRL',
      'contact_person': 'Persoana QA', 'phone': '0700000000', 'email': '$id@demo.test',
      'address': 'Strada QA', 'city': 'Arad', 'county': 'Arad', 'notes': notes,
    });

OfferRecord _offer(String id) => OfferRecord.fromMap({
      'id': id, 'offer_number': 'QA-OF-$id', 'title': 'Oferta $id', 'client_id': 'c1',
    });

Future<List<CloudSyncItem>> _queued(CloudEntityType type, String id) async {
  // queueClient este lansat ne-așteptat (unawaited) din saveClient.
  for (var i = 0; i < 20; i++) {
    final items = (await LocalCloudSyncRepository().listItems())
        .where((x) => x.entityType == type && x.entityId == id)
        .toList();
    if (items.isNotEmpty) return items;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return const [];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    LocalAppDataRepository.debugClientCloudWrite = null;
    LocalAppDataRepository.debugClientsCloudAvailable = null;
  });

  group('saveClient — local întâi (F1)', () {
    test('server inaccesibil (scriere neconfirmată): revine după timeout, client local + coadă',
        () async {
      LocalAppDataRepository.debugClientsCloudAvailable = true;
      final calls = <String>[];
      LocalAppDataRepository.debugClientCloudWrite = (id, data) {
        calls.add('cloud:$id');
        return Completer<void>().future; // nu se confirmă niciodată
      };
      final repo = LocalAppDataRepository();
      final sw = Stopwatch()..start();
      await repo.saveClient(_client('c-hang', notes: 'nota offline'));
      expect(sw.elapsed, lessThan(const Duration(seconds: 15)),
          reason: 'salvarea nu mai așteaptă confirmarea serverului');
      final local = (await repo.listClients()).where((c) => c.id == 'c-hang').toList();
      expect(local, hasLength(1));
      expect(local.single.notes, 'nota offline');
      expect(calls, ['cloud:c-hang']);
      expect(await _queued(CloudEntityType.clients, 'c-hang'), hasLength(1));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('clientul este scris local ÎNAINTE de scrierea cloud', () async {
      LocalAppDataRepository.debugClientsCloudAvailable = true;
      final repo = LocalAppDataRepository();
      var seenLocally = false;
      LocalAppDataRepository.debugClientCloudWrite = (id, data) async {
        seenLocally = (await repo.listClients()).any((c) => c.id == id);
      };
      await repo.saveClient(_client('c-order'));
      expect(seenLocally, isTrue);
    });

    test('eroare cloud (ex. permission-denied): local + coadă', () async {
      LocalAppDataRepository.debugClientsCloudAvailable = true;
      LocalAppDataRepository.debugClientCloudWrite =
          (id, data) => Future<void>.error(StateError('permission-denied'));
      final repo = LocalAppDataRepository();
      await repo.saveClient(_client('c-fail'));
      expect((await repo.listClients()).map((c) => c.id), contains('c-fail'));
      expect(await _queued(CloudEntityType.clients, 'c-fail'), hasLength(1));
    });

    test('cloud confirmat: local + scriere cloud cu datele clientului', () async {
      LocalAppDataRepository.debugClientsCloudAvailable = true;
      Map<String, dynamic>? written;
      LocalAppDataRepository.debugClientCloudWrite = (id, data) async => written = data;
      final repo = LocalAppDataRepository();
      await repo.saveClient(_client('c-ok', notes: 'n'));
      expect((await repo.listClients()).map((c) => c.id), contains('c-ok'));
      expect(written?['id'], 'c-ok');
      expect(written?['updated_at'], isA<String>());
    });
  });

  group('offerSaveLocalFirst (F1 oferte)', () {
    test('server inaccesibil: local + coadă, revine după timeout', () async {
      final order = <String>[];
      final sw = Stopwatch()..start();
      final r = await offerSaveLocalFirst(
        offer: _offer('o-hang'),
        saveLocal: (o) async => order.add('local'),
        cloudUpsert: (o) {
          order.add('cloud');
          return Completer<void>().future;
        },
        queue: (o) async => order.add('queue'),
        online: true,
        cloudTimeout: const Duration(milliseconds: 100),
      );
      expect(r, CloudPushOutcome.failed);
      expect(order, ['local', 'cloud', 'queue']);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('confirmat + queueAlways=false (field_sales): fără coadă', () async {
      final order = <String>[];
      final r = await offerSaveLocalFirst(
        offer: _offer('o-ok'),
        saveLocal: (o) async => order.add('local'),
        cloudUpsert: (o) async => order.add('cloud'),
        queue: (o) async => order.add('queue'),
        queueAlways: false,
        online: true,
      );
      expect(r, CloudPushOutcome.synced);
      expect(order, ['local', 'cloud']);
    });

    test('confirmat + queueAlways=true (oferte_page): coada păstrată ca înainte', () async {
      final order = <String>[];
      await offerSaveLocalFirst(
        offer: _offer('o-ok2'),
        saveLocal: (o) async => order.add('local'),
        cloudUpsert: (o) async => order.add('cloud'),
        queue: (o) async => order.add('queue'),
        online: true,
      );
      expect(order, ['local', 'cloud', 'queue']);
    });

    test('eroare cloud sau fără cloud: local + coadă', () async {
      for (final cloud in <Future<void> Function(OfferRecord)?>[
        (o) => Future<void>.error(StateError('x')),
        null,
      ]) {
        final order = <String>[];
        final r = await offerSaveLocalFirst(
          offer: _offer('o-x'),
          saveLocal: (o) async => order.add('local'),
          cloudUpsert: cloud,
          queue: (o) async => order.add('queue'),
          queueAlways: false,
          online: true,
        );
        expect(r, CloudPushOutcome.failed);
        expect(order, ['local', 'queue']);
      }
    });

    test('offline: nu așteaptă cloud-ul (pendingOffline), local + coadă', () async {
      final order = <String>[];
      final r = await offerSaveLocalFirst(
        offer: _offer('o-off'),
        saveLocal: (o) async => order.add('local'),
        cloudUpsert: (o) => Completer<void>().future,
        queue: (o) async => order.add('queue'),
        queueAlways: false,
        online: false,
      );
      expect(r, CloudPushOutcome.pendingOffline);
      expect(order, ['local', 'queue']);
    });
  });
}
