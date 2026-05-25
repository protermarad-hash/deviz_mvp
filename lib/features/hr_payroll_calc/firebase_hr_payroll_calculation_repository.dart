import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'hr_payroll_calculation_cloud_repository.dart';
import 'hr_payroll_calculation_models.dart';

class FirebaseHrPayrollCalculationRepository
    implements HrPayrollCalculationCloudRepository {
  FirebaseHrPayrollCalculationRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.hrPayrollCalculations);

  @override
  Future<List<HrPayrollCalculationResult>> listResults() async {
    final snapshot = await _collection.get();
    final rows = snapshot.docs
        .map(
          (doc) => HrPayrollCalculationResult.fromMap(
            _normalize(doc.data()),
          ),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) {
      final byMonth = b.payrollMonth.compareTo(a.payrollMonth);
      if (byMonth != 0) return byMonth;
      return b.calculatedAt.compareTo(a.calculatedAt);
    });
    return rows;
  }

  @override
  Future<void> upsertResult(HrPayrollCalculationResult item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).set(item.toMap(), SetOptions(merge: true));
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    return Map<String, dynamic>.from(raw);
  }
}
