import 'package:uuid/uuid.dart';

// ── Linie planificată din ofertă (iun 2026) ────────────────────────────────
class JobLine {
  const JobLine({
    required this.id,
    required this.denumire,
    required this.um,
    required this.cantitateOferta,
    required this.cantitateReala,
    required this.pretUnitarOferta,
    required this.pretUnitarReal,
    required this.categorie,
    this.ofertaLineId = '',
  });

  final String id;
  final String ofertaLineId;
  final String denumire;
  final String um;
  final double cantitateOferta;
  final double cantitateReala;
  final double pretUnitarOferta;
  final double pretUnitarReal;
  final String categorie; // 'material' | 'manopera' | 'transport' | 'altul'

  double get totalOferta => cantitateOferta * pretUnitarOferta;
  double get totalReal => cantitateReala * pretUnitarReal;
  double get diferenta => totalReal - totalOferta;

  static JobLine fromOfertaLine({
    required String id,
    required String ofertaLineId,
    required String denumire,
    required String um,
    required double cantitate,
    required double pretUnitar,
    required String categorie,
  }) =>
      JobLine(
        id: id.isNotEmpty ? id : const Uuid().v4(),
        ofertaLineId: ofertaLineId,
        denumire: denumire,
        um: um,
        cantitateOferta: cantitate,
        cantitateReala: cantitate,
        pretUnitarOferta: pretUnitar,
        pretUnitarReal: pretUnitar,
        categorie: categorie,
      );

  JobLine copyWith({
    double? cantitateReala,
    double? pretUnitarReal,
  }) =>
      JobLine(
        id: id,
        ofertaLineId: ofertaLineId,
        denumire: denumire,
        um: um,
        cantitateOferta: cantitateOferta,
        cantitateReala: cantitateReala ?? this.cantitateReala,
        pretUnitarOferta: pretUnitarOferta,
        pretUnitarReal: pretUnitarReal ?? this.pretUnitarReal,
        categorie: categorie,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'oferta_line_id': ofertaLineId,
        'denumire': denumire,
        'um': um,
        'cantitate_oferta': cantitateOferta,
        'cantitate_reala': cantitateReala,
        'pret_unitar_oferta': pretUnitarOferta,
        'pret_unitar_real': pretUnitarReal,
        'categorie': categorie,
      };

  factory JobLine.fromMap(Map<String, dynamic> map) {
    double d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0;
    return JobLine(
      id: (map['id'] ?? '').toString(),
      ofertaLineId: (map['oferta_line_id'] ?? '').toString(),
      denumire: (map['denumire'] ?? map['name'] ?? '').toString(),
      um: (map['um'] ?? map['unit'] ?? 'buc').toString(),
      cantitateOferta: d(map['cantitate_oferta'] ?? map['cantitate']),
      cantitateReala: d(map['cantitate_reala'] ?? map['cantitate_oferta'] ?? map['cantitate']),
      pretUnitarOferta: d(map['pret_unitar_oferta'] ?? map['pret_unitar']),
      pretUnitarReal: d(map['pret_unitar_real'] ?? map['pret_unitar_oferta'] ?? map['pret_unitar']),
      categorie: (map['categorie'] ?? 'altul').toString(),
    );
  }
}

enum JobStatus {
  noua,
  ofertata,
  planificata,
  inExecutie,
  suspendata,
  finalizata,
  inchisa;

  String get value {
    switch (this) {
      case JobStatus.noua:
        return 'noua';
      case JobStatus.ofertata:
        return 'ofertata';
      case JobStatus.planificata:
        return 'planificata';
      case JobStatus.inExecutie:
        return 'in_executie';
      case JobStatus.suspendata:
        return 'suspendata';
      case JobStatus.finalizata:
        return 'finalizata';
      case JobStatus.inchisa:
        return 'inchisa';
    }
  }

  String get storageValue => value;

  String get label {
    switch (this) {
      case JobStatus.noua:
        return 'Nouă';
      case JobStatus.ofertata:
        return 'Ofertată';
      case JobStatus.planificata:
        return 'Planificată';
      case JobStatus.inExecutie:
        return 'În execuție';
      case JobStatus.suspendata:
        return 'Suspendată';
      case JobStatus.finalizata:
        return 'Finalizată';
      case JobStatus.inchisa:
        return 'Închisă';
    }
  }

