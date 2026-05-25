import '../clients/client_models.dart';

enum AgfrEquipmentCategory {
  aerConditionatSplit,
  multisplit,
  chiller,
  rooftop,
  vrf,
  cameraFrigorifica,
  vitrinaFrigorifica,
  pompaDeCaldura,
  alta;

  String get value {
    switch (this) {
      case AgfrEquipmentCategory.aerConditionatSplit:
        return 'aer_conditionat_split';
      case AgfrEquipmentCategory.multisplit:
        return 'multisplit';
      case AgfrEquipmentCategory.chiller:
        return 'chiller';
      case AgfrEquipmentCategory.rooftop:
        return 'rooftop';
      case AgfrEquipmentCategory.vrf:
        return 'vrf';
      case AgfrEquipmentCategory.cameraFrigorifica:
        return 'camera_frigorifica';
      case AgfrEquipmentCategory.vitrinaFrigorifica:
        return 'vitrina_frigorifica';
      case AgfrEquipmentCategory.pompaDeCaldura:
        return 'pompa_de_caldura';
      case AgfrEquipmentCategory.alta:
        return 'alta';
    }
  }

  String get label {
    switch (this) {
      case AgfrEquipmentCategory.aerConditionatSplit:
        return 'AC split';
      case AgfrEquipmentCategory.multisplit:
        return 'Multisplit';
      case AgfrEquipmentCategory.chiller:
        return 'Chiller';
      case AgfrEquipmentCategory.rooftop:
        return 'Rooftop';
      case AgfrEquipmentCategory.vrf:
        return 'VRF';
      case AgfrEquipmentCategory.cameraFrigorifica:
        return 'Camera frigorifica';
      case AgfrEquipmentCategory.vitrinaFrigorifica:
        return 'Vitrina frigorifica';
      case AgfrEquipmentCategory.pompaDeCaldura:
        return 'Pompa de caldura';
      case AgfrEquipmentCategory.alta:
        return 'Alta';
    }
  }

  static AgfrEquipmentCategory fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return AgfrEquipmentCategory.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AgfrEquipmentCategory.alta,
    );
  }
}

enum AgfrInterventionType {
  instalare,
  punereInFunctiune,
  service,
  mentenanta,
  verificareEtanseitate,
  recuperare,
  incarcare,
  completare,
  dezafectare;

  String get value {
    switch (this) {
      case AgfrInterventionType.instalare:
        return 'instalare';
      case AgfrInterventionType.punereInFunctiune:
        return 'punere_in_functiune';
      case AgfrInterventionType.service:
        return 'service';
      case AgfrInterventionType.mentenanta:
        return 'mentenanta';
      case AgfrInterventionType.verificareEtanseitate:
        return 'verificare_etanseitate';
      case AgfrInterventionType.recuperare:
        return 'recuperare';
      case AgfrInterventionType.incarcare:
        return 'incarcare';
      case AgfrInterventionType.completare:
        return 'completare';
      case AgfrInterventionType.dezafectare:
        return 'dezafectare';
    }
  }

  String get label {
    switch (this) {
      case AgfrInterventionType.instalare:
        return 'Instalare';
      case AgfrInterventionType.punereInFunctiune:
        return 'Punere in functiune';
      case AgfrInterventionType.service:
        return 'Service';
      case AgfrInterventionType.mentenanta:
        return 'Mentenanta';
      case AgfrInterventionType.verificareEtanseitate:
        return 'Verificare etanseitate';
      case AgfrInterventionType.recuperare:
        return 'Recuperare';
      case AgfrInterventionType.incarcare:
        return 'Incarcare';
      case AgfrInterventionType.completare:
        return 'Completare';
      case AgfrInterventionType.dezafectare:
        return 'Dezafectare';
    }
  }

  static AgfrInterventionType fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return AgfrInterventionType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AgfrInterventionType.service,
    );
  }
}

enum AgfrRefrigerantType {
  r32,
  r134a,
  r404a,
  r407c,
  r410a,
  r417a,
  r422d,
  r448a,
  r449a,
  r452a,
  r454b,
  r507,
  altul;

  String get value {
    switch (this) {
      case AgfrRefrigerantType.r32:
        return 'R32';
      case AgfrRefrigerantType.r134a:
        return 'R134a';
      case AgfrRefrigerantType.r404a:
        return 'R404A';
      case AgfrRefrigerantType.r407c:
        return 'R407C';
      case AgfrRefrigerantType.r410a:
        return 'R410A';
      case AgfrRefrigerantType.r417a:
        return 'R417A';
      case AgfrRefrigerantType.r422d:
        return 'R422D';
      case AgfrRefrigerantType.r448a:
        return 'R448A';
      case AgfrRefrigerantType.r449a:
        return 'R449A';
      case AgfrRefrigerantType.r452a:
        return 'R452A';
      case AgfrRefrigerantType.r454b:
        return 'R454B';
      case AgfrRefrigerantType.r507:
        return 'R507';
      case AgfrRefrigerantType.altul:
        return 'ALTUL';
    }
  }

