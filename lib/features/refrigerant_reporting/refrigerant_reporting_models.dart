enum RefrigerantReportingEntityType {
  persoanaFizica,
  persoanaJuridica;

  String get value {
    switch (this) {
      case RefrigerantReportingEntityType.persoanaFizica:
        return 'pf';
      case RefrigerantReportingEntityType.persoanaJuridica:
        return 'pj';
    }
  }

  String get label {
    switch (this) {
      case RefrigerantReportingEntityType.persoanaFizica:
        return 'PF';
      case RefrigerantReportingEntityType.persoanaJuridica:
        return 'PJ';
    }
  }

  static RefrigerantReportingEntityType fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return RefrigerantReportingEntityType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => RefrigerantReportingEntityType.persoanaJuridica,
    );
  }
}

enum RefrigerantReportingCategory {
  refrigerareIndustriala,
  climatizareIndustriala,
  refrigerareComerciala,
  climatizareComerciala,
  rataAnualaScurgere,
  altaCategorie;

  String get value {
    switch (this) {
      case RefrigerantReportingCategory.refrigerareIndustriala:
        return 'refrigerare_industriala';
      case RefrigerantReportingCategory.climatizareIndustriala:
        return 'climatizare_industriala';
      case RefrigerantReportingCategory.refrigerareComerciala:
        return 'refrigerare_comerciala';
      case RefrigerantReportingCategory.climatizareComerciala:
        return 'climatizare_comerciala';
      case RefrigerantReportingCategory.rataAnualaScurgere:
        return 'rata_anuala_scurgere';
      case RefrigerantReportingCategory.altaCategorie:
        return 'alta_categorie';
    }
  }

  String get label {
    switch (this) {
      case RefrigerantReportingCategory.refrigerareIndustriala:
        return 'Refrigerare industriala';
      case RefrigerantReportingCategory.climatizareIndustriala:
        return 'Climatizare industriala';
      case RefrigerantReportingCategory.refrigerareComerciala:
        return 'Refrigerare comerciala';
      case RefrigerantReportingCategory.climatizareComerciala:
        return 'Climatizare comerciala';
      case RefrigerantReportingCategory.rataAnualaScurgere:
        return 'Rata anuala de scurgere';
      case RefrigerantReportingCategory.altaCategorie:
        return 'Alta categorie';
    }
  }

  static RefrigerantReportingCategory fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return RefrigerantReportingCategory.values.firstWhere(
      (item) => item.value == value,
      orElse: () => RefrigerantReportingCategory.refrigerareComerciala,
    );
  }
}

enum RefrigerantReportingStatus {
  draft,
  inLucru,
  pregatita,
  transmisa;

  String get value {
    switch (this) {
      case RefrigerantReportingStatus.draft:
        return 'draft';
      case RefrigerantReportingStatus.inLucru:
        return 'in_lucru';
      case RefrigerantReportingStatus.pregatita:
        return 'pregatita';
      case RefrigerantReportingStatus.transmisa:
        return 'transmisa';
    }
  }

  String get label {
    switch (this) {
      case RefrigerantReportingStatus.draft:
        return 'Draft';
      case RefrigerantReportingStatus.inLucru:
        return 'In lucru';
      case RefrigerantReportingStatus.pregatita:
        return 'Pregatita';
      case RefrigerantReportingStatus.transmisa:
        return 'Transmisa';
    }
  }

  static RefrigerantReportingStatus fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return RefrigerantReportingStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => RefrigerantReportingStatus.draft,
    );
  }
}

class RefrigerantReportingRecord {
  const RefrigerantReportingRecord({
    required this.id,
    required this.reportingYear,
    required this.clientId,
    required this.clientName,
    required this.entityType,
    required this.workLocation,
    required this.reportingCategory,
    required this.status,
    required this.questionnaireTitle,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.jobId = '',
    this.location = '',
    this.equipmentIds = const <String>[],
    this.equipmentSummary = '',
    this.registryEntryId = '',
    this.documentType = 'chestionar_anmap',
    this.sourceModule = 'refrigeranti_anmap',
    this.generatedDocumentPath = '',
    this.generatedDocumentFileName = '',
  });

  final String id;
  final int reportingYear;
  final String clientId;
  final String clientName;
  final RefrigerantReportingEntityType entityType;
  final String jobId;
  final String workLocation;
  final String location;
  final RefrigerantReportingCategory reportingCategory;
  final List<String> equipmentIds;
  final String equipmentSummary;
  final RefrigerantReportingStatus status;
  final String questionnaireTitle;
  final String notes;
  final String registryEntryId;
  final String documentType;
  final String sourceModule;
  final String generatedDocumentPath;
  final String generatedDocumentFileName;
  final DateTime createdAt;
  final DateTime updatedAt;

