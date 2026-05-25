enum RepairReportResolutionStatus {
  rezolvata,
  partialRezolvata,
  necesitaRevenire,
  nerezolvata;

  String get value {
    switch (this) {
      case RepairReportResolutionStatus.rezolvata:
        return 'rezolvata';
      case RepairReportResolutionStatus.partialRezolvata:
        return 'partial_rezolvata';
      case RepairReportResolutionStatus.necesitaRevenire:
        return 'necesita_revenire';
      case RepairReportResolutionStatus.nerezolvata:
        return 'nerezolvata';
    }
  }

  String get label {
    switch (this) {
      case RepairReportResolutionStatus.rezolvata:
        return 'Rezolvata';
      case RepairReportResolutionStatus.partialRezolvata:
        return 'Partial rezolvata';
      case RepairReportResolutionStatus.necesitaRevenire:
        return 'Necesita revenire';
      case RepairReportResolutionStatus.nerezolvata:
        return 'Nerezolvata';
    }
  }

  static RepairReportResolutionStatus fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return RepairReportResolutionStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => RepairReportResolutionStatus.rezolvata,
    );
  }
}

class RepairReportRecord {
  const RepairReportRecord({
    required this.id,
    required this.complaintId,
    required this.appointmentId,
    required this.interventionDate,
    required this.technicianName,
    required this.teamName,
    required this.beneficiaryName,
    required this.contractorName,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.location,
    required this.complaintDescription,
    required this.findings,
    required this.workPerformed,
    required this.materialsUsed,
    required this.recommendations,
    required this.resolutionStatus,
    required this.createdAt,
    required this.updatedAt,
    this.jobId = '',
    this.reportNumber = '',
    this.clientSignatureBase64 = '',
    this.technicianSignatureBase64 = '',
    this.pdfPath = '',
    this.equipmentType = '',
    this.equipmentBrand = '',
    this.equipmentModel = '',
    this.outdoorUnitSerial = '',
    this.indoorUnitSerials = '',
    this.equipmentDetails = '',
  });

