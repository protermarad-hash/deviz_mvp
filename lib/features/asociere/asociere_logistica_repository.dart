import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cloud/cloud_sync_models.dart';
import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'cazare_asociere_models.dart';
import 'deplasare_asociere_models.dart';
import 'diurna_asociere_models.dart';

typedef _Decoder<T> = T Function(Map<String, dynamic> map);
typedef _Encoder<T> = Map<String, dynamic> Function(T value);
typedef _Queue<T> = Future<void> Function(T value);

class _LogisticaStore<T> {
  const _LogisticaStore({
    required this.localKey,
    required this.collection,
    required this.entityType,
    required this.decode,
    required this.encode,
    required this.queue,
    required this.idOf,
    required this.projectIdOf,
    required this.revisionOf,
    required this.dateOf,
  });

  final String localKey;
  final String collection;
  final CloudEntityType entityType;
  final _Decoder<T> decode;
  final _Encoder<T> encode;
  final _Queue<T> queue;
  final String Function(T value) idOf;
  final String Function(T value) projectIdOf;
  final int Function(T value) revisionOf;
  final DateTime Function(T value) dateOf;

  Future<List<T>> listLocal() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString(localKey) ?? '[]');
      if (raw is! List) return const [];
      return _sort(raw
          .whereType<Map>()
          .map((item) => decode(Map<String, dynamic>.from(item)))
          .toList());
    } catch (_) {
      return const [];
    }
  }

  Future<List<T>> listMerged() async {
    final local = await listLocal();
    if (!FirebaseBootstrap.isInitialized) return local;
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection(collection).get();
      final remote = snapshot.docs
          .map((doc) => decode({...doc.data(), 'id': doc.id}))
          .toList();
      final pending =
          await OfflineSyncRuntime.instance.pendingUpsertEntityIds(entityType);
      final localById = {for (final item in local) idOf(item): item};
      final merged = <String, T>{};
      for (final remoteItem in remote) {
        final id = idOf(remoteItem);
        final localItem = localById[id];
        merged[id] = localItem != null &&
                (pending.contains(id) ||
                    revisionOf(localItem) > revisionOf(remoteItem))
            ? localItem
            : remoteItem;
      }
      for (final localItem in local) {
        final id = idOf(localItem);
        if (!merged.containsKey(id)) {
          merged[id] = localItem;
          await queue(localItem);
        }
      }
      final result = _sort(merged.values.toList());
      await _writeAll(result);
      return result;
    } catch (_) {
      return local;
    }
  }

  Future<List<T>> listByProject(String projectId) async {
    final items = await listMerged();
    return _sort(
        items.where((item) => projectIdOf(item) == projectId).toList());
  }

  Future<void> upsert(T value) async {
    final items = await listLocal();
    final index = items.indexWhere((item) => idOf(item) == idOf(value));
    if (index < 0) {
      items.add(value);
    } else {
      items[index] = value;
    }
    await _writeAll(items);
    await queue(value);
  }

  Future<void> _writeAll(List<T> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      localKey,
      jsonEncode(values.map(encode).toList()),
    );
  }

  List<T> _sort(List<T> values) =>
      values..sort((a, b) => dateOf(b).compareTo(dateOf(a)));
}

class DeplasareAsociereRepository {
  DeplasareAsociereRepository._();
  static final instance = DeplasareAsociereRepository._();

  final _store = _LogisticaStore<DeplasareAsociereRecord>(
    localKey: 'deplasari_asociere_v1',
    collection: FirebaseCollections.deplasariAsociere,
    entityType: CloudEntityType.deplasariAsociere,
    decode: DeplasareAsociereRecord.fromMap,
    encode: (value) => value.toMap(),
    queue: OfflineSyncRuntime.instance.queueDeplasareAsociere,
    idOf: (value) => value.id,
    projectIdOf: (value) => value.projectId,
    revisionOf: (value) => value.revision,
    dateOf: (value) => value.dataPlecare,
  );

  Future<List<DeplasareAsociereRecord>> listLocal() => _store.listLocal();
  Future<List<DeplasareAsociereRecord>> listMerged() => _store.listMerged();
  Future<List<DeplasareAsociereRecord>> listByProject(String id) =>
      _store.listByProject(id);
  Future<void> upsert(DeplasareAsociereRecord value) => _store.upsert(value);
}

class CazareAsociereRepository {
  CazareAsociereRepository._();
  static final instance = CazareAsociereRepository._();

  final _store = _LogisticaStore<CazareAsociereRecord>(
    localKey: 'cazari_asociere_v1',
    collection: FirebaseCollections.cazariAsociere,
    entityType: CloudEntityType.cazariAsociere,
    decode: CazareAsociereRecord.fromMap,
    encode: (value) => value.toMap(),
    queue: OfflineSyncRuntime.instance.queueCazareAsociere,
    idOf: (value) => value.id,
    projectIdOf: (value) => value.projectId,
    revisionOf: (value) => value.revision,
    dateOf: (value) => value.checkIn,
  );

  Future<List<CazareAsociereRecord>> listLocal() => _store.listLocal();
  Future<List<CazareAsociereRecord>> listMerged() => _store.listMerged();
  Future<List<CazareAsociereRecord>> listByProject(String id) =>
      _store.listByProject(id);
  Future<void> upsert(CazareAsociereRecord value) => _store.upsert(value);
}

class DiurnaAsociereRepository {
  DiurnaAsociereRepository._();
  static final instance = DiurnaAsociereRepository._();

  final _store = _LogisticaStore<DiurnaAsociereRecord>(
    localKey: 'diurne_asociere_v1',
    collection: FirebaseCollections.diurneAsociere,
    entityType: CloudEntityType.diurneAsociere,
    decode: DiurnaAsociereRecord.fromMap,
    encode: (value) => value.toMap(),
    queue: OfflineSyncRuntime.instance.queueDiurnaAsociere,
    idOf: (value) => value.id,
    projectIdOf: (value) => value.projectId,
    revisionOf: (value) => value.revision,
    dateOf: (value) => value.dataInceput,
  );

  Future<List<DiurnaAsociereRecord>> listLocal() => _store.listLocal();
  Future<List<DiurnaAsociereRecord>> listMerged() => _store.listMerged();
  Future<List<DiurnaAsociereRecord>> listByProject(String id) =>
      _store.listByProject(id);
  Future<void> upsert(DiurnaAsociereRecord value) => _store.upsert(value);
}
