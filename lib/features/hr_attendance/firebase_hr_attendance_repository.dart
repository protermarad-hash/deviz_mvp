import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'hr_attendance_cloud_repository.dart';
import 'hr_attendance_models.dart';

class FirebaseHrAttendanceRepository implements HrAttendanceCloudRepository {
  FirebaseHrAttendanceRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.hrAttendanceEntries);

  @override
  Future<List<HrAttendanceEntry>> listEntries() async {
    final snapshot = await _collection.get();
    final rows = snapshot.docs
        .map((doc) => HrAttendanceEntry.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return rows;
  }

  @override
  Future<void> upsertEntry(HrAttendanceEntry item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).set(item.toMap(), SetOptions(merge: true));
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'employee_id': (raw['employee_id'] ?? raw['employeeId'] ?? '').toString(),
      'hr_employee_profile_id':
          (raw['hr_employee_profile_id'] ?? raw['hrEmployeeProfileId'] ?? '')
              .toString(),
      'date': (raw['date'] ?? '').toString(),
      'source_type': (raw['source_type'] ?? raw['sourceType'] ?? '').toString(),
      'source_ref_id':
          (raw['source_ref_id'] ?? raw['sourceRefId'] ?? '').toString(),
      'worked_hours': raw['worked_hours'] ?? raw['workedHours'] ?? 0,
      'overtime_hours': raw['overtime_hours'] ?? raw['overtimeHours'] ?? 0,
      'night_hours': raw['night_hours'] ?? raw['nightHours'] ?? 0,
      'leave_hours': raw['leave_hours'] ?? raw['leaveHours'] ?? 0,
      'job_id': (raw['job_id'] ?? raw['jobId'] ?? '').toString(),
      'appointment_id':
          (raw['appointment_id'] ?? raw['appointmentId'] ?? '').toString(),
      'team_id': (raw['team_id'] ?? raw['teamId'] ?? '').toString(),
      'status': (raw['status'] ?? 'draft').toString(),
      'submitted_at':
          (raw['submitted_at'] ?? raw['submittedAt'] ?? '').toString(),
      'submitted_by_user_id':
          (raw['submitted_by_user_id'] ?? raw['submittedByUserId'] ?? '')
              .toString(),
      'approved_at': (raw['approved_at'] ?? raw['approvedAt'] ?? '').toString(),
      'approved_by_user_id':
          (raw['approved_by_user_id'] ?? raw['approvedByUserId'] ?? '')
              .toString(),
      'reviewed_at': (raw['reviewed_at'] ?? raw['reviewedAt'] ?? '').toString(),
      'reviewed_by_user_id':
          (raw['reviewed_by_user_id'] ?? raw['reviewedByUserId'] ?? '')
              .toString(),
      'review_notes':
          (raw['review_notes'] ?? raw['reviewNotes'] ?? '').toString(),
      'notes': (raw['notes'] ?? '').toString(),
      'created_at': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
      'updated_at': (raw['updated_at'] ?? raw['updatedAt'] ?? '').toString(),
    };
  }
}
