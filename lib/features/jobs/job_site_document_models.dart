enum JobSiteDocumentType {
  montajExecutie,
  pifVentilatieRecuperator,
  pifVrfClimatizare;

  String get storageValue {
    switch (this) {
      case JobSiteDocumentType.montajExecutie:
        return 'pv_montaj_executie';
      case JobSiteDocumentType.pifVentilatieRecuperator:
        return 'pv_pif_ventilatie_recuperator';
      case JobSiteDocumentType.pifVrfClimatizare:
        return 'pv_pif_vrf_climatizare';
    }
  }

  String get label {
    switch (this) {
      case JobSiteDocumentType.montajExecutie:
        return 'PV montaj / executie lucrari';
      case JobSiteDocumentType.pifVentilatieRecuperator:
        return 'PV PIF ventilatie / recuperator';
      case JobSiteDocumentType.pifVrfClimatizare:
        return 'PV PIF VRF / climatizare';
    }
  }

  String get registryCategory {
    switch (this) {
      case JobSiteDocumentType.montajExecutie:
        return 'PV montaj executie lucrari';
      case JobSiteDocumentType.pifVentilatieRecuperator:
        return 'PV PIF ventilatie recuperator';
      case JobSiteDocumentType.pifVrfClimatizare:
        return 'PV PIF VRF climatizare';
    }
  }

  String get shortCode {
    switch (this) {
      case JobSiteDocumentType.montajExecutie:
        return 'PVM';
      case JobSiteDocumentType.pifVentilatieRecuperator:
        return 'PIFV';
      case JobSiteDocumentType.pifVrfClimatizare:
        return 'PIFVRF';
    }
  }

  static JobSiteDocumentType fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final item in JobSiteDocumentType.values) {
      if (item.storageValue == normalized) return item;
    }
    return JobSiteDocumentType.montajExecutie;
  }
}

class JobSiteDocumentCheckItem {
  const JobSiteDocumentCheckItem({
    required this.id,
    required this.sectionKey,
    required this.label,
    this.value = false,
    this.notes = '',
  });

  final String id;
  final String sectionKey;
  final String label;
  final bool value;
  final String notes;

  JobSiteDocumentCheckItem copyWith({
    String? id,
    String? sectionKey,
    String? label,
    bool? value,
    String? notes,
  }) {
    return JobSiteDocumentCheckItem(
      id: id ?? this.id,
      sectionKey: sectionKey ?? this.sectionKey,
      label: label ?? this.label,
      value: value ?? this.value,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'section_key': sectionKey,
        'label': label,
        'value': value,
        'notes': notes,
      };

  factory JobSiteDocumentCheckItem.fromMap(Map<String, dynamic> map) {
    return JobSiteDocumentCheckItem(
      id: (map['id'] ?? '').toString().trim(),
      sectionKey: (map['section_key'] ?? map['sectionKey'] ?? '')
          .toString()
          .trim(),
      label: (map['label'] ?? '').toString().trim(),
      value: map['value'] == true,
      notes: (map['notes'] ?? '').toString().trim(),
    );
  }
}

class JobSiteDocumentMeasurement {
  const JobSiteDocumentMeasurement({
    required this.id,
    required this.sectionKey,
    required this.label,
    this.value = '',
    this.unit = '',
    this.notes = '',
  });

  final String id;
  final String sectionKey;
  final String label;
  final String value;
  final String unit;
  final String notes;

