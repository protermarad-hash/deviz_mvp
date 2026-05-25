// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/cloud/cloud_sync_models.dart';
import '../lib/core/cloud/cloud_sync_service.dart';
import '../lib/core/cloud/local_cloud_sync_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalCloudSyncRepository – deduplication', () {
    test('upsert followed by delete keeps only the delete for the same entity',
        () async {
      final repo = LocalCloudSyncRepository();
      final service = CloudSyncService(repo);

      // Simulate: create/update appointment, then delete it offline
      await service.queueUpsert(
        entityType: CloudEntityType.appointments,
        entityId: 'appt-1',
        payload: {'id': 'appt-1', 'title': 'Test'},
      );
      await service.queueDelete(
        entityType: CloudEntityType.appointments,
        entityId: 'appt-1',
      );

      final pending = await repo.listPendingItems();
      expect(pending.length, 1,
          reason: 'Only the last pending op per entity should remain');
      expect(pending.first.deleted, isTrue,
          reason: 'The surviving op must be the delete');
      expect(pending.first.entityId, 'appt-1');
    });

    test(
        'delete followed by upsert keeps only the upsert (re-creation scenario)',
        () async {
      final repo = LocalCloudSyncRepository();
      final service = CloudSyncService(repo);

      await service.queueDelete(
        entityType: CloudEntityType.appointments,
        entityId: 'appt-2',
      );
      await service.queueUpsert(
        entityType: CloudEntityType.appointments,
        entityId: 'appt-2',
        payload: {'id': 'appt-2', 'title': 'Re-added'},
      );

      final pending = await repo.listPendingItems();
      expect(pending.length, 1);
      expect(pending.first.deleted, isFalse);
      expect(pending.first.entityId, 'appt-2');
    });

    test('operations for different entity types do not interfere', () async {
      final repo = LocalCloudSyncRepository();
      final service = CloudSyncService(repo);

      await service.queueUpsert(
        entityType: CloudEntityType.appointments,
        entityId: 'shared-id',
        payload: {'id': 'shared-id'},
      );
      await service.queueUpsert(
        entityType: CloudEntityType.clients,
        entityId: 'shared-id',
        payload: {'id': 'shared-id'},
      );

      final pending = await repo.listPendingItems();
      expect(pending.length, 2,
          reason:
              'Same entity ID but different types must be separate queue entries');
    });

    test('operations for different entity IDs are kept independently',
        () async {
      final repo = LocalCloudSyncRepository();
      final service = CloudSyncService(repo);

      await service.queueDelete(
        entityType: CloudEntityType.appointments,
        entityId: 'appt-A',
      );
      await service.queueDelete(
        entityType: CloudEntityType.appointments,
        entityId: 'appt-B',
      );

      final pending = await repo.listPendingItems();
      expect(pending.length, 2);
    });

    test('markItemSynced does not remove pending ops for other entities',
        () async {
      final repo = LocalCloudSyncRepository();
      final service = CloudSyncService(repo);

      await service.queueDelete(
        entityType: CloudEntityType.appointments,
        entityId: 'appt-X',
      );
      await service.queueDelete(
        entityType: CloudEntityType.appointments,
        entityId: 'appt-Y',
      );

      final all = await repo.listItems();
      expect(all.length, 2);

      // Mark first one synced
      await repo.markItemSynced(all[0].id, DateTime.now());

      final pending = await repo.listPendingItems();
      expect(pending.length, 1);
      expect(pending.first.entityId, all[1].entityId);
    });

    test(
        'already-synced items are not removed when a new op for same entity is queued',
        () async {
      final repo = LocalCloudSyncRepository();
      final service = CloudSyncService(repo);

      // Queue and mark as synced
      await service.queueUpsert(
        entityType: CloudEntityType.clients,
        entityId: 'c-1',
        payload: {'id': 'c-1'},
      );
      final allAfterFirst = await repo.listItems();
      await repo.markItemSynced(allAfterFirst[0].id, DateTime.now());

      // Queue again for same entity
      await service.queueUpsert(
        entityType: CloudEntityType.clients,
        entityId: 'c-1',
        payload: {'id': 'c-1', 'name': 'Updated'},
      );

      final allFinal = await repo.listItems();
      // Synced item stays; a new pending item is added
      final synced = allFinal.where((item) => item.isSynced).toList();
      final pending = allFinal.where((item) => !item.isSynced).toList();
      expect(synced.length, 1);
      expect(pending.length, 1);
      expect(pending.first.payload['name'], 'Updated');
    });

    test('clearAll removes all items', () async {
      final repo = LocalCloudSyncRepository();
      final service = CloudSyncService(repo);

      await service.queueDelete(
          entityType: CloudEntityType.appointments, entityId: 'x');
      await repo.clearAll();
      final pending = await repo.listPendingItems();
      expect(pending, isEmpty);
    });
  });

  group('End-to-end – offline appointment lifecycle', () {
    test('create → modify → delete leaves only a delete in the queue',
        () async {
      final repo = LocalCloudSyncRepository();
      final service = CloudSyncService(repo);

      // Step 1: user creates appointment offline
      await service.queueUpsert(
        entityType: CloudEntityType.appointments,
        entityId: 'appt-e2e',
        payload: {'id': 'appt-e2e', 'title': 'Initial'},
      );

      // Step 2: user modifies appointment before sync happens
      await service.queueUpsert(
        entityType: CloudEntityType.appointments,
        entityId: 'appt-e2e',
        payload: {'id': 'appt-e2e', 'title': 'Modified'},
      );

      var pending = await repo.listPendingItems();
      expect(pending.length, 1, reason: 'Modify replaces create in queue');
      expect(pending.first.payload['title'], 'Modified');

      // Step 3: user deletes before sync
      await service.queueDelete(
        entityType: CloudEntityType.appointments,
        entityId: 'appt-e2e',
      );

      pending = await repo.listPendingItems();
      expect(pending.length, 1, reason: 'Delete replaces modify in queue');
      expect(pending.first.deleted, isTrue);
    });

    test(
        'after syncPending marks items synced, a new operation is queued fresh',
        () async {
      final repo = LocalCloudSyncRepository();
      final service = CloudSyncService(repo);

      // Simulate a successful sync cycle for appt-e2e-2
      await service.queueUpsert(
        entityType: CloudEntityType.appointments,
        entityId: 'appt-e2e-2',
        payload: {'id': 'appt-e2e-2'},
      );
      var all = await repo.listItems();
      await repo.markItemSynced(all[0].id, DateTime.now());

      expect((await repo.listPendingItems()), isEmpty);

      // User modifies after sync
      await service.queueUpsert(
        entityType: CloudEntityType.appointments,
        entityId: 'appt-e2e-2',
        payload: {'id': 'appt-e2e-2', 'title': 'Post-sync update'},
      );

      final pending = await repo.listPendingItems();
      expect(pending.length, 1);
      expect(pending.first.payload['title'], 'Post-sync update');
    });

    test('all entity types can be queued independently', () async {
      final repo = LocalCloudSyncRepository();
      final service = CloudSyncService(repo);

      for (final type in [
        CloudEntityType.appointments,
        CloudEntityType.clients,
        CloudEntityType.jobs,
        CloudEntityType.offers,
        CloudEntityType.complaints,
        CloudEntityType.documents,
        CloudEntityType.materials,
        CloudEntityType.teams,
      ]) {
        await service.queueDelete(entityType: type, entityId: 'id-$type');
      }

      final pending = await repo.listPendingItems();
      expect(pending.length, 8,
          reason: 'Each entity type must have its own queue slot');
    });
  });

  group('LocalCloudSyncRepository – ordering', () {
    test('listPendingItems returns items sorted by updatedAt ascending',
        () async {
      final repo = LocalCloudSyncRepository();
      // Insert items with explicit different timestamps by awaiting each
      final service = CloudSyncService(repo);
      await service.queueUpsert(
        entityType: CloudEntityType.jobs,
        entityId: 'job-1',
        payload: {'id': 'job-1'},
      );
      // Small delay ensures a distinct timestamp
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await service.queueUpsert(
        entityType: CloudEntityType.jobs,
        entityId: 'job-2',
        payload: {'id': 'job-2'},
      );

      final pending = await repo.listPendingItems();
      expect(pending.length, 2);
      expect(
        pending[0].updatedAt.isBefore(pending[1].updatedAt) ||
            pending[0].updatedAt.isAtSameMomentAs(pending[1].updatedAt),
        isTrue,
      );
    });
  });

  group('LocalCloudSyncRepository – retry backoff metadata', () {
    test('failed item is deferred until next attempt time', () async {
      final repo = LocalCloudSyncRepository();
      final service = CloudSyncService(repo);

      await service.queueUpsert(
        entityType: CloudEntityType.jobs,
        entityId: 'retry-job-1',
        payload: {'id': 'retry-job-1'},
      );

      final created = await repo.listPendingItems();
      expect(created.length, 1);

      await repo.markItemFailed(
        id: created.first.id,
        attemptedAt: DateTime.now(),
        nextAttemptAt: DateTime.now().add(const Duration(hours: 1)),
        errorMessage: 'temporary network error',
      );

      final pending = await repo.listPendingItems();
      expect(
        pending.where((item) => item.entityId == 'retry-job-1'),
        isEmpty,
        reason: 'Deferred item should not be picked before nextAttemptAt.',
      );
    });

    test('markItemSynced clears retry metadata', () async {
      final repo = LocalCloudSyncRepository();
      final service = CloudSyncService(repo);

      await service.queueUpsert(
        entityType: CloudEntityType.clients,
        entityId: 'retry-client-1',
        payload: {'id': 'retry-client-1'},
      );
      final created = await repo.listPendingItems();
      await repo.markItemFailed(
        id: created.first.id,
        attemptedAt: DateTime.now(),
        nextAttemptAt: DateTime.now(),
        errorMessage: 'temporary error',
      );
      await repo.markItemSynced(created.first.id, DateTime.now());

      final all = await repo.listItems();
      final synced =
          all.firstWhere((item) => item.entityId == 'retry-client-1');
      expect(synced.retryCount, 0);
      expect(synced.lastError, isNull);
      expect(synced.nextAttemptAt, isNull);
      expect(synced.lastAttemptAt, isNull);
      expect(synced.isSynced, isTrue);
    });
  });
}
