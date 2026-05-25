import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'hr_payroll_input_cloud_repository.dart';
import 'hr_payroll_input_snapshot_models.dart';

class FirebaseHrPayrollInputRepository
    implements HrPayrollInputCloudRepository {
  FirebaseHrPayrollInputRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.hrPayrollInputSnapshots);

  @override
  Future<List<HrPayrollInputSnapshot>> listSnapshots() async {
    final snapshot = await _collection.get();
    final rows = snapshot.docs
        .map((doc) => HrPayrollInputSnapshot.fromMap(doc.data()))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) {
      final byMonth = b.payrollMonth.compareTo(a.payrollMonth);
      if (byMonth != 0) return byMonth;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return rows;
  }

  @override
  Future<void> upsertSnapshot(HrPayrollInputSnapshot item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).set(item.toMap(), SetOptions(merge: true));
  }
}
