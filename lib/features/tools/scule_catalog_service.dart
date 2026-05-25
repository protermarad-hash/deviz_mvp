import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'firebase_scule_repository.dart';
import 'local_scule_store.dart';
import 'scule_cloud_repository.dart';
import 'scule_models.dart';

class SculeCatalogService {
  SculeCatalogService({
    SculeCloudRepository? cloudRepository,
    LocalSculeStore? localStore,
  })  : _cloudRepository = cloudRepository ??
            (FirebaseBootstrap.isInitialized ? FirebaseSculeRepository() : null),
        _localStore = localStore ?? LocalSculeStore();

  final SculeCloudRepository? _cloudRepository;
  final LocalSculeStore _localStore;

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

  Future<List<ToolInventoryItem>> listTools() async {
    final cloud = _cloudRepository;
    final localRows = await _localStore.listTools();
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listTools();
      if (localRows.isNotEmpty) {
        final cloudIds = cloudRows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!cloudIds.contains(row.id)) {
            await cloud.upsertTool(row);
          }
        }
        cloudRows = await cloud.listTools();
      }
      _markCloud();
      await _localStore.saveTools(cloudRows);
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> upsertTool(ToolInventoryItem item) async {
    final cloud = _cloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.upsertTool(item);
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
      await OfflineSyncRuntime.instance.queueToolUpsert(item);
    }
    final local = [...await _localStore.listTools()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveTools(local);
  }

  Future<void> deleteTool(String toolId) async {
    final id = toolId.trim();
    if (id.isEmpty) return;
    final cloud = _cloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.deleteTool(id);
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
      await OfflineSyncRuntime.instance.queueToolDelete(id);
    }
    final local = await _localStore.listTools();
    final next = local.where((row) => row.id != id).toList(growable: false);
    await _localStore.saveTools(next);
  }

  Future<List<ToolMovementEvent>> listMovementEvents(String toolId) async {
    final id = toolId.trim();
    if (id.isEmpty) return const <ToolMovementEvent>[];
    final cloud = _cloudRepository;
    final localRows = await _localStore.listMovementEvents(id);
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listMovementEvents(id);
      if (localRows.isNotEmpty) {
        final cloudIds = cloudRows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!cloudIds.contains(row.id)) {
            await cloud.appendMovementEvent(row);
          }
        }
        cloudRows = await cloud.listMovementEvents(id);
      }
      _markCloud();
      for (final row in cloudRows) {
        await _localStore.appendMovementEvent(row);
      }
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> appendMovementEvent(ToolMovementEvent event) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.appendMovementEvent(event);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    await _localStore.appendMovementEvent(event);
  }

  Future<List<ToolHandoverDocument>> listHandoverDocuments() async {
    final cloud = _cloudRepository;
    final localRows = await _localStore.listHandoverDocuments();
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listHandoverDocuments();
      if (localRows.isNotEmpty) {
        final cloudIds = cloudRows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!cloudIds.contains(row.id)) {
            await cloud.saveHandoverDocument(row);
          }
        }
        cloudRows = await cloud.listHandoverDocuments();
      }
      _markCloud();
      await _localStore.saveHandoverDocuments(cloudRows);
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> saveHandoverDocument(ToolHandoverDocument item) async {
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

  Future<List<String>> listToolCategories() async {
    final cloud = _cloudRepository;
    final localRows = await _localStore.listToolCategories();
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listToolCategories();
      if (localRows.isNotEmpty) {
        final normalizedCloud =
            cloudRows.map((item) => item.trim().toLowerCase()).toSet();
        for (final row in localRows) {
          if (!normalizedCloud.contains(row.trim().toLowerCase())) {
            await cloud.saveToolCategory(row);
          }
        }
        cloudRows = await cloud.listToolCategories();
      }
      _markCloud();
      await _localStore.saveToolCategories(cloudRows);
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> saveToolCategory(String category) async {
    final normalized = category.trim();
    if (normalized.isEmpty) return;
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.saveToolCategory(normalized);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final existing = await _localStore.listToolCategories();
    if (existing.any((item) => item.toLowerCase() == normalized.toLowerCase())) {
      return;
    }
    final next = [...existing, normalized];
    await _localStore.saveToolCategories(next);
  }

  Future<List<ToolTransferRequest>> listTransferRequests() async {
    final cloud = _cloudRepository;
    final localRows = await _localStore.listTransferRequests();
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listTransferRequests();
      if (localRows.isNotEmpty) {
        final cloudIds = cloudRows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!cloudIds.contains(row.id)) {
            await cloud.saveTransferRequest(row);
          }
        }
        cloudRows = await cloud.listTransferRequests();
      }
      _markCloud();
      await _localStore.saveTransferRequests(cloudRows);
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> saveTransferRequest(ToolTransferRequest request) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.saveTransferRequest(request);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final local = [...await _localStore.listTransferRequests()];
    final index = local.indexWhere((row) => row.id == request.id);
    if (index >= 0) {
      local[index] = request;
    } else {
      local.add(request);
    }
    await _localStore.saveTransferRequests(local);
  }

  Future<List<ToolTransferNotification>> listTransferNotifications() async {
    final cloud = _cloudRepository;
    final localRows = await _localStore.listTransferNotifications();
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listTransferNotifications();
      if (localRows.isNotEmpty) {
        final cloudIds = cloudRows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!cloudIds.contains(row.id)) {
            await cloud.saveTransferNotification(row);
          }
        }
        cloudRows = await cloud.listTransferNotifications();
      }
      _markCloud();
      await _localStore.saveTransferNotifications(cloudRows);
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> saveTransferNotification(ToolTransferNotification notification) async {
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.saveTransferNotification(notification);
        _markCloud();
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        _markLocalFallback(error);
      }
    } else {
      _markLocalFallback();
    }
    final local = [...await _localStore.listTransferNotifications()];
    final index = local.indexWhere((row) => row.id == notification.id);
    if (index >= 0) {
      local[index] = notification;
    } else {
      local.add(notification);
    }
    await _localStore.saveTransferNotifications(local);
  }
}
