import 'dart:math';

import 'cloud_sync_models.dart';
import 'cloud_sync_repository.dart';

class CloudSyncService {
  CloudSyncService(this._repository);

  final CloudSyncRepository _repository;
  final Random _random = Random();

  Future<void> queueUpsert({
    required CloudEntityType entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now();
    final item = CloudSyncItem(
      id: _buildId(entityType, entityId, now),
      entityType: entityType,
      entityId: entityId,
      payload: payload,
      updatedAt: now,
    );
    await _repository.upsertItem(item);
  }

  Future<void> queueDelete({
    required CloudEntityType entityType,
    required String entityId,
  }) async {
    final now = DateTime.now();
    final item = CloudSyncItem(
      id: _buildId(entityType, entityId, now),
      entityType: entityType,
      entityId: entityId,
      payload: const <String, dynamic>{},
      updatedAt: now,
      deleted: true,
    );
    await _repository.upsertItem(item);
  }

  Future<List<CloudSyncItem>> pending() => _repository.listPendingItems();

  String _buildId(CloudEntityType type, String entityId, DateTime now) {
    final millis = now.millisecondsSinceEpoch;
    final suffix = _random.nextInt(999999).toString().padLeft(6, '0');
    return '${type.name}_${entityId}_${millis}_$suffix';
  }
}