  static JobStatus fromValue(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'ofertata':
        return JobStatus.ofertata;
      case 'planificata':
        return JobStatus.planificata;
      case 'in_executie':
        return JobStatus.inExecutie;
      case 'suspendata':
        return JobStatus.suspendata;
      case 'finalizata':
        return JobStatus.finalizata;
      case 'inchisa':
        return JobStatus.inchisa;
      case 'noua':
      default:
        return JobStatus.noua;
    }
  }
}

class BeneficiarySuppliedEquipment {
  const BeneficiarySuppliedEquipment({
    required this.id,
    required this.name,
    this.equipmentType = '',
    this.brand = '',
    this.model = '',
    this.serialNumber = '',
    this.quantity = 0,
    this.notes = '',
  });

  final String id;
  final String name;
  final String equipmentType;
  final String brand;
  final String model;
  final String serialNumber;
  final double quantity;
  final String notes;

  BeneficiarySuppliedEquipment copyWith({
    String? id,
    String? name,
    String? equipmentType,
    String? brand,
    String? model,
    String? serialNumber,
    double? quantity,
    String? notes,
  }) {
    return BeneficiarySuppliedEquipment(
      id: id ?? this.id,
      name: name ?? this.name,
      equipmentType: equipmentType ?? this.equipmentType,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'equipment_type': equipmentType,
        'brand': brand,
        'model': model,
        'serial_number': serialNumber,
        'quantity': quantity,
        'notes': notes,
      };

  factory BeneficiarySuppliedEquipment.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    return BeneficiarySuppliedEquipment(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? map['denumire'] ?? '').toString().trim(),
      equipmentType:
          (map['equipment_type'] ?? map['equipmentType'] ?? map['type'] ?? '')
              .toString()
              .trim(),
      brand: (map['brand'] ?? '').toString().trim(),
      model: (map['model'] ?? '').toString().trim(),
      serialNumber:
          (map['serial_number'] ?? map['serialNumber'] ?? map['serie'] ?? '')
              .toString()
              .trim(),
      quantity: parseDouble(map['quantity'] ?? map['cantitate']),
      notes: (map['notes'] ?? map['observatii'] ?? '').toString().trim(),
    );
  }
}

class BeneficiarySuppliedMaterial {
  const BeneficiarySuppliedMaterial({
    required this.id,
    required this.name,
    this.unit = '',
    this.quantity = 0,
    this.notes = '',
  });

  final String id;
  final String name;
  final String unit;
  final double quantity;
  final String notes;

  BeneficiarySuppliedMaterial copyWith({
    String? id,
    String? name,
    String? unit,
    double? quantity,
    String? notes,
  }) {
    return BeneficiarySuppliedMaterial(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'unit': unit,
        'quantity': quantity,
        'notes': notes,
      };

  factory BeneficiarySuppliedMaterial.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    return BeneficiarySuppliedMaterial(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? map['denumire'] ?? '').toString().trim(),
      unit: (map['unit'] ?? map['um'] ?? '').toString().trim(),
      quantity: parseDouble(map['quantity'] ?? map['cantitate']),
      notes: (map['notes'] ?? map['observatii'] ?? '').toString().trim(),
    );
  }
}