  JobSiteDocumentMeasurement copyWith({
    String? id,
    String? sectionKey,
    String? label,
    String? value,
    String? unit,
    String? notes,
  }) {
    return JobSiteDocumentMeasurement(
      id: id ?? this.id,
      sectionKey: sectionKey ?? this.sectionKey,
      label: label ?? this.label,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'section_key': sectionKey,
        'label': label,
        'value': value,
        'unit': unit,
        'notes': notes,
      };

  factory JobSiteDocumentMeasurement.fromMap(Map<String, dynamic> map) {
    return JobSiteDocumentMeasurement(
      id: (map['id'] ?? '').toString().trim(),
      sectionKey: (map['section_key'] ?? map['sectionKey'] ?? '')
          .toString()
          .trim(),
      label: (map['label'] ?? '').toString().trim(),
      value: (map['value'] ?? '').toString().trim(),
      unit: (map['unit'] ?? '').toString().trim(),
      notes: (map['notes'] ?? '').toString().trim(),
    );
  }
}

class JobSiteDocumentAnnexItem {
  const JobSiteDocumentAnnexItem({
    required this.id,
    required this.label,
    this.quantity = '',
    this.unit = '',
    this.details = '',
    this.source = '',
  });

  final String id;
  final String label;
  final String quantity;
  final String unit;
  final String details;
  final String source;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'label': label,
        'quantity': quantity,
        'unit': unit,
        'details': details,
        'source': source,
      };

  factory JobSiteDocumentAnnexItem.fromMap(Map<String, dynamic> map) {
    return JobSiteDocumentAnnexItem(
      id: (map['id'] ?? '').toString().trim(),
      label: (map['label'] ?? '').toString().trim(),
      quantity: (map['quantity'] ?? '').toString().trim(),
      unit: (map['unit'] ?? '').toString().trim(),
      details: (map['details'] ?? '').toString().trim(),
      source: (map['source'] ?? '').toString().trim(),
    );
  }
}

class JobSiteDocumentAnnex {
  const JobSiteDocumentAnnex({
    required this.key,
    required this.title,
    this.description = '',
    this.summary = '',
    this.items = const <JobSiteDocumentAnnexItem>[],
  });

  final String key;
  final String title;
  final String description;
  final String summary;
  final List<JobSiteDocumentAnnexItem> items;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'key': key,
        'title': title,
        'description': description,
        'summary': summary,
        'items': items.map((item) => item.toMap()).toList(growable: false),
      };

  factory JobSiteDocumentAnnex.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    return JobSiteDocumentAnnex(
      key: (map['key'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString().trim(),
      summary: (map['summary'] ?? '').toString().trim(),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => JobSiteDocumentAnnexItem.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const <JobSiteDocumentAnnexItem>[],
    );
  }
}

class JobSiteDocumentRecord {
  const JobSiteDocumentRecord({
    required this.id,
    required this.jobId,
    required this.documentType,
    required this.documentTitle,
    required this.documentSubtitle,
    required this.documentNumber,
    required this.documentDate,
    required this.beneficiaryRepresentative,
    required this.executorRepresentative,
    required this.projectName,
    required this.location,
    required this.observations,
    required this.conclusions,
    required this.clientSignatureBase64,
    required this.executorSignatureBase64,
    required this.registryEntryId,
    required this.documentTypeForRegistry,
    required this.sourceModule,
    required this.generatedDocumentPath,
    required this.generatedDocumentFileName,
    required this.createdAt,
    required this.updatedAt,
    this.status = 'draft',
    this.functionalStatus = '',
    this.measurements = const <JobSiteDocumentMeasurement>[],
    this.checkItems = const <JobSiteDocumentCheckItem>[],
    this.annexes = const <JobSiteDocumentAnnex>[],
    this.probesSummary = '',
    this.remediationDeadline,
    this.trainingProvided = false,
    this.preparedForNextStep = '',
  });

  final String id;
  final String jobId;
  final JobSiteDocumentType documentType;
  final String documentTitle;
  final String documentSubtitle;
  final String documentNumber;
  final DateTime documentDate;
  final String beneficiaryRepresentative;
  final String executorRepresentative;
  final String projectName;
  final String location;
  final String observations;
  final String conclusions;
  final String clientSignatureBase64;
  final String executorSignatureBase64;
  final String registryEntryId;
  final String documentTypeForRegistry;
  final String sourceModule;
  final String generatedDocumentPath;
  final String generatedDocumentFileName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final String functionalStatus;
  final List<JobSiteDocumentMeasurement> measurements;
  final List<JobSiteDocumentCheckItem> checkItems;
  final List<JobSiteDocumentAnnex> annexes;
  final String probesSummary;
  final DateTime? remediationDeadline;
  final bool trainingProvided;
  final String preparedForNextStep;

