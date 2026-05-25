class ComplaintClientCentralizerLine {
  const ComplaintClientCentralizerLine({
    required this.id,
    this.complaintId = '',
    this.complaintNumber = '',
    this.interventionDate,
    this.beneficiaryName = '',
    this.workSummary = '',
    this.offerId = '',
    this.offerNumber = '',
    this.offerValue = 0,
    this.repairReportId = '',
    this.repairReportNumber = '',
    this.warrantyReportId = '',
    this.warrantyReportNumber = '',
    this.includeInTotal = true,
  });

  final String id;
  final String complaintId;
  final String complaintNumber;
  final DateTime? interventionDate;
  final String beneficiaryName;
  final String workSummary;
  final String offerId;
  final String offerNumber;
  final double offerValue;
  final String repairReportId;
  final String repairReportNumber;
  final String warrantyReportId;
  final String warrantyReportNumber;
  final bool includeInTotal;

  ComplaintClientCentralizerLine copyWith({
    String? id,
    String? complaintId,
    String? complaintNumber,
    DateTime? interventionDate,
    String? beneficiaryName,
    String? workSummary,
    String? offerId,
    String? offerNumber,
    double? offerValue,
    String? repairReportId,
    String? repairReportNumber,
    String? warrantyReportId,
    String? warrantyReportNumber,
    bool? includeInTotal,
  }) {
    return ComplaintClientCentralizerLine(
      id: id ?? this.id,
      complaintId: complaintId ?? this.complaintId,
      complaintNumber: complaintNumber ?? this.complaintNumber,
      interventionDate: interventionDate ?? this.interventionDate,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      workSummary: workSummary ?? this.workSummary,
      offerId: offerId ?? this.offerId,
      offerNumber: offerNumber ?? this.offerNumber,
      offerValue: offerValue ?? this.offerValue,
      repairReportId: repairReportId ?? this.repairReportId,
      repairReportNumber: repairReportNumber ?? this.repairReportNumber,
      warrantyReportId: warrantyReportId ?? this.warrantyReportId,
      warrantyReportNumber: warrantyReportNumber ?? this.warrantyReportNumber,
      includeInTotal: includeInTotal ?? this.includeInTotal,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'complaint_id': complaintId,
      'complaint_number': complaintNumber,
      'intervention_date': interventionDate?.toIso8601String(),
      'beneficiary_name': beneficiaryName,
      'work_summary': workSummary,
      'offer_id': offerId,
      'offer_number': offerNumber,
      'offer_value': offerValue,
      'repair_report_id': repairReportId,
      'repair_report_number': repairReportNumber,
      'warranty_report_id': warrantyReportId,
      'warranty_report_number': warrantyReportNumber,
      'include_in_total': includeInTotal,
    };
  }

  factory ComplaintClientCentralizerLine.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }
      return double.tryParse((value ?? '').toString()) ?? 0;
    }

    return ComplaintClientCentralizerLine(
      id: (map['id'] ?? '').toString().trim(),
      complaintId:
          (map['complaint_id'] ?? map['complaintId'] ?? '').toString().trim(),
      complaintNumber: (map['complaint_number'] ?? map['complaintNumber'] ?? '')
          .toString()
          .trim(),
      interventionDate: DateTime.tryParse(
        (map['intervention_date'] ?? map['interventionDate'] ?? '').toString(),
      ),
      beneficiaryName: (map['beneficiary_name'] ?? map['beneficiaryName'] ?? '')
          .toString()
          .trim(),
      workSummary:
          (map['work_summary'] ?? map['workSummary'] ?? '').toString().trim(),
      offerId: (map['offer_id'] ?? map['offerId'] ?? '').toString().trim(),
      offerNumber:
          (map['offer_number'] ?? map['offerNumber'] ?? '').toString().trim(),
      offerValue: asDouble(map['offer_value'] ?? map['offerValue']),
      repairReportId: (map['repair_report_id'] ?? map['repairReportId'] ?? '')
          .toString()
          .trim(),
      repairReportNumber:
          (map['repair_report_number'] ?? map['repairReportNumber'] ?? '')
              .toString()
              .trim(),
      warrantyReportId:
          (map['warranty_report_id'] ?? map['warrantyReportId'] ?? '')
              .toString()
              .trim(),
      warrantyReportNumber:
          (map['warranty_report_number'] ?? map['warrantyReportNumber'] ?? '')
              .toString()
              .trim(),
      includeInTotal: map['include_in_total'] != false,
    );
  }
}