class JobRecord {
  const JobRecord({
    required this.id,
    required this.jobCode,
    required this.clientId,
    required this.title,
    required this.location,
    required this.city,
    required this.county,
    required this.contactPerson,
    required this.contactPhone,
    this.clientDepartmentId = '',
    this.clientDepartmentName = '',
    this.contactPersonId = '',
    this.contactPersonEmail = '',
    required this.description,
    required this.category,
    required this.status,
    required this.startDate,
    required this.dueDate,
    required this.closedDate,
    required this.estimatedValue,
    required this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.materials = const <Map<String, dynamic>>[],
    this.materialsUpdatedAt,
    this.detailsUpdatedAt,
    this.assignedTeamId = '',
    this.assignedTeamLabel = '',
    this.assignedTeamMembersLabel = '',
    this.documents = const <Map<String, dynamic>>[],
    this.laborEntries = const <Map<String, dynamic>>[],
    this.journalEntries = const <Map<String, dynamic>>[],
    this.checklist = const <String, bool>{},
    this.workTaskEntries = const <Map<String, dynamic>>[],
    this.jobPartners = const <Map<String, dynamic>>[],
    this.jobPartnerWorkers = const <Map<String, dynamic>>[],
    this.jobPartnerVehicles = const <Map<String, dynamic>>[],
    this.jobOwnVehicles = const <Map<String, dynamic>>[],
    this.beneficiarySuppliedEquipment = const <BeneficiarySuppliedEquipment>[],
    this.beneficiarySuppliedMaterials = const <BeneficiarySuppliedMaterial>[],
    this.sourceOfferId = '',
    this.sourceOfferNumber = '',
    this.sourceOfferTitle = '',
    this.createdByUserId = '',
    this.createdByUserEmail = '',
    this.timeEntries = const <Map<String, dynamic>>[],
    this.profitSharingPercent = 100.0,
    this.partnerId = '',
    this.partnerName = '',
    this.partnerProfitPercent = 0.0,
    this.partnerResources = 0.0,
    this.profitTaxPercent = 16.0,
    // Linii planificate din ofertă (iun 2026) — backward compatible
    this.liniiPlanificate = const <JobLine>[],
    this.totalOferta = 0.0,
    // Procente îngheţate din ofertă (iun 2026) — backward compatible
    this.regiePercent = 0.0,
    this.profitPercent = 0.0,
    this.vatPercent = 21.0,
    // SmartBill facturare (iun 2026) — backward compatible
    this.smartbillFacturaNumar = '',
    this.smartbillFacturaSerie = '',
  });

  final String id;
  final String jobCode;
  final String clientId;
  final String title;
  final String location;
  final String city;
  final String county;
  final String contactPerson;
  final String contactPhone;
  final String clientDepartmentId;
  final String clientDepartmentName;
  final String contactPersonId;
  final String contactPersonEmail;
  final String description;
  final String category;
  final JobStatus status;
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? closedDate;
  final double? estimatedValue;
  final String notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Map<String, dynamic>> materials;
  final DateTime? materialsUpdatedAt;
  final DateTime? detailsUpdatedAt;
  final String assignedTeamId;
  final String assignedTeamLabel;
  final String assignedTeamMembersLabel;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> laborEntries;
  final List<Map<String, dynamic>> journalEntries;
  final Map<String, bool> checklist;
  final List<Map<String, dynamic>> workTaskEntries;
  final List<Map<String, dynamic>> jobPartners;
  final List<Map<String, dynamic>> jobPartnerWorkers;
  final List<Map<String, dynamic>> jobPartnerVehicles;
  final List<Map<String, dynamic>> jobOwnVehicles;
  final List<BeneficiarySuppliedEquipment> beneficiarySuppliedEquipment;
  final List<BeneficiarySuppliedMaterial> beneficiarySuppliedMaterials;
  final String sourceOfferId;
  final String sourceOfferNumber;
  final String sourceOfferTitle;
  final String createdByUserId;
  final String createdByUserEmail;

  /// Clock-in/clock-out time entries per technician
  final List<Map<String, dynamic>> timeEntries;

  /// Profit sharing: percentage that goes to owner after corporate tax.
  /// The rest (100 - profitSharingPercent) is billable by partner.
  /// Default 100 means all profit stays with the company.
  final double profitSharingPercent;

  /// ID partener principal selectat pentru împărțire profit
  final String partnerId;

  /// Nume partener (denormalizat pentru afișare rapidă)
  final String partnerName;

  /// Procent din profit net care revine partenerului (0–100). Default 0.
  final double partnerProfitPercent;

  /// Resurse/costuri contribuite de partener în RON. Default 0.
  final double partnerResources;

  /// Rata impozit profit aplicată acestei lucrări (%). Default 16.
  final double profitTaxPercent;
  // Linii planificate din ofertă (iun 2026)
  final List<JobLine> liniiPlanificate;
  final double totalOferta;
  // Procente îngheţate din ofertă la conversie (iun 2026)
  final double regiePercent;
  final double profitPercent;
  final double vatPercent;
  // SmartBill (iun 2026)
  final String smartbillFacturaNumar;
  final String smartbillFacturaSerie;

