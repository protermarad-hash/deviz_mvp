import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'hr_employee_cloud_repository.dart';
import 'hr_employee_models.dart';

class FirebaseHrEmployeeRepository implements HrEmployeeCloudRepository {
  FirebaseHrEmployeeRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _profilesCollection =>
      _firestore.collection(FirebaseCollections.hrEmployeeProfiles);

  CollectionReference<Map<String, dynamic>> get _contractsCollection =>
      _firestore.collection(FirebaseCollections.hrContracts);

  @override
  Future<List<HrEmployeeProfile>> listProfiles() async {
    final snapshot = await _profilesCollection.get();
    final rows = snapshot.docs
        .map((doc) => HrEmployeeProfile.fromMap(_normalizeProfile(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return rows;
  }

  @override
  Future<List<HrContract>> listContracts() async {
    final snapshot = await _contractsCollection.get();
    final rows = snapshot.docs
        .map((doc) => HrContract.fromMap(_normalizeContract(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    rows.sort((a, b) => b.startDate.compareTo(a.startDate));
    return rows;
  }

  @override
  Future<void> upsertProfile(HrEmployeeProfile item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _profilesCollection
        .doc(id)
        .set(item.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> upsertContract(HrContract item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    await _contractsCollection
        .doc(id)
        .set(item.toMap(), SetOptions(merge: true));
  }

  Map<String, dynamic> _normalizeProfile(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'employee_id': (raw['employee_id'] ?? raw['employeeId'] ?? '').toString(),
      'user_id': (raw['user_id'] ?? raw['userId'] ?? '').toString(),
      'full_name': (raw['full_name'] ?? raw['fullName'] ?? '').toString(),
      'team_id': (raw['team_id'] ?? raw['teamId'] ?? '').toString(),
      'is_active': raw['is_active'] ?? raw['isActive'] ?? true,
      'personal_numeric_code':
          (raw['personal_numeric_code'] ?? raw['personalNumericCode'] ?? '')
              .toString(),
      'tax_residence_country':
          (raw['tax_residence_country'] ?? raw['taxResidenceCountry'] ?? 'RO')
              .toString(),
      'bank_account':
          (raw['bank_account'] ?? raw['bankAccount'] ?? '').toString(),
      'notes': (raw['notes'] ?? '').toString(),
      'created_at': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
      'updated_at': (raw['updated_at'] ?? raw['updatedAt'] ?? '').toString(),
    };
  }

  Map<String, dynamic> _normalizeContract(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'hr_employee_profile_id':
          (raw['hr_employee_profile_id'] ?? raw['hrEmployeeProfileId'] ?? '')
              .toString(),
      'employee_id': (raw['employee_id'] ?? raw['employeeId'] ?? '').toString(),
      'contract_type':
          (raw['contract_type'] ?? raw['contractType'] ?? '').toString(),
      'job_title': (raw['job_title'] ?? raw['jobTitle'] ?? '').toString(),
      'employment_norm_hours_per_day': raw['employment_norm_hours_per_day'] ??
          raw['employmentNormHoursPerDay'] ??
          0,
      'employment_norm_hours_per_week': raw['employment_norm_hours_per_week'] ??
          raw['employmentNormHoursPerWeek'] ??
          0,
      'base_salary_gross':
          raw['base_salary_gross'] ?? raw['baseSalaryGross'] ?? 0,
      'currency': (raw['currency'] ?? 'RON').toString(),
      'start_date': (raw['start_date'] ?? raw['startDate'] ?? '').toString(),
      'end_date': (raw['end_date'] ?? raw['endDate'] ?? '').toString(),
      'is_childcare_leave':
          raw['is_childcare_leave'] ?? raw['isChildcareLeave'] ?? false,
      'childcare_leave_start_date':
          (raw['childcare_leave_start_date'] ??
                  raw['childcareLeaveStartDate'] ??
                  '')
              .toString(),
      'childcare_leave_end_date':
          (raw['childcare_leave_end_date'] ??
                  raw['childcareLeaveEndDate'] ??
                  '')
              .toString(),
      'status': (raw['status'] ?? 'active').toString(),
      'payroll_rule_jurisdiction': (raw['payroll_rule_jurisdiction'] ??
              raw['payrollRuleJurisdiction'] ??
              'RO')
          .toString(),
      'payroll_rule_scope_defaults': raw['payroll_rule_scope_defaults'] ??
          raw['payrollRuleScopeDefaults'] ??
          const <dynamic>[],
      'registry_entry_id':
          (raw['registry_entry_id'] ?? raw['registryEntryId'] ?? '').toString(),
      'registry_number':
          (raw['registry_number'] ?? raw['registryNumber'] ?? '').toString(),
      'registered_at':
          (raw['registered_at'] ?? raw['registeredAt'] ?? '').toString(),
      'created_at': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
      'updated_at': (raw['updated_at'] ?? raw['updatedAt'] ?? '').toString(),
    };
  }
}