  String get label {
    switch (this) {
      case AgfrRefrigerantType.altul:
        return 'Altul';
      default:
        return value;
    }
  }

  static AgfrRefrigerantType? fromValue(String? raw) {
    final value = (raw ?? '').trim().toUpperCase();
    for (final item in AgfrRefrigerantType.values) {
      if (item.value.toUpperCase() == value) {
        return item;
      }
    }
    return null;
  }
}

enum AgfrLeakCheckMethod {
  detectorElectronic,
  spuma,
  azot,
  vacuum,
  monitorizarePresiune,
  alta;

  String get value {
    switch (this) {
      case AgfrLeakCheckMethod.detectorElectronic:
        return 'detector_electronic';
      case AgfrLeakCheckMethod.spuma:
        return 'spuma';
      case AgfrLeakCheckMethod.azot:
        return 'azot';
      case AgfrLeakCheckMethod.vacuum:
        return 'vacuum';
      case AgfrLeakCheckMethod.monitorizarePresiune:
        return 'monitorizare_presiune';
      case AgfrLeakCheckMethod.alta:
        return 'alta';
    }
  }

  String get label {
    switch (this) {
      case AgfrLeakCheckMethod.detectorElectronic:
        return 'Detector electronic';
      case AgfrLeakCheckMethod.spuma:
        return 'Spuma';
      case AgfrLeakCheckMethod.azot:
        return 'Azot';
      case AgfrLeakCheckMethod.vacuum:
        return 'Vacuum';
      case AgfrLeakCheckMethod.monitorizarePresiune:
        return 'Monitorizare presiune';
      case AgfrLeakCheckMethod.alta:
        return 'Alta';
    }
  }

  static AgfrLeakCheckMethod? fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final item in AgfrLeakCheckMethod.values) {
      if (item.value == value) {
        return item;
      }
    }
    return null;
  }
}

enum AgfrLeakCheckResult {
  faraScurgeri,
  scurgeriDepistate,
  necesitaMonitorizare,
  neconcludent;

  String get value {
    switch (this) {
      case AgfrLeakCheckResult.faraScurgeri:
        return 'fara_scurgeri';
      case AgfrLeakCheckResult.scurgeriDepistate:
        return 'scurgeri_depistate';
      case AgfrLeakCheckResult.necesitaMonitorizare:
        return 'necesita_monitorizare';
      case AgfrLeakCheckResult.neconcludent:
        return 'neconcludent';
    }
  }

  String get label {
    switch (this) {
      case AgfrLeakCheckResult.faraScurgeri:
        return 'Fara scurgeri';
      case AgfrLeakCheckResult.scurgeriDepistate:
        return 'Scurgeri depistate';
      case AgfrLeakCheckResult.necesitaMonitorizare:
        return 'Necesita monitorizare';
      case AgfrLeakCheckResult.neconcludent:
        return 'Neconcludent';
    }
  }

  static AgfrLeakCheckResult? fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final item in AgfrLeakCheckResult.values) {
      if (item.value == value) {
        return item;
      }
    }
    return null;
  }
}

enum AgfrWeighingSourceType {
  manual,
  testoCsv,
  testoPdf;

  String get value {
    switch (this) {
      case AgfrWeighingSourceType.manual:
        return 'manual';
      case AgfrWeighingSourceType.testoCsv:
        return 'testo_csv';
      case AgfrWeighingSourceType.testoPdf:
        return 'testo_pdf';
    }
  }

  String get label {
    switch (this) {
      case AgfrWeighingSourceType.manual:
        return 'Manual';
      case AgfrWeighingSourceType.testoCsv:
        return 'Import CSV Testo';
      case AgfrWeighingSourceType.testoPdf:
        return 'PDF Testo atasat';
    }
  }

  static AgfrWeighingSourceType fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return AgfrWeighingSourceType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AgfrWeighingSourceType.manual,
    );
  }
}

