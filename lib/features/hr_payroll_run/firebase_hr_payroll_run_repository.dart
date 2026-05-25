import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'hr_payroll_run_cloud_repository.dart';
import 'hr_payroll_run_models.dart';

class FirebaseHrPayrollRunRepository implements HrPayrollRunCloudRepository {
  FirebaseHrPayrollRunRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _runsCollection =>
      _firestore.collection(FirebaseCollections.hrPayrollRuns);

  CollectionReference<Map<String, dynamic>> get _payslipsCollection =>
      _firestore.collection(FirebaseCollections.hrPayslips);

  @override
  Future<List<HrPayrollRun>> listRuns() async {
    final snapshot = await _runsCollection.get();
    final rows = snapshot.docs
        .map((doc) => HrPayrollRun.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) {
      final byMonth = b.payrollMonth.compareTo(a.payrollMonth);
      if (byMonth != 0) return byMonth;
      return b.generatedAt.compareTo(a.generatedAt);
    });
    return rows;
  }

  @override
  Future<List<HrPayslip>> listPayslips() async {
    final snapshot = await _payslipsCollection.get();
    final rows = snapshot.docs
        .map((doc) => HrPayslip.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) {
      final byMonth = b.payrollMonth.compareTo(a.payrollMonth);
      if (byMonth != 0) return byMonth;
      return b.generatedAt.compareTo(a.generatedAt);
    });
    return rows;
  }

  @override
  Future<void> upsertRun(HrPayrollRun item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _runsCollection.doc(id).set(item.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> upsertPayslip(HrPayslip item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _payslipsCollection
        .doc(id)
        .set(item.toMap(), SetOptions(merge: true));
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    return Map<String, dynamic>.from(raw);
  }
}