class ComplaintClientCentralizerRecord {
  const ComplaintClientCentralizerRecord({
    required this.id,
    required this.documentNumber,
    required this.clientId,
    required this.clientName,
    required this.periodStart,
    required this.periodEnd,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    this.summaryDescription = '',
    this.acceptancePerson = '',
    this.acceptanceRole = '',
    this.acceptanceDateText = '',
    this.acceptanceNotes = '',
    this.lines = const <ComplaintClientCentralizerLine>[],
    this.registryEntryId = '',
    this.generatedDocumentPath = '',
    this.generatedDocumentFileName = '',
  });

  final String id;
  final String documentNumber;
  final String clientId;
  final String clientName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String title;
  final String summaryDescription;
  final String acceptancePerson;
  final String acceptanceRole;
  final String acceptanceDateText;
  final String acceptanceNotes;
  final List<ComplaintClientCentralizerLine> lines;
  final String registryEntryId;
  final String generatedDocumentPath;
  final String generatedDocumentFileName;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get totalValue {
    return lines
        .where((line) => line.includeInTotal)
        .fold<double>(0, (sum, line) => sum + line.offerValue);
  }

  ComplaintClientCentralizerRecord copyWith({
    String? id,
    String? documentNumber,
    String? clientId,
    String? clientName,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? title,
    String? summaryDescription,
    String? acceptancePerson,
    String? acceptanceRole,
    String? acceptanceDateText,
    String? acceptanceNotes,
    List<ComplaintClientCentralizerLine>? lines,
    String? registryEntryId,
    String? generatedDocumentPath,
    String? generatedDocumentFileName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ComplaintClientCentralizerRecord(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      title: title ?? this.title,
      summaryDescription: summaryDescription ?? this.summaryDescription,
      acceptancePerson: acceptancePerson ?? this.acceptancePerson,
      acceptanceRole: acceptanceRole ?? this.acceptanceRole,
      acceptanceDateText: acceptanceDateText ?? this.acceptanceDateText,
      acceptanceNotes: acceptanceNotes ?? this.acceptanceNotes,
      lines: lines ?? this.lines,
      registryEntryId: registryEntryId ?? this.registryEntryId,
      generatedDocumentPath:
          generatedDocumentPath ?? this.generatedDocumentPath,
      generatedDocumentFileName:
          generatedDocumentFileName ?? this.generatedDocumentFileName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'document_number': documentNumber,
      'client_id': clientId,
      'client_name': clientName,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'title': title,
      'summary_description': summaryDescription,
      'acceptance_person': acceptancePerson,
      'acceptance_role': acceptanceRole,
      'acceptance_date_text': acceptanceDateText,
      'acceptance_notes': acceptanceNotes,
      'lines': lines.map((line) => line.toMap()).toList(growable: false),
      'registry_entry_id': registryEntryId,
      'generated_document_path': generatedDocumentPath,
      'generated_document_file_name': generatedDocumentFileName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ComplaintClientCentralizerRecord.fromMap(Map<String, dynamic> map) {
    List<ComplaintClientCentralizerLine> parseLines(dynamic raw) {
      if (raw is! List) {
        return const <ComplaintClientCentralizerLine>[];
      }
      return raw
          .whereType<Map>()
          .map(
            (item) => ComplaintClientCentralizerLine.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    }

    final now = DateTime.now();
    return ComplaintClientCentralizerRecord(
      id: (map['id'] ?? '').toString().trim(),
      documentNumber: (map['document_number'] ?? map['documentNumber'] ?? '')
          .toString()
          .trim(),
      clientId: (map['client_id'] ?? map['clientId'] ?? '').toString().trim(),
      clientName:
          (map['client_name'] ?? map['clientName'] ?? '').toString().trim(),
      periodStart: DateTime.tryParse(
            (map['period_start'] ?? map['periodStart'] ?? '').toString(),
          ) ??
          now,
      periodEnd: DateTime.tryParse(
            (map['period_end'] ?? map['periodEnd'] ?? '').toString(),
          ) ??
          now,
      title: (map['title'] ?? '').toString().trim(),
      summaryDescription:
          (map['summary_description'] ?? map['summaryDescription'] ?? '')
              .toString()
              .trim(),
      acceptancePerson:
          (map['acceptance_person'] ?? map['acceptancePerson'] ?? '')
              .toString()
              .trim(),
      acceptanceRole: (map['acceptance_role'] ?? map['acceptanceRole'] ?? '')
          .toString()
          .trim(),
      acceptanceDateText:
          (map['acceptance_date_text'] ?? map['acceptanceDateText'] ?? '')
              .toString()
              .trim(),
      acceptanceNotes: (map['acceptance_notes'] ?? map['acceptanceNotes'] ?? '')
          .toString()
          .trim(),
      lines: parseLines(map['lines']),
      registryEntryId:
          (map['registry_entry_id'] ?? map['registryEntryId'] ?? '')
              .toString()
              .trim(),
      generatedDocumentPath:
          (map['generated_document_path'] ?? map['generatedDocumentPath'] ?? '')
              .toString()
              .trim(),
      generatedDocumentFileName: (map['generated_document_file_name'] ??
              map['generatedDocumentFileName'] ??
              '')
          .toString()
          .trim(),
      createdAt: DateTime.tryParse(
            (map['created_at'] ?? map['createdAt'] ?? '').toString(),
          ) ??
          now,
      updatedAt: DateTime.tryParse(
            (map['updated_at'] ?? map['updatedAt'] ?? '').toString(),
          ) ??
          now,
    );
  }
}

class ComplaintWorkOrderLine {
  const ComplaintWorkOrderLine({
    required this.id,
    this.description = '',
    this.beneficiaryName = '',
    this.quantity = 1,
    this.unit = 'lucrare',
    this.unitPrice = 0,
  });

  final String id;
  final String description;
  final String beneficiaryName;
  final double quantity;
  final String unit;
  final double unitPrice;

  double get totalValue => quantity * unitPrice;

  ComplaintWorkOrderLine copyWith({
    String? id,
    String? description,
    String? beneficiaryName,
    double? quantity,
    String? unit,
    double? unitPrice,
  }) {
    return ComplaintWorkOrderLine(
      id: id ?? this.id,
      description: description ?? this.description,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'description': description,
      'beneficiary_name': beneficiaryName,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
    };
  }

  factory ComplaintWorkOrderLine.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic value, double fallback) {
      if (value is num) {
        return value.toDouble();
      }
      return double.tryParse((value ?? '').toString()) ?? fallback;
    }

    return ComplaintWorkOrderLine(
      id: (map['id'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString().trim(),
      beneficiaryName: (map['beneficiary_name'] ?? map['beneficiaryName'] ?? '')
          .toString()
          .trim(),
      quantity: asDouble(map['quantity'], 1),
      unit: (map['unit'] ?? '').toString().trim(),
      unitPrice: asDouble(map['unit_price'] ?? map['unitPrice'], 0),
    );
  }
}

class ComplaintWorkOrderRecord {
  const ComplaintWorkOrderRecord({
    required this.id,
    required this.documentNumber,
    required this.clientId,
    required this.clientName,
    required this.issueDate,
    required this.createdAt,
    required this.updatedAt,
    this.complaintId = '',
    this.centralizerId = '',
    this.beneficiaryName = '',
    this.requestedBy = '',
    this.requestedPhone = '',
    this.requestedEmail = '',
    this.location = '',
    this.subject = '',
    this.scopeOfWork = '',
    this.executionNotes = '',
    this.acceptancePerson = '',
    this.acceptanceRole = '',
    this.acceptanceDateText = '',
    this.acceptanceNotes = '',
    this.lines = const <ComplaintWorkOrderLine>[],
    this.registryEntryId = '',
    this.generatedDocumentPath = '',
    this.generatedDocumentFileName = '',
  });

  final String id;
  final String documentNumber;
  final String complaintId;
  final String centralizerId;
  final String clientId;
  final String clientName;
  final String beneficiaryName;
  final DateTime issueDate;
  final String requestedBy;
  final String requestedPhone;
  final String requestedEmail;
  final String location;
  final String subject;
  final String scopeOfWork;
  final String executionNotes;
  final String acceptancePerson;
  final String acceptanceRole;
  final String acceptanceDateText;
  final String acceptanceNotes;
  final List<ComplaintWorkOrderLine> lines;
  final String registryEntryId;
  final String generatedDocumentPath;
  final String generatedDocumentFileName;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get totalValue =>
      lines.fold<double>(0, (sum, line) => sum + line.totalValue);

  ComplaintWorkOrderRecord copyWith({
    String? id,
    String? documentNumber,
    String? complaintId,
    String? centralizerId,
    String? clientId,
    String? clientName,
    String? beneficiaryName,
    DateTime? issueDate,
    String? requestedBy,
    String? requestedPhone,
    String? requestedEmail,
    String? location,
    String? subject,
    String? scopeOfWork,
    String? executionNotes,
    String? acceptancePerson,
    String? acceptanceRole,
    String? acceptanceDateText,
    String? acceptanceNotes,
    List<ComplaintWorkOrderLine>? lines,
    String? registryEntryId,
    String? generatedDocumentPath,
    String? generatedDocumentFileName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ComplaintWorkOrderRecord(
      id: id ?? this.id,
      documentNumber: documentNumber ?? this.documentNumber,
      complaintId: complaintId ?? this.complaintId,
      centralizerId: centralizerId ?? this.centralizerId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      issueDate: issueDate ?? this.issueDate,
      requestedBy: requestedBy ?? this.requestedBy,
      requestedPhone: requestedPhone ?? this.requestedPhone,
      requestedEmail: requestedEmail ?? this.requestedEmail,
      location: location ?? this.location,
      subject: subject ?? this.subject,
      scopeOfWork: scopeOfWork ?? this.scopeOfWork,
      executionNotes: executionNotes ?? this.executionNotes,
      acceptancePerson: acceptancePerson ?? this.acceptancePerson,
      acceptanceRole: acceptanceRole ?? this.acceptanceRole,
      acceptanceDateText: acceptanceDateText ?? this.acceptanceDateText,
      acceptanceNotes: acceptanceNotes ?? this.acceptanceNotes,
      lines: lines ?? this.lines,
      registryEntryId: registryEntryId ?? this.registryEntryId,
      generatedDocumentPath:
          generatedDocumentPath ?? this.generatedDocumentPath,
      generatedDocumentFileName:
          generatedDocumentFileName ?? this.generatedDocumentFileName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'document_number': documentNumber,
      'complaint_id': complaintId,
      'centralizer_id': centralizerId,
      'client_id': clientId,
      'client_name': clientName,
      'beneficiary_name': beneficiaryName,
      'issue_date': issueDate.toIso8601String(),
      'requested_by': requestedBy,
      'requested_phone': requestedPhone,
      'requested_email': requestedEmail,
      'location': location,
      'subject': subject,
      'scope_of_work': scopeOfWork,
      'execution_notes': executionNotes,
      'acceptance_person': acceptancePerson,
      'acceptance_role': acceptanceRole,
      'acceptance_date_text': acceptanceDateText,
      'acceptance_notes': acceptanceNotes,
      'lines': lines.map((line) => line.toMap()).toList(growable: false),
      'registry_entry_id': registryEntryId,
      'generated_document_path': generatedDocumentPath,
      'generated_document_file_name': generatedDocumentFileName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ComplaintWorkOrderRecord.fromMap(Map<String, dynamic> map) {
    List<ComplaintWorkOrderLine> parseLines(dynamic raw) {
      if (raw is! List) {
        return const <ComplaintWorkOrderLine>[];
      }
      return raw
          .whereType<Map>()
          .map(
            (item) => ComplaintWorkOrderLine.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    }

    final now = DateTime.now();
    return ComplaintWorkOrderRecord(
      id: (map['id'] ?? '').toString().trim(),
      documentNumber: (map['document_number'] ?? map['documentNumber'] ?? '')
          .toString()
          .trim(),
      complaintId:
          (map['complaint_id'] ?? map['complaintId'] ?? '').toString().trim(),
      centralizerId: (map['centralizer_id'] ?? map['centralizerId'] ?? '')
          .toString()
          .trim(),
      clientId: (map['client_id'] ?? map['clientId'] ?? '').toString().trim(),
      clientName:
          (map['client_name'] ?? map['clientName'] ?? '').toString().trim(),
      beneficiaryName: (map['beneficiary_name'] ?? map['beneficiaryName'] ?? '')
          .toString()
          .trim(),
      issueDate: DateTime.tryParse(
            (map['issue_date'] ?? map['issueDate'] ?? '').toString(),
          ) ??
          now,
      requestedBy:
          (map['requested_by'] ?? map['requestedBy'] ?? '').toString().trim(),
      requestedPhone: (map['requested_phone'] ?? map['requestedPhone'] ?? '')
          .toString()
          .trim(),
      requestedEmail: (map['requested_email'] ?? map['requestedEmail'] ?? '')
          .toString()
          .trim(),
      location: (map['location'] ?? '').toString().trim(),
      subject: (map['subject'] ?? '').toString().trim(),
      scopeOfWork:
          (map['scope_of_work'] ?? map['scopeOfWork'] ?? '').toString().trim(),
      executionNotes: (map['execution_notes'] ?? map['executionNotes'] ?? '')
          .toString()
          .trim(),
      acceptancePerson:
          (map['acceptance_person'] ?? map['acceptancePerson'] ?? '')
              .toString()
              .trim(),
      acceptanceRole: (map['acceptance_role'] ?? map['acceptanceRole'] ?? '')
          .toString()
          .trim(),
      acceptanceDateText:
          (map['acceptance_date_text'] ?? map['acceptanceDateText'] ?? '')
              .toString()
              .trim(),
      acceptanceNotes: (map['acceptance_notes'] ?? map['acceptanceNotes'] ?? '')
          .toString()
          .trim(),
      lines: parseLines(map['lines']),
      registryEntryId:
          (map['registry_entry_id'] ?? map['registryEntryId'] ?? '')
              .toString()
              .trim(),
      generatedDocumentPath:
          (map['generated_document_path'] ?? map['generatedDocumentPath'] ?? '')
              .toString()
              .trim(),
      generatedDocumentFileName: (map['generated_document_file_name'] ??
              map['generatedDocumentFileName'] ??
              '')
          .toString()
          .trim(),
      createdAt: DateTime.tryParse(
            (map['created_at'] ?? map['createdAt'] ?? '').toString(),
          ) ??
          now,
      updatedAt: DateTime.tryParse(
            (map['updated_at'] ?? map['updatedAt'] ?? '').toString(),
          ) ??
          now,
    );
  }
}
