import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'partner_worker_master_models.dart';
import 'partner_worker_master_repository.dart';

/// Implementare Firestore pentru [PartnerWorkerMasterRepository] — pattern
/// identic cu `FirebaseAngajatiRepository`
/// (lib/features/employees/firebase_angajati_repository.dart).
class FirebasePartnerWorkerMasterRepository
    implements PartnerWorkerMasterRepository {
  FirebasePartnerWorkerMasterRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.partnerWorkersMaster);

  @override
  Future<void> deletePartnerWorkerMaster(String workerId) async {
    final id = workerId.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).delete();
  }

  @override
  Future<List<PartnerWorkerMaster>> listPartnerWorkerMasters() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => PartnerWorkerMaster.fromMap(_normalizeMap(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> upsertPartnerWorkerMaster(PartnerWorkerMaster worker) async {
    final id = worker.id.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).set(
      <String, dynamic>{
        ...worker.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Stream<List<PartnerWorkerMaster>> watchPartnerWorkerMasters() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
              (doc) => PartnerWorkerMaster.fromMap(_normalizeMap(doc.data())))
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
    });
  }

  Map<String, dynamic> _normalizeMap(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'partner_id': (raw['partner_id'] ?? raw['partnerId'] ?? '').toString(),
      'full_name': (raw['full_name'] ?? raw['fullName'] ?? '').toString(),
      'role': (raw['role'] ?? '').toString(),
      'active': raw['active'] ?? true,
      'notes': (raw['notes'] ?? '').toString(),
      'created_at': (raw['created_at'] ?? '').toString(),
      'updated_at': (raw['updated_at'] ?? '').toString(),
    };
  }
}
