import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import '../../core/cloud/cloud_sync_models.dart';
import 'lucrare_asociere_local_store.dart';
import 'lucrare_asociere_models.dart';

class LucrareAsociereCloudRepository {
  LucrareAsociereCloudRepository._();
  static final instance = LucrareAsociereCloudRepository._();

  final LucrareAsociereLocalStore _local = const LucrareAsociereLocalStore();
  static String? lastFirestoreError;
  static int lastFirestoreCount = -1;
  static int lastLocalCount = 0;
  static DateTime? lastSyncAt;

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance
          .collection(FirebaseCollections.lucrariAsociere);

  Future<List<LucrareAsociereRecord>> listLocal() async {
    final items = await _local.list();
    lastLocalCount = items.length;
    return _sort(items);
  }

  Future<List<LucrareAsociereRecord>> listRemote() async {
    if (!FirebaseBootstrap.isInitialized) return const [];
    final snapshot = await _collection.get();
    final items = snapshot.docs
        .map((doc) => LucrareAsociereRecord.fromMap(<String, dynamic>{
              ...doc.data(),
              'id': doc.id,
            }))
        .toList(growable: false);
    lastFirestoreCount = items.length;
    return _sort(items);
  }

  Future<List<LucrareAsociereRecord>> listMerged() async {
    final local = await listLocal();
    if (!FirebaseBootstrap.isInitialized) return local;
    try {
      final pendingIds = await OfflineSyncRuntime.instance
          .pendingUpsertEntityIds(CloudEntityType.lucrariAsociere);
      final remote = await listRemote();
      final localById = {for (final item in local) item.id: item};
      final merged = <String, LucrareAsociereRecord>{};
      for (final cloudItem in remote) {
        final localItem = localById[cloudItem.id];
        if (localItem != null && pendingIds.contains(cloudItem.id)) {
          merged[cloudItem.id] = localItem;
        } else if (localItem != null &&
            localItem.revision > cloudItem.revision) {
          merged[cloudItem.id] = localItem;
          await OfflineSyncRuntime.instance.queueLucrareAsociere(localItem);
        } else {
          merged[cloudItem.id] = cloudItem;
        }
      }
      for (final localItem in local) {
        if (!merged.containsKey(localItem.id)) {
          merged[localItem.id] = localItem;
          await OfflineSyncRuntime.instance.queueLucrareAsociere(localItem);
        }
      }
      final result = _sort(merged.values.toList(growable: false));
      await _local.writeAll(result);
      lastFirestoreError = null;
      lastSyncAt = DateTime.now();
      return result;
    } catch (error) {
      lastFirestoreError = '$error';
      return local;
    }
  }

  Future<LucrareAsociereRecord> create(LucrareAsociereRecord record) async {
    final errors = record.validate();
    if (errors.isNotEmpty) throw StateError(errors.join('\n'));
    final existing = await listMerged();
    if (existing.any((item) =>
        item.id == record.id ||
        item.numar.trim().toLowerCase() == record.numar.trim().toLowerCase())) {
      throw StateError('Numărul proiectului trebuie să fie unic.');
    }
    await _persist(record);
    return record;
  }

  Future<LucrareAsociereRecord> update(
    LucrareAsociereRecord record, {
    required int expectedRevision,
  }) async {
    final errors = record.validate();
    if (errors.isNotEmpty) throw StateError(errors.join('\n'));
    final local = await listMerged();
    final current = local.where((item) => item.id == record.id).firstOrNull;
    if (current != null && current.revision != expectedRevision) {
      throw StateError(
        'Proiectul a fost modificat între timp. Reîncarcă înainte de salvare.',
      );
    }
    if (local.any((item) =>
        item.id != record.id &&
        item.numar.trim().toLowerCase() == record.numar.trim().toLowerCase())) {
      throw StateError('Numărul proiectului trebuie să fie unic.');
    }
    await _persist(record);
    return record;
  }

  Future<void> archive(String id, {required String actor}) async {
    final items = await listLocal();
    final current = items.where((item) => item.id == id).firstOrNull;
    if (current == null) throw StateError('Proiectul nu există local.');
    final updated = LucrareAsociereRecord.fromMap(current.toMap()
      ..addAll(<String, dynamic>{
        'arhivat': true,
        'active': false,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': actor,
        'revision': current.revision + 1,
      }));
    await _persist(updated);
  }

  Future<void> _persist(LucrareAsociereRecord record) async {
    await _local.upsert(record);
    await OfflineSyncRuntime.instance.queueLucrareAsociere(record);
    if (FirebaseBootstrap.isInitialized) {
      _collection
          .doc(record.id)
          .set(record.toMap(), SetOptions(merge: true))
          .catchError((Object error) {
        lastFirestoreError = '$error';
      });
    }
  }

  Future<int> forceSyncLocalToCloud() async {
    final items = await listLocal();
    for (final item in items) {
      await OfflineSyncRuntime.instance.queueLucrareAsociere(item);
    }
    return items.length;
  }

  List<LucrareAsociereRecord> search(
    List<LucrareAsociereRecord> source, {
    String query = '',
    LucrareAsociereStatus? status,
    String clientId = '',
    String partnerId = '',
    String managerId = '',
    bool includeArchived = false,
  }) {
    final needle = query.trim().toLowerCase();
    return _sort(source.where((item) {
      if (!includeArchived && item.arhivat) return false;
      if (status != null && item.status != status) return false;
      if (clientId.isNotEmpty && item.clientId != clientId) return false;
      if (partnerId.isNotEmpty && item.partnerId != partnerId) return false;
      if (managerId.isNotEmpty && item.managerId != managerId) return false;
      if (needle.isEmpty) return true;
      return <String>[
        item.numar,
        item.denumire,
        item.clientNameSnapshot,
        item.partnerNameSnapshot,
        item.managerNameSnapshot,
      ].any((value) => value.toLowerCase().contains(needle));
    }).toList(growable: false));
  }

  List<LucrareAsociereRecord> _sort(List<LucrareAsociereRecord> items) =>
      items.toList(growable: false)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}