  JobSiteDocumentRecord copyWith({
    String? id,
    String? jobId,
    JobSiteDocumentType? documentType,
    String? documentTitle,
    String? documentSubtitle,
    String? documentNumber,
    DateTime? documentDate,
    String? beneficiaryRepresentative,
    String? executorRepresentative,
    String? projectName,
    String? location,
    String? observations,
    String? conclusions,
    String? clientSignatureBase64,
    String? executorSignatureBase64,
    String? registryEntryId,
    String? documentTypeForRegistry,
    String? sourceModule,
    String? generatedDocumentPath,
    String? generatedDocumentFileName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? functionalStatus,
    List<JobSiteDocumentMeasurement>? measurements,
    List<JobSiteDocumentCheckItem>? checkItems,
    List<JobSiteDocumentAnnex>? annexes,
    String? probesSummary,
    DateTime? remediationDeadline,
    bool? trainingProvided,
    String? preparedForNextStep,
  }) {
    return JobSiteDocumentRecord(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      documentType: documentType ?? this.documentType,
      documentTitle: documentTitle ?? this.documentTitle,
      documentSubtitle: documentSubtitle ?? this.documentSubtitle,
      documentNumber: documentNumber ?? this.documentNumber,
      documentDate: documentDate ?? this.documentDate,
      beneficiaryRepresentative:
          beneficiaryRepresentative ?? this.beneficiaryRepresentative,
      executorRepresentative:
          executorRepresentative ?? this.executorRepresentative,
      projectName: projectName ?? this.projectName,
      location: location ?? this.location,
      observations: observations ?? this.observations,
      conclusions: conclusions ?? this.conclusions,
      clientSignatureBase64:
          clientSignatureBase64 ?? this.clientSignatureBase64,
      executorSignatureBase64:
          executorSignatureBase64 ?? this.executorSignatureBase64,
      registryEntryId: registryEntryId ?? this.registryEntryId,
      documentTypeForRegistry:
          documentTypeForRegistry ?? this.documentTypeForRegistry,
      sourceModule: sourceModule ?? this.sourceModule,
      generatedDocumentPath: generatedDocumentPath ?? this.generatedDocumentPath,
      generatedDocumentFileName:
          generatedDocumentFileName ?? this.generatedDocumentFileName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      functionalStatus: functionalStatus ?? this.functionalStatus,
      measurements: measurements ?? this.measurements,
      checkItems: checkItems ?? this.checkItems,
      annexes: annexes ?? this.annexes,
      probesSummary: probesSummary ?? this.probesSummary,
      remediationDeadline: remediationDeadline ?? this.remediationDeadline,
      trainingProvided: trainingProvided ?? this.trainingProvided,
      preparedForNextStep: preparedForNextStep ?? this.preparedForNextStep,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'job_id': jobId,
        'document_type': documentType.storageValue,
        'document_title': documentTitle,
        'document_subtitle': documentSubtitle,
        'document_number': documentNumber,
        'document_date': documentDate.toIso8601String(),
        'beneficiary_representative': beneficiaryRepresentative,
        'executor_representative': executorRepresentative,
        'project_name': projectName,
        'location': location,
        'observations': observations,
        'conclusions': conclusions,
        'client_signature_base64': clientSignatureBase64,
        'executor_signature_base64': executorSignatureBase64,
        'registry_entry_id': registryEntryId,
        'document_type_for_registry': documentTypeForRegistry,
        'source_module': sourceModule,
        'generated_document_path': generatedDocumentPath,
        'generated_document_file_name': generatedDocumentFileName,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'status': status,
        'functional_status': functionalStatus,
        'measurements':
            measurements.map((item) => item.toMap()).toList(growable: false),
        'check_items':
            checkItems.map((item) => item.toMap()).toList(growable: false),
        'annexes': annexes.map((item) => item.toMap()).toList(growable: false),
        'probes_summary': probesSummary,
        'remediation_deadline': remediationDeadline?.toIso8601String(),
        'training_provided': trainingProvided,
        'prepared_for_next_step': preparedForNextStep,
      };

  factory JobSiteDocumentRecord.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw, DateTime fallback) {
      final value = DateTime.tryParse((raw ?? '').toString());
      return value ?? fallback;
    }

