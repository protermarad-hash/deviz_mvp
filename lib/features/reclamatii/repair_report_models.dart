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
    this.interventionNumber = 1,
    this.previousReportId = '',
    this.previousReportNumber = '',
    this.previousInterventionSummary = '',
    this.isFollowUp = false,
    this.photoUrls = const <String>[],
    this.photoBase64List = const <String>[],
    this.photoCategories = const <String>[],
    this.photoCaptions = const <String>[],
    // Câmpuri noi template PV Constatare Tehnică (adiționale, backward compatible)
    this.agentFrigorific = '',
    this.cantitateRecuperata = '',
    this.cantitateAdaugata = '',
    this.logFGasGenerat = false,
    this.logFGasPath = '',
    this.coduriEroare = '',
    this.stareTest = '',
    this.reprezentantBeneficiar = '',
    this.motivulInterventiei = '',
    this.constatariLocFinding = '',
    this.lucrariEfectuateDetailed = '',
    this.observatiiTehnice = '',
    this.concluzie = '',
    this.recomandari = '',
    this.mentiuni = '',
    this.materialeDetailed = '',
    this.traseulPieselorDefecte = '',
    this.pvType = 'constatare',
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
  final int interventionNumber;
  final String previousReportId;
  final String previousReportNumber;
  final String previousInterventionSummary;
  final bool isFollowUp;
  final List<String> photoUrls;
  final List<String> photoBase64List;
  final List<String> photoCategories;
  final List<String> photoCaptions;
  // Câmpuri template PV Constatare Tehnică
  final String agentFrigorific;
  final String cantitateRecuperata;
  final String cantitateAdaugata;
  final bool logFGasGenerat;
  final String logFGasPath;
  final String coduriEroare;
  final String stareTest;
  final String reprezentantBeneficiar;
  final String motivulInterventiei;
  final String constatariLocFinding;
  final String lucrariEfectuateDetailed;
  final String observatiiTehnice;
  final String concluzie;
  final String recomandari;
  final String mentiuni;
  final String materialeDetailed;
  final String traseulPieselorDefecte;
  final String pvType;

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
    int? interventionNumber,
    String? previousReportId,
    String? previousReportNumber,
    String? previousInterventionSummary,
    bool? isFollowUp,
    List<String>? photoUrls,
    List<String>? photoBase64List,
    List<String>? photoCategories,
    List<String>? photoCaptions,
    String? agentFrigorific,
    String? cantitateRecuperata,
    String? cantitateAdaugata,
    bool? logFGasGenerat,
    String? logFGasPath,
    String? coduriEroare,
    String? stareTest,
    String? reprezentantBeneficiar,
    String? motivulInterventiei,
    String? constatariLocFinding,
    String? lucrariEfectuateDetailed,
    String? observatiiTehnice,
    String? concluzie,
    String? recomandari,
    String? mentiuni,
    String? materialeDetailed,
    String? traseulPieselorDefecte,
    String? pvType,
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
      interventionNumber: interventionNumber ?? this.interventionNumber,
      previousReportId: previousReportId ?? this.previousReportId,
      previousReportNumber: previousReportNumber ?? this.previousReportNumber,
      previousInterventionSummary: previousInterventionSummary ?? this.previousInterventionSummary,
      isFollowUp: isFollowUp ?? this.isFollowUp,
      photoUrls: photoUrls ?? this.photoUrls,
      photoBase64List: photoBase64List ?? this.photoBase64List,
      photoCategories: photoCategories ?? this.photoCategories,
      photoCaptions: photoCaptions ?? this.photoCaptions,
      agentFrigorific: agentFrigorific ?? this.agentFrigorific,
      cantitateRecuperata: cantitateRecuperata ?? this.cantitateRecuperata,
      cantitateAdaugata: cantitateAdaugata ?? this.cantitateAdaugata,
      logFGasGenerat: logFGasGenerat ?? this.logFGasGenerat,
      logFGasPath: logFGasPath ?? this.logFGasPath,
      coduriEroare: coduriEroare ?? this.coduriEroare,
      stareTest: stareTest ?? this.stareTest,
      reprezentantBeneficiar: reprezentantBeneficiar ?? this.reprezentantBeneficiar,
      motivulInterventiei: motivulInterventiei ?? this.motivulInterventiei,
      constatariLocFinding: constatariLocFinding ?? this.constatariLocFinding,
      lucrariEfectuateDetailed: lucrariEfectuateDetailed ?? this.lucrariEfectuateDetailed,
      observatiiTehnice: observatiiTehnice ?? this.observatiiTehnice,
      concluzie: concluzie ?? this.concluzie,
      recomandari: recomandari ?? this.recomandari,
      mentiuni: mentiuni ?? this.mentiuni,
      materialeDetailed: materialeDetailed ?? this.materialeDetailed,
      traseulPieselorDefecte: traseulPieselorDefecte ?? this.traseulPieselorDefecte,
      pvType: pvType ?? this.pvType,
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
      'intervention_number': interventionNumber,
      'previous_report_id': previousReportId,
      'previous_report_number': previousReportNumber,
      'previous_intervention_summary': previousInterventionSummary,
      'is_follow_up': isFollowUp,
      'photo_urls': photoUrls,
      'photo_base64_list': photoBase64List,
      'photo_categories': photoCategories,
      'photo_captions': photoCaptions,
      'agent_frigorific': agentFrigorific,
      'cantitate_recuperata': cantitateRecuperata,
      'cantitate_adaugata': cantitateAdaugata,
      'log_fgas_generat': logFGasGenerat,
      'log_fgas_path': logFGasPath,
      'coduri_eroare': coduriEroare,
      'stare_test': stareTest,
      'reprezentant_beneficiar': reprezentantBeneficiar,
      'motivul_interventiei': motivulInterventiei,
      'constatari_loc_finding': constatariLocFinding,
      'lucrari_efectuate_detailed': lucrariEfectuateDetailed,
      'observatii_tehnice': observatiiTehnice,
      'concluzie': concluzie,
      'recomandari': recomandari,
      'mentiuni': mentiuni,
      'materiale_detailed': materialeDetailed,
      'traseul_pieselor_defecte': traseulPieselorDefecte,
      'pv_type': pvType,
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
      interventionNumber: (map['intervention_number'] ?? map['interventionNumber'] ?? 1) as int,
      previousReportId: pick(const <String>['previous_report_id', 'previousReportId']),
      previousReportNumber: pick(const <String>['previous_report_number', 'previousReportNumber']),
      previousInterventionSummary: pick(const <String>['previous_intervention_summary', 'previousInterventionSummary']),
      isFollowUp: (map['is_follow_up'] ?? map['isFollowUp'] ?? false) as bool,
      photoUrls: List<String>.from((map['photo_urls'] ?? map['photoUrls'] ?? const <String>[]) as List),
      photoBase64List: List<String>.from((map['photo_base64_list'] ?? map['photoBase64List'] ?? const <String>[]) as List),
      photoCategories: List<String>.from((map['photo_categories'] ?? map['photoCategories'] ?? const <String>[]) as List),
      photoCaptions: List<String>.from((map['photo_captions'] ?? map['photoCaptions'] ?? const <String>[]) as List),
      agentFrigorific: pick(const <String>['agent_frigorific']),
      cantitateRecuperata: pick(const <String>['cantitate_recuperata']),
      cantitateAdaugata: pick(const <String>['cantitate_adaugata']),
      logFGasGenerat: map['log_fgas_generat'] == true,
      logFGasPath: pick(const <String>['log_fgas_path']),
      coduriEroare: pick(const <String>['coduri_eroare']),
      stareTest: pick(const <String>['stare_test']),
      reprezentantBeneficiar: pick(const <String>['reprezentant_beneficiar']),
      motivulInterventiei: pick(const <String>['motivul_interventiei']),
      constatariLocFinding: pick(const <String>['constatari_loc_finding']),
      lucrariEfectuateDetailed: pick(const <String>['lucrari_efectuate_detailed']),
      observatiiTehnice: pick(const <String>['observatii_tehnice']),
      concluzie: pick(const <String>['concluzie']),
      recomandari: pick(const <String>['recomandari']),
      mentiuni: pick(const <String>['mentiuni']),
      materialeDetailed: pick(const <String>['materiale_detailed']),
      traseulPieselorDefecte: pick(const <String>['traseul_pieselor_defecte']),
      pvType: pick(const <String>['pv_type']).isEmpty ? 'constatare' : pick(const <String>['pv_type']),
    );
  }
}