  // Rotunjire la 10 — identic cu OfferLaborCalculator.roundPriceUpToTen
  static double _roundUpToTen(double v) {
    if (v <= 0) return v;
    return ((v / 10).ceil() * 10).toDouble();
  }

  /// Suma directă planificată (cantitateOferta × pretUnitarOferta), fără regie/profit
  double get subtotalDirectPlanificat =>
      liniiPlanificate.fold(0.0, (s, l) => s + l.totalOferta);

  /// Suma directă realizată (cantitateReala × pretUnitarReal), fără regie/profit
  double get subtotalDirectReal =>
      liniiPlanificate.fold(0.0, (s, l) => s + l.totalReal);

  /// Subtotal comercial planificat = subtotalDirect + regie + profit, rotunjit la 10
  double get subtotalComercialPlanificat {
    final direct = subtotalDirectPlanificat;
    final regie = direct * regiePercent / 100;
    final profit = direct * profitPercent / 100;
    return _roundUpToTen(direct + regie + profit);
  }

  /// Subtotal comercial realizat = subtotalDirectReal + regie + profit, rotunjit la 10
  /// Prețurile unitare rămân cele din ofertă (frozen), doar cantitățile pot varia
  double get subtotalComercialReal {
    final direct = subtotalDirectReal;
    final regie = direct * regiePercent / 100;
    final profit = direct * profitPercent / 100;
    return _roundUpToTen(direct + regie + profit);
  }

  double get totalReal =>
      liniiPlanificate.fold(0.0, (s, l) => s + l.totalReal);
  double get diferenta => totalReal - totalOferta;

