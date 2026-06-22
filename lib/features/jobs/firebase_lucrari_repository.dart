import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'job_models.dart';
import 'lucrari_cloud_repository.dart';

class FirebaseLucrariRepository implements LucrariCloudRepository {
  FirebaseLucrariRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.jobs);

  @override
  Future<void> deleteJob(String jobId) async {
    final id = jobId.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).delete();
  }

  @override
  Future<List<JobRecord>> listJobs() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => JobRecord.fromMap(_normalizeJobMap(doc.data())))
        .toList(growable: false);
  }

  @override
  Future<void> upsertJob(JobRecord job) async {
    final id = job.id.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).set(_jobToCloudMap(job), SetOptions(merge: true));
  }

  @override
  Stream<List<JobRecord>> watchJobs() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => JobRecord.fromMap(_normalizeJobMap(doc.data())))
          .toList(growable: false);
    });
  }

  Map<String, dynamic> _jobToCloudMap(JobRecord job) {
    return <String, dynamic>{
      'id': job.id,
      'job_code': job.jobCode,
      'client_id': job.clientId,
      'title': job.title,
      'location': job.location,
      'city': job.city,
      'county': job.county,
      'contact_person': job.contactPerson,
      'contact_phone': job.contactPhone,
      'client_department_id': job.clientDepartmentId,
      'client_department_name': job.clientDepartmentName,
      'contact_person_id': job.contactPersonId,
      'contact_person_email': job.contactPersonEmail,
      'description': job.description,
      'category': job.category,
      'status': job.status.value,
      'start_date': job.startDate?.toIso8601String(),
      'due_date': job.dueDate?.toIso8601String(),
      'closed_date': job.closedDate?.toIso8601String(),
      'estimated_value': job.estimatedValue,
      'notes': job.notes,
      'is_active': job.isActive,
      'created_at': job.createdAt.toIso8601String(),
      'updated_at': job.updatedAt.toIso8601String(),
      'materials': job.materials,
      'materials_updated_at': job.materialsUpdatedAt?.toIso8601String(),
      'details_updated_at': job.detailsUpdatedAt?.toIso8601String(),
      'assigned_team_id': job.assignedTeamId,
      'assigned_team_label': job.assignedTeamLabel,
      'assigned_team_members_label': job.assignedTeamMembersLabel,
      'documents': job.documents,
      'labor_entries': job.laborEntries,
      'journal_entries': job.journalEntries,
      'checklist': job.checklist,
      'work_task_entries': job.workTaskEntries,
      'job_partners': job.jobPartners,
      'job_partner_workers': job.jobPartnerWorkers,
      'job_partner_vehicles': job.jobPartnerVehicles,
      'job_own_vehicles': job.jobOwnVehicles,
      'time_entries': job.timeEntries,
      'profit_sharing_percent': job.profitSharingPercent,
      'beneficiary_supplied_equipment': job.beneficiarySuppliedEquipment
          .map((entry) => entry.toMap())
          .toList(growable: false),
      'beneficiary_supplied_materials': job.beneficiarySuppliedMaterials
          .map((entry) => entry.toMap())
          .toList(growable: false),
      'source_offer_id': job.sourceOfferId,
      'source_offer_number': job.sourceOfferNumber,
      'source_offer_title': job.sourceOfferTitle,
      'source_document_type': job.sourceDocumentType,
      'linii_planificate':
          job.liniiPlanificate.map((l) => l.toMap()).toList(growable: false),
      'created_by_user_id': job.createdByUserId,
      'created_by_user_email': job.createdByUserEmail,
      'partner_id': job.partnerId,
      'partner_name': job.partnerName,
      'partner_profit_percent': job.partnerProfitPercent,
      'partner_resources': job.partnerResources,
      'profit_tax_percent': job.profitTaxPercent,
    };
  }

  Map<String, dynamic> _normalizeJobMap(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'job_code': (raw['job_code'] ?? raw['jobCode'] ?? '').toString(),
      'client_id': (raw['client_id'] ?? raw['clientId'] ?? '').toString(),
      'title': (raw['title'] ?? '').toString(),
      'location': (raw['location'] ?? '').toString(),
      'city': (raw['city'] ?? '').toString(),
      'county': (raw['county'] ?? '').toString(),
      'contact_person':
          (raw['contact_person'] ?? raw['contactPerson'] ?? '').toString(),
      'contact_phone':
          (raw['contact_phone'] ?? raw['contactPhone'] ?? '').toString(),
      'client_department_id':
          (raw['client_department_id'] ?? raw['clientDepartmentId'] ?? '')
              .toString(),
      'client_department_name':
          (raw['client_department_name'] ?? raw['clientDepartmentName'] ?? '')
              .toString(),
      'contact_person_id':
          (raw['contact_person_id'] ?? raw['contactPersonId'] ?? '').toString(),
      'contact_person_email':
          (raw['contact_person_email'] ?? raw['contactPersonEmail'] ?? '')
              .toString(),
      'description': (raw['description'] ?? '').toString(),
      'category': (raw['category'] ?? '').toString(),
      'status': (raw['status'] ?? '').toString(),
      'start_date': (raw['start_date'] ?? raw['startDate'] ?? '').toString(),
      'due_date': (raw['due_date'] ?? raw['dueDate'] ?? '').toString(),
      'closed_date': (raw['closed_date'] ?? raw['closedDate'] ?? '').toString(),
      'estimated_value': raw['estimated_value'] ?? raw['estimatedValue'],
      'notes': (raw['notes'] ?? '').toString(),
      'is_active': raw['is_active'] ?? raw['isActive'] ?? true,
      'created_at': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
      'updated_at': (raw['updated_at'] ?? raw['updatedAt'] ?? '').toString(),
      'materials': raw['materials'] ?? raw['materialsSnapshot'] ?? const [],
      'materials_updated_at':
          (raw['materials_updated_at'] ?? raw['materialsUpdatedAt'] ?? '')
              .toString(),
      'details_updated_at':
          (raw['details_updated_at'] ?? raw['detailsUpdatedAt'] ?? '')
              .toString(),
      'assigned_team_id':
          (raw['assigned_team_id'] ?? raw['assignedTeamId'] ?? '').toString(),
      'assigned_team_label':
          (raw['assigned_team_label'] ?? raw['assignedTeamLabel'] ?? '')
              .toString(),
      'assigned_team_members_label': (raw['assigned_team_members_label'] ??
              raw['assignedTeamMembersLabel'] ??
              '')
          .toString(),
      'documents': raw['documents'] ?? const <dynamic>[],
      'labor_entries': raw['labor_entries'] ?? raw['laborEntries'] ?? const [],
      'journal_entries':
          raw['journal_entries'] ?? raw['journalEntries'] ?? const [],
      'checklist': raw['checklist'] ?? const <String, bool>{},
      'work_task_entries':
          raw['work_task_entries'] ?? raw['workTaskEntries'] ?? const [],
      'job_partners': raw['job_partners'] ?? raw['jobPartners'] ?? const [],
      'job_partner_workers':
          raw['job_partner_workers'] ?? raw['jobPartnerWorkers'] ?? const [],
      'job_partner_vehicles':
          raw['job_partner_vehicles'] ?? raw['jobPartnerVehicles'] ?? const [],
      'beneficiary_supplied_equipment': raw['beneficiary_supplied_equipment'] ??
          raw['beneficiarySuppliedEquipment'] ??
          const [],
      'beneficiary_supplied_materials': raw['beneficiary_supplied_materials'] ??
          raw['beneficiarySuppliedMaterials'] ??
          const [],
      'source_offer_id':
          (raw['source_offer_id'] ?? raw['sourceOfferId'] ?? '').toString(),
      'source_offer_number':
          (raw['source_offer_number'] ?? raw['sourceOfferNumber'] ?? '')
              .toString(),
      'source_offer_title':
          (raw['source_offer_title'] ?? raw['sourceOfferTitle'] ?? '')
              .toString(),
      'source_document_type':
          (raw['source_document_type'] ?? raw['sourceDocumentType'] ?? 'oferta')
              .toString(),
      'linii_planificate':
          raw['linii_planificate'] ?? raw['liniiPlanificate'] ?? const [],
      'job_own_vehicles':
          raw['job_own_vehicles'] ?? raw['jobOwnVehicles'] ?? const [],
      'time_entries': raw['time_entries'] ?? raw['timeEntries'] ?? const [],
      'profit_sharing_percent':
          raw['profit_sharing_percent'] ?? raw['profitSharingPercent'],
      'created_by_user_id':
          (raw['created_by_user_id'] ?? raw['createdByUserId'] ?? '')
              .toString(),
      'created_by_user_email':
          (raw['created_by_user_email'] ?? raw['createdByUserEmail'] ?? '')
              .toString(),
      'partner_id':
          (raw['partner_id'] ?? raw['partnerId'] ?? '').toString(),
      'partner_name':
          (raw['partner_name'] ?? raw['partnerName'] ?? '').toString(),
      'partner_profit_percent':
          raw['partner_profit_percent'] ?? raw['partnerProfitPercent'],
      'partner_resources':
          raw['partner_resources'] ?? raw['partnerResources'],
      'profit_tax_percent':
          raw['profit_tax_percent'] ?? raw['profitTaxPercent'],
    };
  }
}