  RefrigerantReportingRecord copyWith({
    String? id,
    int? reportingYear,
    String? clientId,
    String? clientName,
    RefrigerantReportingEntityType? entityType,
    String? jobId,
    String? workLocation,
    String? location,
    RefrigerantReportingCategory? reportingCategory,
    List<String>? equipmentIds,
    String? equipmentSummary,
    RefrigerantReportingStatus? status,
    String? questionnaireTitle,
    String? notes,
    String? registryEntryId,
    String? documentType,
    String? sourceModule,
    String? generatedDocumentPath,
    String? generatedDocumentFileName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RefrigerantReportingRecord(
      id: id ?? this.id,
      reportingYear: reportingYear ?? this.reportingYear,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      entityType: entityType ?? this.entityType,
      jobId: jobId ?? this.jobId,
      workLocation: workLocation ?? this.workLocation,
      location: location ?? this.location,
      reportingCategory: reportingCategory ?? this.reportingCategory,
      equipmentIds: equipmentIds ?? this.equipmentIds,
      equipmentSummary: equipmentSummary ?? this.equipmentSummary,
      status: status ?? this.status,
      questionnaireTitle: questionnaireTitle ?? this.questionnaireTitle,
      notes: notes ?? this.notes,
      registryEntryId: registryEntryId ?? this.registryEntryId,
      documentType: documentType ?? this.documentType,
      sourceModule: sourceModule ?? this.sourceModule,
      generatedDocumentPath: generatedDocumentPath ?? this.generatedDocumentPath,
      generatedDocumentFileName:
          generatedDocumentFileName ?? this.generatedDocumentFileName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'reporting_year': reportingYear,
      'client_id': clientId,
      'client_name': clientName,
      'entity_type': entityType.value,
      'job_id': jobId,
      'work_location': workLocation,
      'location': location,
      'reporting_category': reportingCategory.value,
      'equipment_ids': equipmentIds,
      'equipment_summary': equipmentSummary,
      'status': status.value,
      'questionnaire_title': questionnaireTitle,
      'notes': notes,
      'registry_entry_id': registryEntryId,
      'document_type': documentType,
      'source_module': sourceModule,
      'generated_document_path': generatedDocumentPath,
      'generated_document_file_name': generatedDocumentFileName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory RefrigerantReportingRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    List<String> parseIds(dynamic raw) {
      if (raw is! List) {
        return const <String>[];
      }
      final values = <String>[];
      for (final item in raw) {
        final value = item.toString().trim();
        if (value.isEmpty || values.contains(value)) {
          continue;
        }
        values.add(value);
      }
      return values;
    }

    int parseYear(dynamic raw) {
      if (raw is num) {
        return raw.toInt();
      }
      return int.tryParse('${raw ?? ''}'.trim()) ?? now.year;
    }

    return RefrigerantReportingRecord(
      id: _pick(map, const <String>['id']),
      reportingYear: parseYear(map['reporting_year'] ?? map['reportingYear']),
      clientId: _pick(map, const <String>['client_id', 'clientId']),
      clientName: _pick(map, const <String>['client_name', 'clientName']),
      entityType: RefrigerantReportingEntityType.fromValue(
        _pick(map, const <String>['entity_type', 'entityType']),
      ),
      jobId: _pick(map, const <String>['job_id', 'jobId']),
      workLocation: _pick(
        map,
        const <String>['work_location', 'workLocation'],
      ),
      location: _pick(map, const <String>['location']),
      reportingCategory: RefrigerantReportingCategory.fromValue(
        _pick(
          map,
          const <String>['reporting_category', 'reportingCategory'],
        ),
      ),
      equipmentIds: parseIds(map['equipment_ids'] ?? map['equipmentIds']),
      equipmentSummary: _pick(
        map,
        const <String>['equipment_summary', 'equipmentSummary'],
      ),
      status: RefrigerantReportingStatus.fromValue(
        _pick(map, const <String>['status']),
      ),
      questionnaireTitle: _pick(
        map,
        const <String>['questionnaire_title', 'questionnaireTitle'],
      ),
      notes: _pick(map, const <String>['notes']),
      registryEntryId: _pick(
        map,
        const <String>['registry_entry_id', 'registryEntryId'],
      ),
      documentType: _pick(
        map,
        const <String>['document_type', 'documentType'],
      ).isEmpty
          ? 'chestionar_anmap'
          : _pick(map, const <String>['document_type', 'documentType']),
      sourceModule: _pick(
        map,
        const <String>['source_module', 'sourceModule'],
      ).isEmpty
          ? 'refrigeranti_anmap'
          : _pick(map, const <String>['source_module', 'sourceModule']),
      generatedDocumentPath: _pick(
        map,
        const <String>['generated_document_path', 'generatedDocumentPath'],
      ),
      generatedDocumentFileName: _pick(
        map,
        const <String>[
          'generated_document_file_name',
          'generatedDocumentFileName',
        ],
      ),
      createdAt: _parseDate(map['created_at'] ?? map['createdAt'], now),
      updatedAt: _parseDate(map['updated_at'] ?? map['updatedAt'], now),
    );
  }
}

String _pick(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

DateTime _parseDate(dynamic raw, DateTime fallback) {
  final value = (raw ?? '').toString().trim();
  return DateTime.tryParse(value) ?? fallback;
}
