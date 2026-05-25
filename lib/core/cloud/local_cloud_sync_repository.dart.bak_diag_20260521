import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync_models.dart';
import 'cloud_sync_repository.dart';

class LocalCloudSyncRepository implements CloudSyncRepository {
  static const _syncQueueKey = 'cloud_sync_queue_v1';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.remove(_syncQueueKey);
  }

  @override
  Future<List<CloudSyncItem>> listItems() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_syncQueueKey);
    if (raw == null || raw.isEmpty) return const <CloudSyncItem>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <CloudSyncItem>[];
    return decoded
        .whereType<Map>()
        .map((entry) => CloudSyncItem.fromMap(
              Map<String, dynamic>.from(entry),
            ))
        .toList();
  }

  @override
  Future<List<CloudSyncItem>> listPendingItems() async {
    final items = await listItems();
    final now = DateTime.now();
    return items
        .where(
          (item) =>
              !item.isSynced &&
              (item.nextAttemptAt == null || !item.nextAttemptAt!.isAfter(now)),
        )
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
  }

  @override
  Future<void> markItemSynced(String id, DateTime syncedAt) async {
    // Ștergem direct itemul sincronizat — nu îl păstrăm cu isSynced=true.
    // Motivul: coada nu se umfla indefinit; performanța rămâne constantă.
    final items = await listItems();
    final updated = items.where((item) => item.id != id).toList();
    await _saveAll(updated);
  }

  /// Elimină din coadă itemele deja sincronizate (isSynced=true) și pe cele
  /// care au depășit numărul maxim de reîncercări (sunt moarte).
  /// Se apelează la startul fiecărui syncPending() pentru a curăța backlog-ul.
  Future<void> clearStale({int maxRetries = 10}) async {
    final items = await listItems();
    final active = items
        .where((i) => !i.isSynced && i.retryCount < maxRetries)
        .toList();
    if (active.length < items.length) {
      debugPrint('[Queue] clearStale: ${items.length - active.length} iteme eliminate '
          '(rămân ${active.length} active)');
      await _saveAll(active);
    }
  }

  @override
  Future<void> markItemFailed({
    required String id,
    required DateTime attemptedAt,
    required DateTime nextAttemptAt,
    required String errorMessage,
  }) async {
    final items = await listItems();
    final updated = items
        .map(
          (item) => item.id == id
              ? item.copyWith(
                  retryCount: item.retryCount + 1,
                  lastError: errorMessage,
                  lastAttemptAt: attemptedAt,
                  nextAttemptAt: nextAttemptAt,
                )
              : item,
        )
        .toList();
    await _saveAll(updated);
  }

  @override
  Future<void> upsertItem(CloudSyncItem item) async {
    final items = List<CloudSyncItem>.of(await listItems());
    items.removeWhere(
      (existing) =>
          !existing.isSynced &&
          existing.entityType == item.entityType &&
          existing.entityId == item.entityId,
    );
    final index = items.indexWhere((existing) => existing.id == item.id);
    if (index >= 0) {
      items[index] = item;
    } else {
      items.add(item);
    }
    await _saveAll(items);
  }

  /// Adaugă mai multe iteme în coadă cu O(1) citire + O(1) scriere SharedPreferences.
  /// Înlocuiește bucla `for (item in list) { await upsertItem(item); }` (O(n) I/O).
  Future<void> upsertBatch(List<CloudSyncItem> newItems) async {
    if (newItems.isEmpty) return;
    final items = List<CloudSyncItem>.of(await listItems());
    for (final item in newItems) {
      items.removeWhere(
        (existing) =>
            !existing.isSynced &&
            existing.entityType == item.entityType &&
            existing.entityId == item.entityId,
      );
      final index = items.indexWhere((existing) => existing.id == item.id);
      if (index >= 0) {
        items[index] = item;
      } else {
        items.add(item);
      }
    }
    await _saveAll(items);
  }

  Future<void> _saveAll(List<CloudSyncItem> items) async {
    final prefs = await _prefs;
    final encoded = jsonEncode(
      items.map((item) => item.toMap()).toList(),
    );
    await prefs.setString(_syncQueueKey, encoded);
  }
}