  final String id;
  final String complaintId;
  final String appointmentId;
  final String jobId;
  final String reportNumber;
  final String clientSignatureBase64;
  final String technicianSignatureBase64;
  final String pdfPath;
  final String equipmentType;
  final String equipmentBrand;
  final String equipmentModel;
  final String outdoorUnitSerial;
  final String indoorUnitSerials;
  final String equipmentDetails;
  final DateTime interventionDate;
  final String technicianName;
  final String teamName;
  final String beneficiaryName;
  final String contractorName;
  final String contactPerson;
  final String phone;
  final String email;
  final String location;
  final String complaintDescription;
  final String findings;
  final String workPerformed;
  final String materialsUsed;
  final String recommendations;
  final RepairReportResolutionStatus resolutionStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  RepairReportRecord copyWith({
    String? id,
    String? complaintId,
    String? appointmentId,
    String? jobId,
    String? reportNumber,
    String? clientSignatureBase64,
    String? technicianSignatureBase64,
    String? pdfPath,
    String? equipmentType,
    String? equipmentBrand,
    String? equipmentModel,
    String? outdoorUnitSerial,
    String? indoorUnitSerials,
    String? equipmentDetails,
    DateTime? interventionDate,
    String? technicianName,
    String? teamName,
    String? beneficiaryName,
    String? contractorName,
    String? contactPerson,
    String? phone,
    String? email,
    String? location,
    String? complaintDescription,
    String? findings,
    String? workPerformed,
    String? materialsUsed,
    String? recommendations,
    RepairReportResolutionStatus? resolutionStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RepairReportRecord(
      id: id ?? this.id,
      complaintId: complaintId ?? this.complaintId,
      appointmentId: appointmentId ?? this.appointmentId,
      jobId: jobId ?? this.jobId,
      reportNumber: reportNumber ?? this.reportNumber,
      clientSignatureBase64:
          clientSignatureBase64 ?? this.clientSignatureBase64,
      technicianSignatureBase64:
          technicianSignatureBase64 ?? this.technicianSignatureBase64,
      pdfPath: pdfPath ?? this.pdfPath,
      equipmentType: equipmentType ?? this.equipmentType,
      equipmentBrand: equipmentBrand ?? this.equipmentBrand,
      equipmentModel: equipmentModel ?? this.equipmentModel,
      outdoorUnitSerial: outdoorUnitSerial ?? this.outdoorUnitSerial,
      indoorUnitSerials: indoorUnitSerials ?? this.indoorUnitSerials,
      equipmentDetails: equipmentDetails ?? this.equipmentDetails,
      interventionDate: interventionDate ?? this.interventionDate,
      technicianName: technicianName ?? this.technicianName,
      teamName: teamName ?? this.teamName,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      contractorName: contractorName ?? this.contractorName,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      location: location ?? this.location,
      complaintDescription: complaintDescription ?? this.complaintDescription,
      findings: findings ?? this.findings,
      workPerformed: workPerformed ?? this.workPerformed,
      materialsUsed: materialsUsed ?? this.materialsUsed,
      recommendations: recommendations ?? this.recommendations,
      resolutionStatus: resolutionStatus ?? this.resolutionStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'complaint_id': complaintId,
      'appointment_id': appointmentId,
      'job_id': jobId,
      'report_number': reportNumber,
      'client_signature_base64': clientSignatureBase64,
      'technician_signature_base64': technicianSignatureBase64,
      'pdf_path': pdfPath,
      'equipment_type': equipmentType,
      'equipment_brand': equipmentBrand,
      'equipment_model': equipmentModel,
      'outdoor_unit_serial': outdoorUnitSerial,
      'indoor_unit_serials': indoorUnitSerials,
      'equipment_details': equipmentDetails,
      'intervention_date': interventionDate.toIso8601String(),
      'technician_name': technicianName,
      'team_name': teamName,
      'beneficiary_name': beneficiaryName,
      'contractor_name': contractorName,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'location': location,
      'complaint_description': complaintDescription,
      'findings': findings,
      'work_performed': workPerformed,
      'materials_used': materialsUsed,
      'recommendations': recommendations,
      'resolution_status': resolutionStatus.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory RepairReportRecord.fromMap(Map<String, dynamic> map) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    DateTime parseDate(String key, DateTime fallback) {
      return DateTime.tryParse((map[key] ?? '').toString()) ?? fallback;
    }

    final now = DateTime.now();
    return RepairReportRecord(
      id: pick(const <String>['id']),
      complaintId: pick(const <String>['complaint_id', 'complaintId']),
      appointmentId: pick(const <String>['appointment_id', 'appointmentId']),
      jobId: pick(const <String>['job_id', 'jobId']),
      reportNumber: pick(const <String>['report_number', 'reportNumber']),
      clientSignatureBase64: pick(
        const <String>['client_signature_base64', 'clientSignatureBase64'],
      ),
      technicianSignatureBase64: pick(
        const <String>[
          'technician_signature_base64',
          'technicianSignatureBase64',
        ],
      ),
      pdfPath: pick(const <String>['pdf_path', 'pdfPath']),
      equipmentType: pick(const <String>['equipment_type', 'equipmentType']),
      equipmentBrand:
          pick(const <String>['equipment_brand', 'equipmentBrand']),
      equipmentModel:
          pick(const <String>['equipment_model', 'equipmentModel']),
      outdoorUnitSerial: pick(
        const <String>['outdoor_unit_serial', 'outdoorUnitSerial'],
      ),
      indoorUnitSerials: pick(
        const <String>['indoor_unit_serials', 'indoorUnitSerials'],
      ),
      equipmentDetails: pick(
        const <String>['equipment_details', 'equipmentDetails'],
      ),
      interventionDate: parseDate('intervention_date', now),
      technicianName: pick(const <String>['technician_name', 'technicianName']),
      teamName: pick(const <String>['team_name', 'teamName']),
      beneficiaryName:
          pick(const <String>['beneficiary_name', 'beneficiaryName']),
      contractorName:
          pick(const <String>['contractor_name', 'contractorName']),
      contactPerson: pick(const <String>['contact_person', 'contactPerson']),
      phone: pick(const <String>['phone']),
      email: pick(const <String>['email']),
      location: pick(const <String>['location']),
      complaintDescription: pick(
        const <String>['complaint_description', 'complaintDescription'],
      ),
      findings: pick(const <String>['findings', 'constatare']),
      workPerformed:
          pick(const <String>['work_performed', 'workPerformed']),
      materialsUsed: pick(const <String>['materials_used', 'materialsUsed']),
      recommendations:
          pick(const <String>['recommendations', 'observations']),
      resolutionStatus: RepairReportResolutionStatus.fromValue(
        pick(const <String>['resolution_status', 'resolutionStatus']),
      ),
      createdAt: parseDate('created_at', now),
      updatedAt: parseDate('updated_at', now),
    );
  }
}