class AgfrEquipmentRecord {
  const AgfrEquipmentRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.entityType,
    required this.location,
    required this.equipmentCategory,
    required this.equipmentType,
    required this.brand,
    required this.model,
    required this.serialNumber,
    required this.refrigerantType,
    required this.gwp,
    required this.factoryChargeKg,
    required this.additionalChargeKg,
    required this.totalChargeKg,
    required this.co2EquivalentTons,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.jobId = '',
  });

  final String id;
  final String clientId;
  final String clientName;
  final ClientType entityType;
  final String jobId;
  final String location;
  final AgfrEquipmentCategory equipmentCategory;
  final String equipmentType;
  final String brand;
  final String model;
  final String serialNumber;
  final String refrigerantType;
  final double gwp;
  final double factoryChargeKg;
  final double additionalChargeKg;
  final double totalChargeKg;
  final double co2EquivalentTons;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  AgfrEquipmentRecord copyWith({
    String? id,
    String? clientId,
    String? clientName,
    ClientType? entityType,
    String? jobId,
    String? location,
    AgfrEquipmentCategory? equipmentCategory,
    String? equipmentType,
    String? brand,
    String? model,
    String? serialNumber,
    String? refrigerantType,
    double? gwp,
    double? factoryChargeKg,
    double? additionalChargeKg,
    double? totalChargeKg,
    double? co2EquivalentTons,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AgfrEquipmentRecord(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      entityType: entityType ?? this.entityType,
      jobId: jobId ?? this.jobId,
      location: location ?? this.location,
      equipmentCategory: equipmentCategory ?? this.equipmentCategory,
      equipmentType: equipmentType ?? this.equipmentType,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      refrigerantType: refrigerantType ?? this.refrigerantType,
      gwp: gwp ?? this.gwp,
      factoryChargeKg: factoryChargeKg ?? this.factoryChargeKg,
      additionalChargeKg: additionalChargeKg ?? this.additionalChargeKg,
      totalChargeKg: totalChargeKg ?? this.totalChargeKg,
      co2EquivalentTons: co2EquivalentTons ?? this.co2EquivalentTons,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'client_id': clientId,
      'client_name': clientName,
      'entity_type': entityType.value,
      'job_id': jobId,
      'location': location,
      'equipment_category': equipmentCategory.value,
      'equipment_type': equipmentType,
      'brand': brand,
      'model': model,
      'serial_number': serialNumber,
      'refrigerant_type': refrigerantType,
      'gwp': gwp,
      'factory_charge_kg': factoryChargeKg,
      'additional_charge_kg': additionalChargeKg,
      'total_charge_kg': totalChargeKg,
      'co2_equivalent_tons': co2EquivalentTons,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AgfrEquipmentRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return AgfrEquipmentRecord(
      id: _pick(map, const <String>['id']),
      clientId: _pick(map, const <String>['client_id', 'clientId']),
      clientName: _pick(map, const <String>['client_name', 'clientName']),
      entityType: ClientType.fromValue(
        _pick(map, const <String>['entity_type', 'entityType', 'client_type']),
      ),
      jobId: _pick(map, const <String>['job_id', 'jobId']),
      location: _pick(map, const <String>['location']),
      equipmentCategory: AgfrEquipmentCategory.fromValue(
        _pick(map, const <String>['equipment_category', 'equipmentCategory']),
      ),
      equipmentType:
          _pick(map, const <String>['equipment_type', 'equipmentType']),
      brand: _pick(map, const <String>['brand']),
      model: _pick(map, const <String>['model']),
      serialNumber: _pick(map, const <String>['serial_number', 'serialNumber']),
      refrigerantType:
          _pick(map, const <String>['refrigerant_type', 'refrigerantType']),
      gwp: _parseDouble(map['gwp']),
      factoryChargeKg: _parseDouble(
        map['factory_charge_kg'] ?? map['factoryChargeKg'],
      ),
      additionalChargeKg: _parseDouble(
        map['additional_charge_kg'] ?? map['additionalChargeKg'],
      ),
      totalChargeKg: _parseDouble(
        map['total_charge_kg'] ?? map['totalChargeKg'],
      ),
      co2EquivalentTons: _parseDouble(
        map['co2_equivalent_tons'] ?? map['co2EquivalentTons'],
      ),
      notes: _pick(map, const <String>['notes']),
      createdAt: _parseDate(
        map['created_at'] ?? map['createdAt'],
        fallback: now,
      ),
      updatedAt: _parseDate(
        map['updated_at'] ?? map['updatedAt'],
        fallback: now,
      ),
    );
  }
}

class AgfrInterventionRecord {
  const AgfrInterventionRecord({
    required this.id,
    required this.equipmentId,
    required this.clientId,
    required this.clientName,
    required this.operationDate,
    required this.operationType,
    required this.refrigerantType,
    required this.chargedKg,
    required this.recoveredKg,
    required this.totalInSystemKg,
    required this.pressureTestBar,
    required this.pressureTestDurationHours,
    required this.vacuumMicrons,
    required this.vacuumDurationHours,
    required this.leakCheckMethod,
    required this.leakCheckResult,
    required this.notes,
    required this.technicianName,
    required this.technicianCertificateNumber,
    required this.companyFgasAuthorizationNumber,
    required this.createdAt,
    required this.updatedAt,
    this.jobId = '',
    this.appointmentId = '',
  });

  final String id;
  final String equipmentId;
  final String clientId;
  final String clientName;
  final String jobId;
  final String appointmentId;
  final DateTime operationDate;
  final AgfrInterventionType operationType;
  final String refrigerantType;
  final double chargedKg;
  final double recoveredKg;
  final double totalInSystemKg;
  final double pressureTestBar;
  final double pressureTestDurationHours;
  final double vacuumMicrons;
  final double vacuumDurationHours;
  final AgfrLeakCheckMethod? leakCheckMethod;
  final AgfrLeakCheckResult? leakCheckResult;
  final String notes;
  final String technicianName;
  final String technicianCertificateNumber;
  final String companyFgasAuthorizationNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  AgfrInterventionRecord copyWith({
    String? id,
    String? equipmentId,
    String? clientId,
    String? clientName,
    String? jobId,
    String? appointmentId,
    DateTime? operationDate,
    AgfrInterventionType? operationType,
    String? refrigerantType,
    double? chargedKg,
    double? recoveredKg,
    double? totalInSystemKg,
    double? pressureTestBar,
    double? pressureTestDurationHours,
    double? vacuumMicrons,
    double? vacuumDurationHours,
    AgfrLeakCheckMethod? leakCheckMethod,
    bool clearLeakCheckMethod = false,
    AgfrLeakCheckResult? leakCheckResult,
    bool clearLeakCheckResult = false,
    String? notes,
    String? technicianName,
    String? technicianCertificateNumber,
    String? companyFgasAuthorizationNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AgfrInterventionRecord(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      jobId: jobId ?? this.jobId,
      appointmentId: appointmentId ?? this.appointmentId,
      operationDate: operationDate ?? this.operationDate,
      operationType: operationType ?? this.operationType,
      refrigerantType: refrigerantType ?? this.refrigerantType,
      chargedKg: chargedKg ?? this.chargedKg,
      recoveredKg: recoveredKg ?? this.recoveredKg,
      totalInSystemKg: totalInSystemKg ?? this.totalInSystemKg,
      pressureTestBar: pressureTestBar ?? this.pressureTestBar,
      pressureTestDurationHours:
          pressureTestDurationHours ?? this.pressureTestDurationHours,
      vacuumMicrons: vacuumMicrons ?? this.vacuumMicrons,
      vacuumDurationHours: vacuumDurationHours ?? this.vacuumDurationHours,
      leakCheckMethod: clearLeakCheckMethod
          ? null
          : (leakCheckMethod ?? this.leakCheckMethod),
      leakCheckResult: clearLeakCheckResult
          ? null
          : (leakCheckResult ?? this.leakCheckResult),
      notes: notes ?? this.notes,
      technicianName: technicianName ?? this.technicianName,
      technicianCertificateNumber:
          technicianCertificateNumber ?? this.technicianCertificateNumber,
      companyFgasAuthorizationNumber:
          companyFgasAuthorizationNumber ?? this.companyFgasAuthorizationNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'equipment_id': equipmentId,
      'client_id': clientId,
      'client_name': clientName,
      'job_id': jobId,
      'appointment_id': appointmentId,
      'operation_date': operationDate.toIso8601String(),
      'operation_type': operationType.value,
      'refrigerant_type': refrigerantType,
      'charged_kg': chargedKg,
      'recovered_kg': recoveredKg,
      'total_in_system_kg': totalInSystemKg,
      'pressure_test_bar': pressureTestBar,
      'pressure_test_duration_hours': pressureTestDurationHours,
      'vacuum_microns': vacuumMicrons,
      'vacuum_duration_hours': vacuumDurationHours,
      'leak_check_method': leakCheckMethod?.value ?? '',
      'leak_check_result': leakCheckResult?.value ?? '',
      'notes': notes,
      'technician_name': technicianName,
      'technician_certificate_number': technicianCertificateNumber,
      'company_fgas_authorization_number': companyFgasAuthorizationNumber,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AgfrInterventionRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return AgfrInterventionRecord(
      id: _pick(map, const <String>['id']),
      equipmentId: _pick(map, const <String>['equipment_id', 'equipmentId']),
      clientId: _pick(map, const <String>['client_id', 'clientId']),
      clientName: _pick(map, const <String>['client_name', 'clientName']),
      jobId: _pick(map, const <String>['job_id', 'jobId']),
      appointmentId:
          _pick(map, const <String>['appointment_id', 'appointmentId']),
      operationDate: _parseDate(
        map['operation_date'] ?? map['operationDate'],
        fallback: now,
      ),
      operationType: AgfrInterventionType.fromValue(
        _pick(map, const <String>['operation_type', 'operationType']),
      ),
      refrigerantType:
          _pick(map, const <String>['refrigerant_type', 'refrigerantType']),
      chargedKg: _parseDouble(map['charged_kg'] ?? map['chargedKg']),
      recoveredKg: _parseDouble(map['recovered_kg'] ?? map['recoveredKg']),
      totalInSystemKg: _parseDouble(
        map['total_in_system_kg'] ?? map['totalInSystemKg'],
      ),
      pressureTestBar: _parseDouble(
        map['pressure_test_bar'] ?? map['pressureTestBar'],
      ),
      pressureTestDurationHours: _parseDouble(
        map['pressure_test_duration_hours'] ?? map['pressureTestDurationHours'],
      ),
      vacuumMicrons:
          _parseDouble(map['vacuum_microns'] ?? map['vacuumMicrons']),
      vacuumDurationHours: _parseDouble(
        map['vacuum_duration_hours'] ?? map['vacuumDurationHours'],
      ),
      leakCheckMethod: AgfrLeakCheckMethod.fromValue(
        _pick(map, const <String>['leak_check_method', 'leakCheckMethod']),
      ),
      leakCheckResult: AgfrLeakCheckResult.fromValue(
        _pick(map, const <String>['leak_check_result', 'leakCheckResult']),
      ),
      notes: _pick(map, const <String>['notes']),
      technicianName:
          _pick(map, const <String>['technician_name', 'technicianName']),
      technicianCertificateNumber: _pick(
        map,
        const <String>[
          'technician_certificate_number',
          'technicianCertificateNumber',
        ],
      ),
      companyFgasAuthorizationNumber: _pick(
        map,
        const <String>[
          'company_fgas_authorization_number',
          'companyFgasAuthorizationNumber',
        ],
      ),
      createdAt: _parseDate(
        map['created_at'] ?? map['createdAt'],
        fallback: now,
      ),
      updatedAt: _parseDate(
        map['updated_at'] ?? map['updatedAt'],
        fallback: now,
      ),
    );
  }
}

class AgfrReportRecord {
  const AgfrReportRecord({
    required this.id,
    required this.equipmentId,
    required this.interventionId,
    required this.clientId,
    required this.jobId,
    required this.reportNumber,
    required this.operationDate,
    required this.beneficiaryRepresentative,
    required this.technicianName,
    required this.technicianCertificateNumber,
    required this.companyFgasAuthorizationNumber,
    required this.observations,
    required this.conclusions,
    required this.clientSignatureBase64,
    required this.technicianSignatureBase64,
    required this.documentType,
    required this.sourceModule,
    this.weighingReportId = '',
    required this.companyCertificateAttachmentPath,
    required this.technicianCertificateAttachmentPath,
    this.generatedDocumentPath = '',
    this.generatedDocumentFileName = '',
    this.registryEntryId = '',
    this.registryNumber = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String equipmentId;
  final String interventionId;
  final String clientId;
  final String jobId;
  final String reportNumber;
  final DateTime operationDate;
  final String beneficiaryRepresentative;
  final String technicianName;
  final String technicianCertificateNumber;
  final String companyFgasAuthorizationNumber;
  final String observations;
  final String conclusions;
  final String clientSignatureBase64;
  final String technicianSignatureBase64;
  final String documentType;
  final String sourceModule;
  final String weighingReportId;
  final String companyCertificateAttachmentPath;
  final String technicianCertificateAttachmentPath;
  final String generatedDocumentPath;
  final String generatedDocumentFileName;
  final String registryEntryId;
  final String registryNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  AgfrReportRecord copyWith({
    String? id,
    String? equipmentId,
    String? interventionId,
    String? clientId,
    String? jobId,
    String? reportNumber,
    DateTime? operationDate,
    String? beneficiaryRepresentative,
    String? technicianName,
    String? technicianCertificateNumber,
    String? companyFgasAuthorizationNumber,
    String? observations,
    String? conclusions,
    String? clientSignatureBase64,
    String? technicianSignatureBase64,
    String? documentType,
    String? sourceModule,
    String? weighingReportId,
    String? companyCertificateAttachmentPath,
    String? technicianCertificateAttachmentPath,
    String? generatedDocumentPath,
    String? generatedDocumentFileName,
    String? registryEntryId,
    String? registryNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AgfrReportRecord(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      interventionId: interventionId ?? this.interventionId,
      clientId: clientId ?? this.clientId,
      jobId: jobId ?? this.jobId,
      reportNumber: reportNumber ?? this.reportNumber,
      operationDate: operationDate ?? this.operationDate,
      beneficiaryRepresentative:
          beneficiaryRepresentative ?? this.beneficiaryRepresentative,
      technicianName: technicianName ?? this.technicianName,
      technicianCertificateNumber:
          technicianCertificateNumber ?? this.technicianCertificateNumber,
      companyFgasAuthorizationNumber:
          companyFgasAuthorizationNumber ?? this.companyFgasAuthorizationNumber,
      observations: observations ?? this.observations,
      conclusions: conclusions ?? this.conclusions,
      clientSignatureBase64:
          clientSignatureBase64 ?? this.clientSignatureBase64,
      technicianSignatureBase64:
          technicianSignatureBase64 ?? this.technicianSignatureBase64,
      documentType: documentType ?? this.documentType,
      sourceModule: sourceModule ?? this.sourceModule,
      weighingReportId: weighingReportId ?? this.weighingReportId,
      companyCertificateAttachmentPath: companyCertificateAttachmentPath ??
          this.companyCertificateAttachmentPath,
      technicianCertificateAttachmentPath:
          technicianCertificateAttachmentPath ??
              this.technicianCertificateAttachmentPath,
      generatedDocumentPath:
          generatedDocumentPath ?? this.generatedDocumentPath,
      generatedDocumentFileName:
          generatedDocumentFileName ?? this.generatedDocumentFileName,
      registryEntryId: registryEntryId ?? this.registryEntryId,
      registryNumber: registryNumber ?? this.registryNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'equipment_id': equipmentId,
      'intervention_id': interventionId,
      'client_id': clientId,
      'job_id': jobId,
      'report_number': reportNumber,
      'operation_date': operationDate.toIso8601String(),
      'beneficiary_representative': beneficiaryRepresentative,
      'technician_name': technicianName,
      'technician_certificate_number': technicianCertificateNumber,
      'company_fgas_authorization_number': companyFgasAuthorizationNumber,
      'observations': observations,
      'conclusions': conclusions,
      'client_signature_base64': clientSignatureBase64,
      'technician_signature_base64': technicianSignatureBase64,
      'document_type': documentType,
      'source_module': sourceModule,
      'weighing_report_id': weighingReportId,
      'company_certificate_attachment_path': companyCertificateAttachmentPath,
      'technician_certificate_attachment_path':
          technicianCertificateAttachmentPath,
      'generated_document_path': generatedDocumentPath,
      'generated_document_file_name': generatedDocumentFileName,
      'registry_entry_id': registryEntryId,
      'registry_number': registryNumber,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AgfrReportRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return AgfrReportRecord(
      id: _pick(map, const <String>['id']),
      equipmentId: _pick(map, const <String>['equipment_id', 'equipmentId']),
      interventionId: _pick(
        map,
        const <String>['intervention_id', 'interventionId'],
      ),
      clientId: _pick(map, const <String>['client_id', 'clientId']),
      jobId: _pick(map, const <String>['job_id', 'jobId']),
      reportNumber: _pick(map, const <String>['report_number', 'reportNumber']),
      operationDate: _parseDate(
        map['operation_date'] ?? map['operationDate'],
        fallback: now,
      ),
      beneficiaryRepresentative: _pick(
        map,
        const <String>[
          'beneficiary_representative',
          'beneficiaryRepresentative',
        ],
      ),
      technicianName:
          _pick(map, const <String>['technician_name', 'technicianName']),
      technicianCertificateNumber: _pick(
        map,
        const <String>[
          'technician_certificate_number',
          'technicianCertificateNumber',
        ],
      ),
      companyFgasAuthorizationNumber: _pick(
        map,
        const <String>[
          'company_fgas_authorization_number',
          'companyFgasAuthorizationNumber',
        ],
      ),
      observations: _pick(map, const <String>['observations']),
      conclusions: _pick(map, const <String>['conclusions']),
      clientSignatureBase64: _pick(
        map,
        const <String>['client_signature_base64', 'clientSignatureBase64'],
      ),
      technicianSignatureBase64: _pick(
        map,
        const <String>[
          'technician_signature_base64',
          'technicianSignatureBase64',
        ],
      ),
      documentType: _pick(
        map,
        const <String>['document_type', 'documentType'],
      ).isEmpty
          ? 'pv_agfr'
          : _pick(
              map,
              const <String>['document_type', 'documentType'],
            ),
      sourceModule: _pick(
        map,
        const <String>['source_module', 'sourceModule'],
      ).isEmpty
          ? 'agfr'
          : _pick(
              map,
              const <String>['source_module', 'sourceModule'],
            ),
      weighingReportId: _pick(
        map,
        const <String>['weighing_report_id', 'weighingReportId'],
      ),
      companyCertificateAttachmentPath: _pick(
        map,
        const <String>[
          'company_certificate_attachment_path',
          'companyCertificateAttachmentPath',
        ],
      ),
      technicianCertificateAttachmentPath: _pick(
        map,
        const <String>[
          'technician_certificate_attachment_path',
          'technicianCertificateAttachmentPath',
        ],
      ),
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
      registryEntryId: _pick(
        map,
        const <String>['registry_entry_id', 'registryEntryId'],
      ),
      registryNumber: _pick(
        map,
        const <String>['registry_number', 'registryNumber'],
      ),
      createdAt: _parseDate(
        map['created_at'] ?? map['createdAt'],
        fallback: now,
      ),
      updatedAt: _parseDate(
        map['updated_at'] ?? map['updatedAt'],
        fallback: now,
      ),
    );
  }
}

class AgfrWeighingReportRecord {
  const AgfrWeighingReportRecord({
    required this.id,
    required this.reportId,
    required this.equipmentId,
    required this.interventionId,
    required this.clientId,
    required this.jobId,
    required this.operationDate,
    required this.sourceType,
    required this.sourceFilePath,
    required this.sourceFileName,
    required this.sourceImportedAt,
    required this.sourceDeviceInfo,
    required this.sourceRawPayload,
    required this.originalPdfAttachmentPath,
    required this.originalPdfAttachmentFileName,
    required this.measurementTimestamp,
    required this.initialWeightKg,
    required this.finalWeightKg,
    required this.chargedKg,
    required this.recoveredKg,
    required this.netQuantityKg,
    required this.scaleIdentifier,
    required this.cylinderIdentifier,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String reportId;
  final String equipmentId;
  final String interventionId;
  final String clientId;
  final String jobId;
  final DateTime operationDate;
  final AgfrWeighingSourceType sourceType;
  final String sourceFilePath;
  final String sourceFileName;
  final DateTime? sourceImportedAt;
  final String sourceDeviceInfo;
  final String sourceRawPayload;
  final String originalPdfAttachmentPath;
  final String originalPdfAttachmentFileName;
  final DateTime? measurementTimestamp;
  final double initialWeightKg;
  final double finalWeightKg;
  final double chargedKg;
  final double recoveredKg;
  final double netQuantityKg;
  final String scaleIdentifier;
  final String cylinderIdentifier;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  AgfrWeighingReportRecord copyWith({
    String? id,
    String? reportId,
    String? equipmentId,
    String? interventionId,
    String? clientId,
    String? jobId,
    DateTime? operationDate,
    AgfrWeighingSourceType? sourceType,
    String? sourceFilePath,
    String? sourceFileName,
    DateTime? sourceImportedAt,
    bool clearSourceImportedAt = false,
    String? sourceDeviceInfo,
    String? sourceRawPayload,
    String? originalPdfAttachmentPath,
    String? originalPdfAttachmentFileName,
    DateTime? measurementTimestamp,
    bool clearMeasurementTimestamp = false,
    double? initialWeightKg,
    double? finalWeightKg,
    double? chargedKg,
    double? recoveredKg,
    double? netQuantityKg,
    String? scaleIdentifier,
    String? cylinderIdentifier,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AgfrWeighingReportRecord(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      equipmentId: equipmentId ?? this.equipmentId,
      interventionId: interventionId ?? this.interventionId,
      clientId: clientId ?? this.clientId,
      jobId: jobId ?? this.jobId,
      operationDate: operationDate ?? this.operationDate,
      sourceType: sourceType ?? this.sourceType,
      sourceFilePath: sourceFilePath ?? this.sourceFilePath,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      sourceImportedAt: clearSourceImportedAt
          ? null
          : (sourceImportedAt ?? this.sourceImportedAt),
      sourceDeviceInfo: sourceDeviceInfo ?? this.sourceDeviceInfo,
      sourceRawPayload: sourceRawPayload ?? this.sourceRawPayload,
      originalPdfAttachmentPath:
          originalPdfAttachmentPath ?? this.originalPdfAttachmentPath,
      originalPdfAttachmentFileName:
          originalPdfAttachmentFileName ?? this.originalPdfAttachmentFileName,
      measurementTimestamp: clearMeasurementTimestamp
          ? null
          : (measurementTimestamp ?? this.measurementTimestamp),
      initialWeightKg: initialWeightKg ?? this.initialWeightKg,
      finalWeightKg: finalWeightKg ?? this.finalWeightKg,
      chargedKg: chargedKg ?? this.chargedKg,
      recoveredKg: recoveredKg ?? this.recoveredKg,
      netQuantityKg: netQuantityKg ?? this.netQuantityKg,
      scaleIdentifier: scaleIdentifier ?? this.scaleIdentifier,
      cylinderIdentifier: cylinderIdentifier ?? this.cylinderIdentifier,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'report_id': reportId,
      'equipment_id': equipmentId,
      'intervention_id': interventionId,
      'client_id': clientId,
      'job_id': jobId,
      'operation_date': operationDate.toIso8601String(),
      'source_type': sourceType.value,
      'source_file_path': sourceFilePath,
      'source_file_name': sourceFileName,
      'source_imported_at': sourceImportedAt?.toIso8601String() ?? '',
      'source_device_info': sourceDeviceInfo,
      'source_raw_payload': sourceRawPayload,
      'original_pdf_attachment_path': originalPdfAttachmentPath,
      'original_pdf_attachment_file_name': originalPdfAttachmentFileName,
      'measurement_timestamp': measurementTimestamp?.toIso8601String() ?? '',
      'initial_weight_kg': initialWeightKg,
      'final_weight_kg': finalWeightKg,
      'charged_kg': chargedKg,
      'recovered_kg': recoveredKg,
      'net_quantity_kg': netQuantityKg,
      'scale_identifier': scaleIdentifier,
      'cylinder_identifier': cylinderIdentifier,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AgfrWeighingReportRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return AgfrWeighingReportRecord(
      id: _pick(map, const <String>['id']),
      reportId: _pick(map, const <String>['report_id', 'reportId']),
      equipmentId: _pick(map, const <String>['equipment_id', 'equipmentId']),
      interventionId: _pick(
        map,
        const <String>['intervention_id', 'interventionId'],
      ),
      clientId: _pick(map, const <String>['client_id', 'clientId']),
      jobId: _pick(map, const <String>['job_id', 'jobId']),
      operationDate: _parseDate(
        map['operation_date'] ?? map['operationDate'],
        fallback: now,
      ),
      sourceType: AgfrWeighingSourceType.fromValue(
        _pick(map, const <String>['source_type', 'sourceType']),
      ),
      sourceFilePath: _pick(
        map,
        const <String>['source_file_path', 'sourceFilePath'],
      ),
      sourceFileName: _pick(
        map,
        const <String>['source_file_name', 'sourceFileName'],
      ),
      sourceImportedAt: _parseOptionalDate(
        map['source_imported_at'] ?? map['sourceImportedAt'],
      ),
      sourceDeviceInfo: _pick(
        map,
        const <String>['source_device_info', 'sourceDeviceInfo'],
      ),
      sourceRawPayload: _pick(
        map,
        const <String>['source_raw_payload', 'sourceRawPayload'],
      ),
      originalPdfAttachmentPath: _pick(
        map,
        const <String>[
          'original_pdf_attachment_path',
          'originalPdfAttachmentPath',
        ],
      ),
      originalPdfAttachmentFileName: _pick(
        map,
        const <String>[
          'original_pdf_attachment_file_name',
          'originalPdfAttachmentFileName',
        ],
      ),
      measurementTimestamp: _parseOptionalDate(
        map['measurement_timestamp'] ?? map['measurementTimestamp'],
      ),
      initialWeightKg: _parseDouble(
        map['initial_weight_kg'] ?? map['initialWeightKg'],
      ),
      finalWeightKg: _parseDouble(
        map['final_weight_kg'] ?? map['finalWeightKg'],
      ),
      chargedKg: _parseDouble(map['charged_kg'] ?? map['chargedKg']),
      recoveredKg: _parseDouble(map['recovered_kg'] ?? map['recoveredKg']),
      netQuantityKg: _parseDouble(
        map['net_quantity_kg'] ?? map['netQuantityKg'],
      ),
      scaleIdentifier: _pick(
        map,
        const <String>['scale_identifier', 'scaleIdentifier'],
      ),
      cylinderIdentifier: _pick(
        map,
        const <String>['cylinder_identifier', 'cylinderIdentifier'],
      ),
      notes: _pick(map, const <String>['notes']),
      createdAt: _parseDate(
        map['created_at'] ?? map['createdAt'],
        fallback: now,
      ),
      updatedAt: _parseDate(
        map['updated_at'] ?? map['updatedAt'],
        fallback: now,
      ),
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

double _parseDouble(dynamic raw) {
  if (raw is num) {
    return raw.toDouble();
  }
  return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
}

DateTime _parseDate(dynamic raw, {required DateTime fallback}) {
  final value = (raw ?? '').toString().trim();
  return DateTime.tryParse(value) ?? fallback;
}

DateTime? _parseOptionalDate(dynamic raw) {
  final value = (raw ?? '').toString().trim();
  if (value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
