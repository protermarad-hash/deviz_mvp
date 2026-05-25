import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/offline_sync_runtime.dart';
import '../master/master_local_store.dart';
import 'firebase_materiale_repository.dart';
import 'materiale_cloud_repository.dart';

class MaterialsCatalogService {
  MaterialsCatalogService({
    MaterialeCloudRepository? cloudRepository,
  }) : _cloudRepository = cloudRepository ??
            (FirebaseBootstrap.isInitialized
                ? FirebaseMaterialeRepository()
                : null);

  final MaterialeCloudRepository? _cloudRepository;

  String dataSourceLabel = 'local';
  String? fallbackReason;

  String _shortCloudError(Object error) {
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.isEmpty) return 'necunoscuta';
    return raw.length > 140 ? '${raw.substring(0, 140)}...' : raw;
  }

  Future<List<MasterMaterial>> listMaterials() async {
    await OfflineSyncRuntime.instance.syncPending();
    final cloud = _cloudRepository;
    if (cloud == null) {
      dataSourceLabel = 'local';
      return MasterLocalStore.readMaterials();
    }
    try {
      final cloudItems = await cloud.listMaterials();
      dataSourceLabel = 'cloud';
      fallbackReason = null;
      await MasterLocalStore.writeMaterials(cloudItems);
      return cloudItems;
    } catch (error) {
      FirebaseBootstrap.registerRuntimeError(error);
      fallbackReason = _shortCloudError(error);
      dataSourceLabel = 'local';
      return MasterLocalStore.readMaterials();
    }
  }

  Future<void> upsertMaterial(MasterMaterial material) async {
    var queuedOffline = false;
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.upsertMaterial(material);
        dataSourceLabel = 'cloud';
        fallbackReason = null;
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        fallbackReason = _shortCloudError(error);
        dataSourceLabel = 'local';
        queuedOffline = true;
      }
    } else {
      dataSourceLabel = 'local';
      queuedOffline = true;
    }
    final local = await MasterLocalStore.readMaterials();
    final index = local.indexWhere((item) => item.id == material.id);
    final next = [...local];
    if (index >= 0) {
      next[index] = material;
    } else {
      next.add(material);
    }
    await MasterLocalStore.writeMaterials(next);
    if (queuedOffline) {
      await OfflineSyncRuntime.instance.queueMaterial(material);
    }
  }

  Future<void> deleteMaterial(String materialId) async {
    final id = materialId.trim();
    if (id.isEmpty) return;
    var queuedOffline = false;
    final cloud = _cloudRepository;
    if (cloud != null) {
      try {
        await cloud.deleteMaterial(id);
        dataSourceLabel = 'cloud';
        fallbackReason = null;
      } catch (error) {
        FirebaseBootstrap.registerRuntimeError(error);
        fallbackReason = _shortCloudError(error);
        dataSourceLabel = 'local';
        queuedOffline = true;
      }
    } else {
      dataSourceLabel = 'local';
      queuedOffline = true;
    }
    final local = await MasterLocalStore.readMaterials();
    final next = local.where((item) => item.id != id).toList(growable: false);
    await MasterLocalStore.writeMaterials(next);
    if (queuedOffline) {
      await OfflineSyncRuntime.instance.queueMaterialDelete(id);
    }
  }

  Future<MasterMaterial> upsertFromOfferMaterial({
    required String name,
    required String unit,
    required double price,
    String notes = '',
  }) async {
    final local = await listMaterials();
    final normalizedName = _normalize(name);
    final normalizedUnit = _normalize(unit);
    final match = local.where((item) {
      return _normalize(item.name) == normalizedName &&
          _normalize(item.unit) == normalizedUnit;
    }).toList(growable: false);

    if (match.isNotEmpty) {
      final existing = match.first;
      final shouldUpdate = (price > 0 && existing.price != price) ||
          (notes.trim().isNotEmpty && existing.notes.trim().isEmpty);
      final updated = shouldUpdate
          ? MasterMaterial(
              id: existing.id,
              name: existing.name,
              unit: existing.unit,
              price: price > 0 ? price : existing.price,
              notes: notes.trim().isNotEmpty ? notes.trim() : existing.notes,
            )
          : existing;
      if (shouldUpdate) {
        await upsertMaterial(updated);
      }
      return updated;
    }

    final now = DateTime.now().microsecondsSinceEpoch;
    final created = MasterMaterial(
      id: 'mat-$now',
      name: name.trim(),
      unit: unit.trim(),
      price: price,
      notes: notes.trim(),
    );
    await upsertMaterial(created);
    return created;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<MasterMaterial> suggestByName(
    List<MasterMaterial> source,
    String query, {
    int minChars = 3,
    int maxItems = 12,
  }) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.length < minChars) {
      return const <MasterMaterial>[];
    }
    final startsWith = <MasterMaterial>[];
    final contains = <MasterMaterial>[];
    for (final item in source) {
      final normalizedName = _normalize(item.name);
      if (normalizedName.isEmpty) continue;
      if (normalizedName.startsWith(normalizedQuery)) {
        startsWith.add(item);
      } else if (normalizedName.contains(normalizedQuery)) {
        contains.add(item);
      }
    }
    final merged = <MasterMaterial>[...startsWith, ...contains];
    if (merged.length <= maxItems) {
      return merged;
    }
    return merged.take(maxItems).toList(growable: false);
  }
}
