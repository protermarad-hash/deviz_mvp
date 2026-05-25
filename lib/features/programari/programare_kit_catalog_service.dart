import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import 'firebase_programare_kit_repository.dart';
import 'local_programare_kit_store.dart';
import 'programare_kit_cloud_repository.dart';
import 'programare_kit_models.dart';

class ProgramareKitCatalogService {
  ProgramareKitCatalogService({
    ProgramareKitCloudRepository? cloudRepository,
    LocalProgramareKitStore? localStore,
  })  : _cloudRepository = cloudRepository ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseProgramareKitRepository()
                : null),
        _localStore = localStore ?? LocalProgramareKitStore();

  final ProgramareKitCloudRepository? _cloudRepository;
  final LocalProgramareKitStore _localStore;

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

  Future<List<AppointmentMaterialKitTemplate>> listTemplates() async {
    final cloud = _cloudRepository;
    final localRows = await _localStore.listTemplates();
    if (cloud == null) {
      _markLocalFallback();
      return localRows;
    }
    try {
      var cloudRows = await cloud.listTemplates();
      if (localRows.isNotEmpty) {
        final cloudIds = cloudRows.map((row) => row.id).toSet();
        for (final row in localRows) {
          if (!cloudIds.contains(row.id)) {
            await cloud.upsertTemplate(row);
          }
        }
        cloudRows = await cloud.listTemplates();
      }
      _markCloud();
      await _localStore.saveTemplates(cloudRows);
      return cloudRows;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      _markLocalFallback(error);
      return localRows;
    }
  }

  Future<void> upsertTemplate(AppointmentMaterialKitTemplate item) async {
    final cloud = _cloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.upsertTemplate(item);
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
      await OfflineSyncRuntime.instance.queueAppointmentMaterialKitUpsert(item);
    }
    final local = [...await _localStore.listTemplates()];
    final index = local.indexWhere((row) => row.id == item.id);
    if (index >= 0) {
      local[index] = item;
    } else {
      local.add(item);
    }
    await _localStore.saveTemplates(local);
  }

  Future<void> deleteTemplate(String templateId) async {
    final id = templateId.trim();
    if (id.isEmpty) return;
    final cloud = _cloudRepository;
    var queuedOffline = cloud == null;
    if (cloud != null) {
      try {
        await cloud.deleteTemplate(id);
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
      await OfflineSyncRuntime.instance.queueAppointmentMaterialKitDelete(id);
    }
    final local = await _localStore.listTemplates();
    final next = local.where((row) => row.id != id).toList(growable: false);
    await _localStore.saveTemplates(next);
  }
}
