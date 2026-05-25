import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import '../master/master_local_store.dart';
import 'materiale_cloud_repository.dart';

class FirebaseMaterialeRepository implements MaterialeCloudRepository {
  FirebaseMaterialeRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.materials);

  @override
  Future<void> deleteMaterial(String materialId) async {
    final id = materialId.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).delete();
  }

  @override
  Future<List<MasterMaterial>> listMaterials() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => MasterMaterial.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> upsertMaterial(MasterMaterial material) async {
    final id = material.id.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).set(
          _toCloud(material),
          SetOptions(merge: true),
        );
  }

  @override
  Stream<List<MasterMaterial>> watchMaterials() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => MasterMaterial.fromMap(_normalize(doc.data())))
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
    });
  }

  Map<String, dynamic> _toCloud(MasterMaterial material) {
    return <String, dynamic>{
      'id': material.id,
      'name': material.name,
      'unit': material.unit,
      'price': material.price,
      'notes': material.notes,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'name': (raw['name'] ?? '').toString(),
      'unit': (raw['unit'] ?? '').toString(),
      'price': raw['price'] ?? 0,
      'notes': (raw['notes'] ?? '').toString(),
    };
  }
}
