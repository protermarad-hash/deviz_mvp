import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import '../master/master_local_store.dart';
import 'angajati_cloud_repository.dart';

class FirebaseAngajatiRepository implements AngajatiCloudRepository {
  FirebaseAngajatiRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.employees);

  @override
  Future<void> deleteEmployee(String employeeId) async {
    final id = employeeId.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).delete();
  }

  @override
  Future<List<MasterEmployee>> listEmployees() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => MasterEmployee.fromMap(_normalizeMap(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> upsertEmployee(MasterEmployee employee) async {
    final id = employee.id.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).set(
      <String, dynamic>{
        ...employee.toMap(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Stream<List<MasterEmployee>> watchEmployees() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => MasterEmployee.fromMap(_normalizeMap(doc.data())))
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
    });
  }

  Map<String, dynamic> _normalizeMap(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'name': (raw['name'] ?? '').toString(),
      'role': (raw['role'] ?? '').toString(),
      'active': raw['active'] ?? true,
      'team_id': (raw['team_id'] ?? raw['teamId'] ?? '').toString(),
      'laborCostType':
          (raw['laborCostType'] ?? raw['labor_cost_type'] ?? 'orar').toString(),
      'costLunar': raw['costLunar'] ?? raw['cost_lunar'] ?? 0,
      'tarifOrar': raw['tarifOrar'] ?? raw['tarif_orar'] ?? 0,
      'oreLunareStandard':
          raw['oreLunareStandard'] ?? raw['ore_lunare_standard'] ?? 168,
      'dailyAllowance': raw['dailyAllowance'] ?? raw['daily_allowance'] ?? 0,
      'defaultLodgingCost':
          raw['defaultLodgingCost'] ?? raw['default_lodging_cost'] ?? 0,
      'requiresLodgingByDefault': raw['requiresLodgingByDefault'] ??
          raw['requires_lodging_by_default'] ??
          false,
    };
  }
}
