import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'hr_leave_cloud_repository.dart';
import 'hr_leave_models.dart';

class FirebaseHrLeaveRepository implements HrLeaveCloudRepository {
  FirebaseHrLeaveRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _leaveTypesCollection =>
      _firestore.collection(FirebaseCollections.hrLeaveTypes);

  CollectionReference<Map<String, dynamic>> get _leaveRequestsCollection =>
      _firestore.collection(FirebaseCollections.hrLeaveRequests);

  @override
  Future<List<HrLeaveType>> listLeaveTypes() async {
    final snapshot = await _leaveTypesCollection.get();
    final rows = snapshot.docs
        .map((doc) => HrLeaveType.fromMap(_normalizeLeaveType(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return rows;
  }

  @override
  Future<List<HrLeaveRequest>> listLeaveRequests() async {
    final snapshot = await _leaveRequestsCollection.get();
    final rows = snapshot.docs
        .map(
          (doc) => HrLeaveRequest.fromMap(_normalizeLeaveRequest(doc.data())),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return rows;
  }

  @override
  Future<void> upsertLeaveType(HrLeaveType item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _leaveTypesCollection
        .doc(id)
        .set(item.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> upsertLeaveRequest(HrLeaveRequest item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _leaveRequestsCollection.doc(id).set(
          item.toMap(),
          SetOptions(merge: true),
        );
  }

  Map<String, dynamic> _normalizeLeaveType(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'code': (raw['code'] ?? '').toString(),
      'name': (raw['name'] ?? '').toString(),
      'category': (raw['category'] ?? '').toString(),
      'is_paid': raw['is_paid'] ?? raw['isPaid'] ?? false,
      'is_medical': raw['is_medical'] ?? raw['isMedical'] ?? false,
      'formula_type':
          (raw['formula_type'] ?? raw['formulaType'] ?? '').toString(),
      'requires_document':
          raw['requires_document'] ?? raw['requiresDocument'] ?? false,
      'is_active': raw['is_active'] ?? raw['isActive'] ?? true,
      'sort_order': raw['sort_order'] ?? raw['sortOrder'] ?? 0,
      'created_at': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
      'updated_at': (raw['updated_at'] ?? raw['updatedAt'] ?? '').toString(),
    };
  }

  Map<String, dynamic> _normalizeLeaveRequest(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'employee_id': (raw['employee_id'] ?? raw['employeeId'] ?? '').toString(),
      'hr_employee_profile_id':
          (raw['hr_employee_profile_id'] ?? raw['hrEmployeeProfileId'] ?? '')
              .toString(),
      'leave_type_code':
          (raw['leave_type_code'] ?? raw['leaveTypeCode'] ?? '').toString(),
      'start_date': (raw['start_date'] ?? raw['startDate'] ?? '').toString(),
      'end_date': (raw['end_date'] ?? raw['endDate'] ?? '').toString(),
      'calendar_days': raw['calendar_days'] ?? raw['calendarDays'] ?? 0,
      'working_days': raw['working_days'] ?? raw['workingDays'] ?? 0,
      'medical_code':
          (raw['medical_code'] ?? raw['medicalCode'] ?? '').toString(),
      'document_ref':
          (raw['document_ref'] ?? raw['documentRef'] ?? '').toString(),
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