    DateTime? parseOptionalDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    List<T> parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic> map) parser,
    ) {
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map>()
          .map((item) => parser(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    final now = DateTime.now();
    return JobSiteDocumentRecord(
      id: (map['id'] ?? '').toString().trim(),
      jobId: (map['job_id'] ?? map['jobId'] ?? '').toString().trim(),
      documentType:
          JobSiteDocumentType.fromValue(map['document_type'] ?? map['documentType']),
      documentTitle:
          (map['document_title'] ?? map['documentTitle'] ?? '').toString().trim(),
      documentSubtitle: (map['document_subtitle'] ?? map['documentSubtitle'] ?? '')
          .toString()
          .trim(),
      documentNumber:
          (map['document_number'] ?? map['documentNumber'] ?? '').toString().trim(),
      documentDate:
          parseDate(map['document_date'] ?? map['documentDate'], now),
      beneficiaryRepresentative: (map['beneficiary_representative'] ??
              map['beneficiaryRepresentative'] ??
              '')
          .toString()
          .trim(),
      executorRepresentative: (map['executor_representative'] ??
              map['executorRepresentative'] ??
              '')
          .toString()
          .trim(),
      projectName:
          (map['project_name'] ?? map['projectName'] ?? '').toString().trim(),
      location: (map['location'] ?? '').toString().trim(),
      observations: (map['observations'] ?? '').toString().trim(),
      conclusions: (map['conclusions'] ?? '').toString().trim(),
      clientSignatureBase64: (map['client_signature_base64'] ??
              map['clientSignatureBase64'] ??
              '')
          .toString()
          .trim(),
      executorSignatureBase64: (map['executor_signature_base64'] ??
              map['executorSignatureBase64'] ??
              '')
          .toString()
          .trim(),
      registryEntryId:
          (map['registry_entry_id'] ?? map['registryEntryId'] ?? '')
              .toString()
              .trim(),
      documentTypeForRegistry: (map['document_type_for_registry'] ??
              map['documentTypeForRegistry'] ??
              '')
          .toString()
          .trim(),
      sourceModule:
          (map['source_module'] ?? map['sourceModule'] ?? 'lucrari')
              .toString()
              .trim(),
      generatedDocumentPath: (map['generated_document_path'] ??
              map['generatedDocumentPath'] ??
              '')
          .toString()
          .trim(),
      generatedDocumentFileName: (map['generated_document_file_name'] ??
              map['generatedDocumentFileName'] ??
              '')
          .toString()
          .trim(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt'], now),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt'], now),
      status: (map['status'] ?? 'draft').toString().trim(),
      functionalStatus:
          (map['functional_status'] ?? map['functionalStatus'] ?? '')
              .toString()
              .trim(),
      measurements: parseList(
        map['measurements'],
        JobSiteDocumentMeasurement.fromMap,
      ),
      checkItems: parseList(
        map['check_items'] ?? map['checkItems'],
        JobSiteDocumentCheckItem.fromMap,
      ),
      annexes: parseList(
        map['annexes'],
        JobSiteDocumentAnnex.fromMap,
      ),
      probesSummary:
          (map['probes_summary'] ?? map['probesSummary'] ?? '').toString().trim(),
      remediationDeadline: parseOptionalDate(
        map['remediation_deadline'] ?? map['remediationDeadline'],
      ),
      trainingProvided: map['training_provided'] == true ||
          map['trainingProvided'] == true,
      preparedForNextStep: (map['prepared_for_next_step'] ??
              map['preparedForNextStep'] ??
              '')
          .toString()
          .trim(),
    );
  }
}
