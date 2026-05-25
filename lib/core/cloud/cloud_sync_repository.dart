import 'cloud_sync_models.dart';

abstract class CloudSyncRepository {
  Future<List<CloudSyncItem>> listItems();
  Future<List<CloudSyncItem>> listPendingItems();
  Future<void> upsertItem(CloudSyncItem item);
  Future<void> markItemSynced(String id, DateTime syncedAt);
  Future<void> markItemFailed({
    required String id,
    required DateTime attemptedAt,
    required DateTime nextAttemptAt,
    required String errorMessage,
  });
  Future<void> clearAll();
}

