import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'firebase_pachete_scule_repository.dart';
import 'local_pachete_scule_store.dart';
import 'pachete_scule_cloud_repository.dart';
import 'pachete_scule_models.dart';

class PacheteSculeCatalogService {
  PacheteSculeCatalogService({
    PacheteSculeCloudRepository? cloudRepository,
    LocalPacheteSculeStore? localStore,
  })  : _cloudRepository = cloudRepository ??
            (FirebaseBootstrap.isInitialized
                ? FirebasePacheteSculeRepository()
                : null),
        _localStore = localStore ?? LocalPacheteSculeStore();

  final PacheteSculeCloudRepository? _cloudRepository;
  final LocalPacheteSculeStore _localStore;

  String dataSourceLabel = 'local_cache';
  String? fallbackReason;

  void _markCloud() {
    dataSourceLabel = 'cloud';
    fallbackReason = null;
  }

  void _markLocalFallback([Object? error]) {
    dataSourceLabel = 'local_cache';
    fallbackReason =
        error == null ? 'cloud indisponibil' : _shortCloudError(error);
  }

  String _shortCloudError(Object error) {
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.isEmpty) return 'necunoscuta';
    return raw.length > 140 ? '${raw.substring(0, 140)}...' : raw;
  }

  Future<List<ToolPackageRecord>> listPackages() async {
    final cloud = _cloudRepository;
    final localRows = await _localStore.listPackages();
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listPackages();
      if (localRows.isNotEmpty) {
        final cloudIds = cloudRows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!cloudIds.contains(row.id)) {
            await cloud.upsertPackage(row);
          }
        }
        cloudRows = await cloud.listPackages();
      }
      _markCloud();
      await _localStore.savePackages(cloudRows);
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> upsertPackage(ToolPackageRecord item) async {
    final cloud = _cloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.upsertPackage(item);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
        queuedOffline = true;
      }
    } else {
      _markLocalFallback();
    }
    if (queuedOffline) {
      await OfflineSyncRuntime.instance.queueToolPackageUpsert(item);
    }
    final local = [...await _localStore.listPackages()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.savePackages(local);
  }

  Future<void> deletePackage(String packageId) async {
    final id = packageId.trim();
    if (id.isEmpty) return;
    final cloud = _cloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.deletePackage(id);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
        queuedOffline = true;
      }
    } else {
      _markLocalFallback();
    }
    if (queuedOffline) {
      await OfflineSyncRuntime.instance.queueToolPackageDelete(id);
    }
    final local = await _localStore.listPackages();
    final next = local.where((row) => row.id != id).toList(growable: false);
    await _localStore.savePackages(next);
  }

  Future<List<ToolPackageHandoverDocument>> listHandoverDocuments() async {
    final cloud = _cloudRepository;
    final localRows = await _localStore.listHandoverDocuments();
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var rows = await cloud.listHandoverDocuments();
      if (localRows.isNotEmpty) {
        final cloudIds = rows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!cloudIds.contains(row.id)) {
            await cloud.saveHandoverDocument(row);
          }
        }
        rows = await cloud.listHandoverDocuments();
      }
      _markCloud();
      await _localStore.saveHandoverDocuments(rows);
      return rows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> saveHandoverDocument(ToolPackageHandoverDocument item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.saveHandoverDocument(item);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final local = [...await _localStore.listHandoverDocuments()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveHandoverDocuments(local);
  }

  Future<List<ToolPackageMovementEvent>> listMovementEvents(String packageId) async {
    final id = packageId.trim();
    if (id.isEmpty) return const <ToolPackageMovementEvent>[];
    final cloud = _cloudRepository;
    final localRows = await _localStore.listMovementEvents(id);
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var rows = await cloud.listMovementEvents(id);
      if (localRows.isNotEmpty) {
        final cloudIds = rows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!cloudIds.contains(row.id)) {
            await cloud.appendMovementEvent(row);
          }
        }
        rows = await cloud.listMovementEvents(id);
      }
      _markCloud();
      for (final row in rows) {
        await _localStore.appendMovementEvent(row);
      }
      return rows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> appendMovementEvent(ToolPackageMovementEvent item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.appendMovementEvent(item);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    await _localStore.appendMovementEvent(item);
  }

  Future<List<ToolPackageNotification>> listNotifications() async {
    final cloud = _cloudRepository;
    final localRows = await _localStore.listNotifications();
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var rows = await cloud.listNotifications();
      if (localRows.isNotEmpty) {
        final cloudIds = rows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!cloudIds.contains(row.id)) {
            await cloud.saveNotification(row);
          }
        }
        rows = await cloud.listNotifications();
      }
      _markCloud();
      await _localStore.saveNotifications(rows);
      return rows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> saveNotification(ToolPackageNotification item) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.saveNotification(item);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final local = [...await _localStore.listNotifications()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveNotifications(local);
  }
}
