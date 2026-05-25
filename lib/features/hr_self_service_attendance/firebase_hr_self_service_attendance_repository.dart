import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'hr_self_service_attendance_cloud_repository.dart';
import 'hr_self_service_attendance_models.dart';

class FirebaseHrSelfServiceAttendanceRepository
    implements HrSelfServiceAttendanceCloudRepository {
  FirebaseHrSelfServiceAttendanceRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.hrSelfServiceAttendanceSessions);

  @override
  Future<List<HrSelfServiceAttendanceSession>> listSessions() async {
    final snapshot = await _collection.get();
    final rows = snapshot.docs
        .map((doc) => HrSelfServiceAttendanceSession.fromMap(_normalize(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rows;
  }

  @override
  Future<void> upsertSession(HrSelfServiceAttendanceSession item) async {
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
      'user_id': (raw['user_id'] ?? raw['userId'] ?? '').toString(),
      'date': (raw['date'] ?? '').toString(),
      'check_in_at': (raw['check_in_at'] ?? raw['checkInAt'] ?? '').toString(),
      'check_out_at':
          (raw['check_out_at'] ?? raw['checkOutAt'] ?? '').toString(),
      'break_start_at':
          (raw['break_start_at'] ?? raw['breakStartAt'] ?? '').toString(),
      'break_end_at':
          (raw['break_end_at'] ?? raw['breakEndAt'] ?? '').toString(),
      'location_type':
          (raw['location_type'] ?? raw['locationType'] ?? '').toString(),
      'job_id': (raw['job_id'] ?? raw['jobId'] ?? '').toString(),
      'appointment_id':
          (raw['appointment_id'] ?? raw['appointmentId'] ?? '').toString(),
      'notes': (raw['notes'] ?? '').toString(),
      'status': (raw['status'] ?? 'open').toString(),
      'created_at': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
      'updated_at': (raw['updated_at'] ?? raw['updatedAt'] ?? '').toString(),
    };
  }
}