  JobRecord copyWith({
    String? id,
    String? jobCode,
    String? clientId,
    String? title,
    String? location,
    String? city,
    String? county,
    String? contactPerson,
    String? contactPhone,
    String? clientDepartmentId,
    String? clientDepartmentName,
    String? contactPersonId,
    String? contactPersonEmail,
    String? description,
    String? category,
    JobStatus? status,
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? closedDate,
    double? estimatedValue,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? materials,
    DateTime? materialsUpdatedAt,
    DateTime? detailsUpdatedAt,
    String? assignedTeamId,
    String? assignedTeamLabel,
    String? assignedTeamMembersLabel,
    List<Map<String, dynamic>>? documents,
    List<Map<String, dynamic>>? laborEntries,
    List<Map<String, dynamic>>? journalEntries,
    Map<String, bool>? checklist,
    List<Map<String, dynamic>>? workTaskEntries,
    List<Map<String, dynamic>>? jobPartners,
    List<Map<String, dynamic>>? jobPartnerWorkers,
    List<Map<String, dynamic>>? jobPartnerVehicles,
    List<Map<String, dynamic>>? jobOwnVehicles,
    List<BeneficiarySuppliedEquipment>? beneficiarySuppliedEquipment,
    List<BeneficiarySuppliedMaterial>? beneficiarySuppliedMaterials,
    String? sourceOfferId,
    String? sourceOfferNumber,
    String? sourceOfferTitle,
    String? createdByUserId,
    String? createdByUserEmail,
    List<Map<String, dynamic>>? timeEntries,
    double? profitSharingPercent,
    String? partnerId,
    String? partnerName,
    double? partnerProfitPercent,
    double? partnerResources,
    double? profitTaxPercent,
    List<JobLine>? liniiPlanificate,
    double? totalOferta,
    double? regiePercent,
    double? profitPercent,
    double? vatPercent,
    String? smartbillFacturaNumar,
    String? smartbillFacturaSerie,
  }) {
    return JobRecord(
      id: id ?? this.id,
      jobCode: jobCode ?? this.jobCode,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      location: location ?? this.location,
      city: city ?? this.city,
      county: county ?? this.county,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      clientDepartmentId: clientDepartmentId ?? this.clientDepartmentId,
      clientDepartmentName: clientDepartmentName ?? this.clientDepartmentName,
      contactPersonId: contactPersonId ?? this.contactPersonId,
      contactPersonEmail: contactPersonEmail ?? this.contactPersonEmail,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      closedDate: closedDate ?? this.closedDate,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      materials: materials ?? this.materials,
      materialsUpdatedAt: materialsUpdatedAt ?? this.materialsUpdatedAt,
      detailsUpdatedAt: detailsUpdatedAt ?? this.detailsUpdatedAt,
      assignedTeamId: assignedTeamId ?? this.assignedTeamId,
      assignedTeamLabel: assignedTeamLabel ?? this.assignedTeamLabel,
      assignedTeamMembersLabel:
          assignedTeamMembersLabel ?? this.assignedTeamMembersLabel,
      documents: documents ?? this.documents,
      laborEntries: laborEntries ?? this.laborEntries,
      journalEntries: journalEntries ?? this.journalEntries,
      checklist: checklist ?? this.checklist,
      workTaskEntries: workTaskEntries ?? this.workTaskEntries,
      jobPartners: jobPartners ?? this.jobPartners,
      jobPartnerWorkers: jobPartnerWorkers ?? this.jobPartnerWorkers,
      jobPartnerVehicles: jobPartnerVehicles ?? this.jobPartnerVehicles,
      jobOwnVehicles: jobOwnVehicles ?? this.jobOwnVehicles,
      beneficiarySuppliedEquipment:
          beneficiarySuppliedEquipment ?? this.beneficiarySuppliedEquipment,
      beneficiarySuppliedMaterials:
          beneficiarySuppliedMaterials ?? this.beneficiarySuppliedMaterials,
      sourceOfferId: sourceOfferId ?? this.sourceOfferId,
      sourceOfferNumber: sourceOfferNumber ?? this.sourceOfferNumber,
      sourceOfferTitle: sourceOfferTitle ?? this.sourceOfferTitle,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByUserEmail: createdByUserEmail ?? this.createdByUserEmail,
      timeEntries: timeEntries ?? this.timeEntries,
      profitSharingPercent: profitSharingPercent ?? this.profitSharingPercent,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      partnerProfitPercent: partnerProfitPercent ?? this.partnerProfitPercent,
      partnerResources: partnerResources ?? this.partnerResources,
      profitTaxPercent: profitTaxPercent ?? this.profitTaxPercent,
      liniiPlanificate: liniiPlanificate ?? this.liniiPlanificate,
      totalOferta: totalOferta ?? this.totalOferta,
      regiePercent: regiePercent ?? this.regiePercent,
      profitPercent: profitPercent ?? this.profitPercent,
      vatPercent: vatPercent ?? this.vatPercent,
      smartbillFacturaNumar:
          smartbillFacturaNumar ?? this.smartbillFacturaNumar,
      smartbillFacturaSerie:
          smartbillFacturaSerie ?? this.smartbillFacturaSerie,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'job_code': jobCode,
      'client_id': clientId,
      'title': title,
      'location': location,
      'city': city,
      'county': county,
      'contact_person': contactPerson,
      'contact_phone': contactPhone,
      'client_department_id': clientDepartmentId,
      'client_department_name': clientDepartmentName,
      'contact_person_id': contactPersonId,
      'contact_person_email': contactPersonEmail,
      'description': description,
      'category': category,
      'status': status.value,
      'start_date': startDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'closed_date': closedDate?.toIso8601String(),
      'estimated_value': estimatedValue,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'materials': materials,
      'materials_updated_at': materialsUpdatedAt?.toIso8601String(),
      'details_updated_at': detailsUpdatedAt?.toIso8601String(),
      'assigned_team_id': assignedTeamId,
      'assigned_team_label': assignedTeamLabel,
      'assigned_team_members_label': assignedTeamMembersLabel,
      'documents': documents,
      'labor_entries': laborEntries,
      'journal_entries': journalEntries,
      'checklist': checklist,
      'work_task_entries': workTaskEntries,
      'job_partners': jobPartners,
      'job_partner_workers': jobPartnerWorkers,
      'job_partner_vehicles': jobPartnerVehicles,
      'job_own_vehicles': jobOwnVehicles,
      'beneficiary_supplied_equipment': beneficiarySuppliedEquipment
          .map((entry) => entry.toMap())
          .toList(growable: false),
      'beneficiary_supplied_materials': beneficiarySuppliedMaterials
          .map((entry) => entry.toMap())
          .toList(growable: false),
      'source_offer_id': sourceOfferId,
      'source_offer_number': sourceOfferNumber,
      'source_offer_title': sourceOfferTitle,
      'created_by_user_id': createdByUserId,
      'created_by_user_email': createdByUserEmail,
      'time_entries': timeEntries,
      'profit_sharing_percent': profitSharingPercent,
      'partner_id': partnerId,
      'partner_name': partnerName,
      'partner_profit_percent': partnerProfitPercent,
      'partner_resources': partnerResources,
      'profit_tax_percent': profitTaxPercent,
      'linii_planificate': liniiPlanificate.map((l) => l.toMap()).toList(),
      'total_oferta': totalOferta,
      'regie_percent': regiePercent,
      'profit_percent': profitPercent,
      'vat_percent': vatPercent,
      'smartbill_factura_numar': smartbillFacturaNumar,
      'smartbill_factura_serie': smartbillFacturaSerie,
    };
  }

