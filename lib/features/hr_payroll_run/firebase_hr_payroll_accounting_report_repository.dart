import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'hr_payroll_accounting_report_cloud_repository.dart';
import 'hr_payroll_accounting_report_models.dart';

class FirebaseHrPayrollAccountingReportRepository
    implements HrPayrollAccountingReportCloudRepository {
  FirebaseHrPayrollAccountingReportRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.hrPayrollAccountingReports);

  @override
  Future<List<HrPayrollAccountingReport>> listReports() async {
    final snapshot = await _collection.get();
    final rows = snapshot.docs
        .map(
          (doc) => HrPayrollAccountingReport.fromMap(
            Map<String, dynamic>.from(doc.data()),
          ),
        )
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
  Future<void> upsertReport(HrPayrollAccountingReport item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).set(item.toMap(), SetOptions(merge: true));
  }
}
