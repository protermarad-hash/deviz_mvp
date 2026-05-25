import '../product_catalog/product_sales_models.dart';

class WarrantyInterventionReportRecord {
  const WarrantyInterventionReportRecord({
    required this.id,
    required this.complaintId,
    this.warrantyCertificateId = '',
    this.warrantyServiceTicketId = '',
    this.clientId = '',
    this.clientName = '',
    this.jobId = '',
    this.jobTitle = '',
    this.documentNumber = '',
    this.documentDate,
    this.warrantyCoverageStatus = WarrantyCoverageStatus.unknown,
    this.equipmentLabel = '',
    this.brand = '',
    this.model = '',
    this.serialNumberIndoor = '',
    this.serialNumberOutdoor = '',
    this.beneficiaryRepresentative = '',
    this.technicianName = '',
    this.teamName = '',
    this.findings = '',
    this.workPerformed = '',
    this.materialsUsedText = '',
    this.partsReplacedText = '',
    this.recommendations = '',
    this.resultStatus = '',
    this.clientSignatureBase64 = '',
    this.technicianSignatureBase64 = '',
    this.registryEntryId = '',
    this.documentType = 'warranty_intervention_report',
    this.sourceModule = 'reclamatii',
    this.generatedDocumentPath = '',
    this.generatedDocumentFileName = '',
    this.agfrEquipmentId = '',
    this.agfrInterventionId = '',
    this.agfrReportId = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String complaintId;
  final String warrantyCertificateId;
  final String warrantyServiceTicketId;
  final String clientId;
  final String clientName;
  final String jobId;
  final String jobTitle;
  final String documentNumber;
  final DateTime? documentDate;
  final WarrantyCoverageStatus warrantyCoverageStatus;
  final String equipmentLabel;
  final String brand;
  final String model;
  final String serialNumberIndoor;
  final String serialNumberOutdoor;
  final String beneficiaryRepresentative;
  final String technicianName;
  final String teamName;
  final String findings;
  final String workPerformed;
  final String materialsUsedText;
  final String partsReplacedText;
  final String recommendations;
  final String resultStatus;
  final String clientSignatureBase64;
  final String technicianSignatureBase64;
  final String registryEntryId;
  final String documentType;
  final String sourceModule;
  final String generatedDocumentPath;
  final String generatedDocumentFileName;
  final String agfrEquipmentId;
  final String agfrInterventionId;
  final String agfrReportId;
  final DateTime createdAt;
  final DateTime updatedAt;

  WarrantyInterventionReportRecord copyWith({
    String? id,
    String? complaintId,
    String? warrantyCertificateId,
    String? warrantyServiceTicketId,
    String? clientId,
    String? clientName,
    String? jobId,
    String? jobTitle,
    String? documentNumber,
    DateTime? documentDate,
    WarrantyCoverageStatus? warrantyCoverageStatus,
    String? equipmentLabel,
    String? brand,
    String? model,
    String? serialNumberIndoor,
    String? serialNumberOutdoor,
    String? beneficiaryRepresentative,
    String? technicianName,
    String? teamName,
    String? findings,
    String? workPerformed,
    String? materialsUsedText,
    String? partsReplacedText,
    String? recommendations,
    String? resultStatus,
    String? clientSignatureBase64,
    String? technicianSignatureBase64,
    String? registryEntryId,
    String? documentType,
    String? sourceModule,
    String? generatedDocumentPath,
    String? generatedDocumentFileName,
    String? agfrEquipmentId,
    String? agfrInterventionId,
    String? agfrReportId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WarrantyInterventionReportRecord(
      id: id ?? this.id,
      complaintId: complaintId ?? this.complaintId,
      warrantyCertificateId:
          warrantyCertificateId ?? this.warrantyCertificateId,
      warrantyServiceTicketId:
          warrantyServiceTicketId ?? this.warrantyServiceTicketId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      documentNumber: documentNumber ?? this.documentNumber,
      documentDate: documentDate ?? this.documentDate,
      warrantyCoverageStatus:
          warrantyCoverageStatus ?? this.warrantyCoverageStatus,
      equipmentLabel: equipmentLabel ?? this.equipmentLabel,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumberIndoor: serialNumberIndoor ?? this.serialNumberIndoor,
      serialNumberOutdoor: serialNumberOutdoor ?? this.serialNumberOutdoor,
      beneficiaryRepresentative:
          beneficiaryRepresentative ?? this.beneficiaryRepresentative,
      technicianName: technicianName ?? this.technicianName,
      teamName: teamName ?? this.teamName,
      findings: findings ?? this.findings,
      workPerformed: workPerformed ?? this.workPerformed,
      materialsUsedText: materialsUsedText ?? this.materialsUsedText,
      partsReplacedText: partsReplacedText ?? this.partsReplacedText,
      recommendations: recommendations ?? this.recommendations,
      resultStatus: resultStatus ?? this.resultStatus,
      clientSignatureBase64:
          clientSignatureBase64 ?? this.clientSignatureBase64,
      technicianSignatureBase64:
          technicianSignatureBase64 ?? this.technicianSignatureBase64,
      registryEntryId: registryEntryId ?? this.registryEntryId,
      documentType: documentType ?? this.documentType,
      sourceModule: sourceModule ?? this.sourceModule,
      generatedDocumentPath:
          generatedDocumentPath ?? this.generatedDocumentPath,
      generatedDocumentFileName:
          generatedDocumentFileName ?? this.generatedDocumentFileName,
      agfrEquipmentId: agfrEquipmentId ?? this.agfrEquipmentId,
      agfrInterventionId: agfrInterventionId ?? this.agfrInterventionId,
      agfrReportId: agfrReportId ?? this.agfrReportId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'complaint_id': complaintId,
      'warranty_certificate_id': warrantyCertificateId,
      'warranty_service_ticket_id': warrantyServiceTicketId,
      'client_id': clientId,
      'client_name': clientName,
      'job_id': jobId,
      'job_title': jobTitle,
      'document_number': documentNumber,
      'document_date': documentDate?.toIso8601String(),
      'warranty_coverage_status': warrantyCoverageStatus.value,
      'equipment_label': equipmentLabel,
      'brand': brand,
      'model': model,
      'serial_number_indoor': serialNumberIndoor,
      'serial_number_outdoor': serialNumberOutdoor,
      'beneficiary_representative': beneficiaryRepresentative,
      'technician_name': technicianName,
      'team_name': teamName,
      'findings': findings,
      'work_performed': workPerformed,
      'materials_used_text': materialsUsedText,
      'parts_replaced_text': partsReplacedText,
      'recommendations': recommendations,
      'result_status': resultStatus,
      'client_signature_base64': clientSignatureBase64,
      'technician_signature_base64': technicianSignatureBase64,
      'registry_entry_id': registryEntryId,
      'document_type': documentType,
      'source_module': sourceModule,
      'generated_document_path': generatedDocumentPath,
      'generated_document_file_name': generatedDocumentFileName,
      'agfr_equipment_id': agfrEquipmentId,
      'agfr_intervention_id': agfrInterventionId,
      'agfr_report_id': agfrReportId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory WarrantyInterventionReportRecord.fromMap(Map<String, dynamic> map) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    DateTime? parseNullableDate(List<String> keys) {
      for (final key in keys) {
        final raw = (map[key] ?? '').toString().trim();
        if (raw.isEmpty) {
          continue;
        }
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) {
          return parsed;
        }
      }
      return null;
    }

    final now = DateTime.now();
    return WarrantyInterventionReportRecord(
      id: pick(const <String>['id']),
      complaintId: pick(const <String>['complaint_id', 'complaintId']),
      warrantyCertificateId: pick(
        const <String>['warranty_certificate_id', 'warrantyCertificateId'],
      ),
      warrantyServiceTicketId: pick(
        const <String>['warranty_service_ticket_id', 'warrantyServiceTicketId'],
      ),
      clientId: pick(const <String>['client_id', 'clientId']),
      clientName: pick(const <String>['client_name', 'clientName']),
      jobId: pick(const <String>['job_id', 'jobId']),
      jobTitle: pick(const <String>['job_title', 'jobTitle']),
      documentNumber: pick(const <String>['document_number', 'documentNumber']),
      documentDate:
          parseNullableDate(const <String>['document_date', 'documentDate']),
      warrantyCoverageStatus: WarrantyCoverageStatus.values.firstWhere(
        (item) =>
            item.value ==
            pick(
              const <String>[
                'warranty_coverage_status',
                'warrantyCoverageStatus',
              ],
            ),
        orElse: () => WarrantyCoverageStatus.unknown,
      ),
      equipmentLabel: pick(const <String>['equipment_label', 'equipmentLabel']),
      brand: pick(const <String>['brand']),
      model: pick(const <String>['model']),
      serialNumberIndoor: pick(
        const <String>['serial_number_indoor', 'serialNumberIndoor'],
      ),
      serialNumberOutdoor: pick(
        const <String>['serial_number_outdoor', 'serialNumberOutdoor'],
      ),
      beneficiaryRepresentative: pick(
        const <String>[
          'beneficiary_representative',
          'beneficiaryRepresentative',
        ],
      ),
      technicianName: pick(const <String>['technician_name', 'technicianName']),
      teamName: pick(const <String>['team_name', 'teamName']),
      findings: pick(const <String>['findings']),
      workPerformed: pick(const <String>['work_performed', 'workPerformed']),
      materialsUsedText: pick(
        const <String>['materials_used_text', 'materialsUsedText'],
      ),
      partsReplacedText: pick(
        const <String>['parts_replaced_text', 'partsReplacedText'],
      ),
      recommendations: pick(const <String>['recommendations']),
      resultStatus: pick(const <String>['result_status', 'resultStatus']),
      clientSignatureBase64: pick(
        const <String>['client_signature_base64', 'clientSignatureBase64'],
      ),
      technicianSignatureBase64: pick(
        const <String>[
          'technician_signature_base64',
          'technicianSignatureBase64',
        ],
      ),
      registryEntryId:
          pick(const <String>['registry_entry_id', 'registryEntryId']),
      documentType: pick(const <String>['document_type', 'documentType']),
      sourceModule: pick(const <String>['source_module', 'sourceModule']),
      generatedDocumentPath: pick(
        const <String>['generated_document_path', 'generatedDocumentPath'],
      ),
      generatedDocumentFileName: pick(
        const <String>[
          'generated_document_file_name',
          'generatedDocumentFileName',
        ],
      ),
      agfrEquipmentId:
          pick(const <String>['agfr_equipment_id', 'agfrEquipmentId']),
      agfrInterventionId: pick(
        const <String>['agfr_intervention_id', 'agfrInterventionId'],
      ),
      agfrReportId: pick(const <String>['agfr_report_id', 'agfrReportId']),
      createdAt:
          parseNullableDate(const <String>['created_at', 'createdAt']) ?? now,
      updatedAt:
          parseNullableDate(const <String>['updated_at', 'updatedAt']) ?? now,
    );
  }
}