  factory JobRecord.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      final text = raw.toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    double? parseDouble(dynamic raw) {
      if (raw == null) return null;
      if (raw is num) return raw.toDouble();
      final text = raw.toString().trim().replaceAll(',', '.');
      if (text.isEmpty) return null;
      return double.tryParse(text);
    }

    final now = DateTime.now();
    final id = (map['id'] ?? '').toString().trim();
    List<Map<String, dynamic>> parseRows(dynamic raw) {
      if (raw is! List) return const <Map<String, dynamic>>[];
      return raw
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }

    Map<String, bool> parseChecklist(dynamic raw) {
      if (raw is! Map) return const <String, bool>{};
      final out = <String, bool>{};
      for (final entry in raw.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) continue;
        out[key] = entry.value == true;
      }
      return out;
    }

    List<T> parseTypedList<T>(
      dynamic raw,
      T Function(Map<String, dynamic> map) parser,
    ) {
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map>()
          .map((row) => parser(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }

    return JobRecord(
      id: id.isEmpty ? 'job-${now.microsecondsSinceEpoch}' : id,
      jobCode: (map['job_code'] ?? map['jobCode'] ?? '').toString().trim(),
      clientId: (map['client_id'] ?? map['clientId'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      county: (map['county'] ?? '').toString(),
      contactPerson:
          (map['contact_person'] ?? map['contactPerson'] ?? '').toString(),
      contactPhone:
          (map['contact_phone'] ?? map['contactPhone'] ?? '').toString(),
      clientDepartmentId:
          (map['client_department_id'] ?? map['clientDepartmentId'] ?? '')
              .toString(),
      clientDepartmentName:
          (map['client_department_name'] ?? map['clientDepartmentName'] ?? '')
              .toString(),
      contactPersonId:
          (map['contact_person_id'] ?? map['contactPersonId'] ?? '').toString(),
      contactPersonEmail:
          (map['contact_person_email'] ?? map['contactPersonEmail'] ?? '')
              .toString(),
      description: (map['description'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      status: JobStatus.fromValue(map['status']?.toString()),
      startDate: parseDate(map['start_date'] ?? map['startDate']),
      dueDate: parseDate(map['due_date'] ?? map['dueDate']),
      closedDate: parseDate(map['closed_date'] ?? map['closedDate']),
      estimatedValue:
          parseDouble(map['estimated_value'] ?? map['estimatedValue']),
      notes: (map['notes'] ?? '').toString(),
      isActive: map['is_active'] == null
          ? (map['isActive'] is bool ? map['isActive'] as bool : true)
          : map['is_active'] == true,
      createdAt: parseDate(map['created_at'] ?? map['createdAt']) ?? now,
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']) ?? now,
      materials: parseRows(map['materials'] ?? map['materialsSnapshot']),
      materialsUpdatedAt: parseDate(
        map['materials_updated_at'] ?? map['materialsUpdatedAt'],
      ),
      detailsUpdatedAt: parseDate(
        map['details_updated_at'] ?? map['detailsUpdatedAt'],
      ),
      assignedTeamId:
          (map['assigned_team_id'] ?? map['assignedTeamId'] ?? '').toString(),
      assignedTeamLabel:
          (map['assigned_team_label'] ?? map['assignedTeamLabel'] ?? '')
              .toString(),
      assignedTeamMembersLabel: (map['assigned_team_members_label'] ??
              map['assignedTeamMembersLabel'] ??
              '')
          .toString(),
      documents: parseRows(map['documents']),
      laborEntries: parseRows(map['labor_entries'] ?? map['laborEntries']),
      journalEntries:
          parseRows(map['journal_entries'] ?? map['journalEntries']),
      checklist: parseChecklist(map['checklist']),
      workTaskEntries:
          parseRows(map['work_task_entries'] ?? map['workTaskEntries']),
      jobPartners: parseRows(map['job_partners'] ?? map['jobPartners']),
      jobPartnerWorkers: parseRows(
        map['job_partner_workers'] ?? map['jobPartnerWorkers'],
      ),
      jobPartnerVehicles: parseRows(
        map['job_partner_vehicles'] ?? map['jobPartnerVehicles'],
      ),
      jobOwnVehicles: parseRows(
        map['job_own_vehicles'] ?? map['jobOwnVehicles'],
      ),
      beneficiarySuppliedEquipment: parseTypedList(
        map['beneficiary_supplied_equipment'] ??
            map['beneficiarySuppliedEquipment'],
        BeneficiarySuppliedEquipment.fromMap,
      ),
      beneficiarySuppliedMaterials: parseTypedList(
        map['beneficiary_supplied_materials'] ??
            map['beneficiarySuppliedMaterials'],
        BeneficiarySuppliedMaterial.fromMap,
      ),
      sourceOfferId:
          (map['source_offer_id'] ?? map['sourceOfferId'] ?? '').toString(),
      sourceOfferNumber:
          (map['source_offer_number'] ?? map['sourceOfferNumber'] ?? '')
              .toString(),
      sourceOfferTitle:
          (map['source_offer_title'] ?? map['sourceOfferTitle'] ?? '')
              .toString(),
      createdByUserId:
          (map['created_by_user_id'] ?? map['createdByUserId'] ?? '')
              .toString(),
      createdByUserEmail:
          (map['created_by_user_email'] ?? map['createdByUserEmail'] ?? '')
              .toString(),
      timeEntries: parseRows(map['time_entries'] ?? map['timeEntries']),
      profitSharingPercent: parseDouble(
              map['profit_sharing_percent'] ?? map['profitSharingPercent']) ??
          100.0,
      partnerId:
          (map['partner_id'] ?? map['partnerId'] ?? '').toString().trim(),
      partnerName:
          (map['partner_name'] ?? map['partnerName'] ?? '').toString().trim(),
      partnerProfitPercent: parseDouble(
              map['partner_profit_percent'] ?? map['partnerProfitPercent']) ??
          0.0,
      partnerResources:
          parseDouble(map['partner_resources'] ?? map['partnerResources']) ??
              0.0,
      profitTaxPercent:
          parseDouble(map['profit_tax_percent'] ?? map['profitTaxPercent']) ??
              16.0,
      liniiPlanificate: (() {
        final raw = map['linii_planificate'] ?? map['liniiPlanificate'];
        if (raw is! List) return const <JobLine>[];
        return raw
            .whereType<Map>()
            .map((m) => JobLine.fromMap(Map<String, dynamic>.from(m)))
            .toList(growable: false);
      })(),
      totalOferta:
          parseDouble(map['total_oferta'] ?? map['totalOferta']) ?? 0.0,
      regiePercent:
          parseDouble(map['regie_percent'] ?? map['regiePercent']) ?? 0.0,
      profitPercent:
          parseDouble(map['profit_percent'] ?? map['profitPercent']) ?? 0.0,
      vatPercent:
          parseDouble(map['vat_percent'] ?? map['vatPercent']) ?? 21.0,
      smartbillFacturaNumar:
          (map['smartbill_factura_numar'] ?? map['smartbillFacturaNumar'] ?? '').toString(),
      smartbillFacturaSerie:
          (map['smartbill_factura_serie'] ?? map['smartbillFacturaSerie'] ?? '').toString(),
    );
  }
}
