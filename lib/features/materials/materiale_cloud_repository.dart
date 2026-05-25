import '../master/master_local_store.dart';

abstract class MaterialeCloudRepository {
  Future<List<MasterMaterial>> listMaterials();
  Stream<List<MasterMaterial>> watchMaterials();
  Future<void> upsertMaterial(MasterMaterial material);
  Future<void> deleteMaterial(String materialId);
}
