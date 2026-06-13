enum ComplaintVisitType {
  constatare,
  interventie,
  revenire,
  verificare,
  inchidere;

  String get value {
    switch (this) {
      case ComplaintVisitType.constatare:
        return 'constatare';
      case ComplaintVisitType.interventie:
        return 'interventie';
      case ComplaintVisitType.revenire:
        return 'revenire';
      case ComplaintVisitType.verificare:
        return 'verificare';
      case ComplaintVisitType.inchidere:
        return 'inchidere';
    }
  }

  String get label {
    switch (this) {
      case ComplaintVisitType.constatare:
        return 'Constatare';
      case ComplaintVisitType.interventie:
        return 'Interventie';
      case ComplaintVisitType.revenire:
        return 'Revenire';
      case ComplaintVisitType.verificare:
        return 'Verificare';
      case ComplaintVisitType.inchidere:
        return 'Închidere';
    }
  }

  static ComplaintVisitType? fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final item in ComplaintVisitType.values) {
      if (item.value == value) {
        return item;
      }
    }
    return null;
  }
}

enum ComplaintVisitOutcome {
  rezolvata,
  necesitaPiese,
  necesitaRevenire,
  monitorizare,
  clientIndisponibil,
  faraDefectConstatat,
  amanata;

  String get value {
    switch (this) {
      case ComplaintVisitOutcome.rezolvata:
        return 'rezolvata';
      case ComplaintVisitOutcome.necesitaPiese:
        return 'necesita_piese';
      case ComplaintVisitOutcome.necesitaRevenire:
        return 'necesita_revenire';
      case ComplaintVisitOutcome.monitorizare:
        return 'monitorizare';
      case ComplaintVisitOutcome.clientIndisponibil:
        return 'client_indisponibil';
      case ComplaintVisitOutcome.faraDefectConstatat:
        return 'fara_defect_constatat';
      case ComplaintVisitOutcome.amanata:
        return 'amanata';
    }
  }

  String get label {
    switch (this) {
      case ComplaintVisitOutcome.rezolvata:
        return 'Rezolvata';
      case ComplaintVisitOutcome.necesitaPiese:
        return 'Necesita piese';
      case ComplaintVisitOutcome.necesitaRevenire:
        return 'Necesita revenire';
      case ComplaintVisitOutcome.monitorizare:
        return 'Monitorizare';
      case ComplaintVisitOutcome.clientIndisponibil:
        return 'Client indisponibil';
      case ComplaintVisitOutcome.faraDefectConstatat:
        return 'Fara defect constatat';
      case ComplaintVisitOutcome.amanata:
        return 'Amanata';
    }
  }

  static ComplaintVisitOutcome? fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final item in ComplaintVisitOutcome.values) {
      if (item.value == value) {
        return item;
      }
    }
    return null;
  }
}

class AppointmentLinkedDocument {
  const AppointmentLinkedDocument({
    required this.label,
    required this.filePath,
    this.fileName = '',
  });

  final String label;
  final String filePath;
  final String fileName;

  AppointmentLinkedDocument copyWith({
    String? label,
    String? filePath,
    String? fileName,
  }) {
    return AppointmentLinkedDocument(
      label: label ?? this.label,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'file_path': filePath,
      'file_name': fileName,
    };
  }

  factory AppointmentLinkedDocument.fromMap(Map<String, dynamic> map) {
    return AppointmentLinkedDocument(
      label: (map['label'] ?? '').toString(),
      filePath: (map['file_path'] ?? map['filePath'] ?? '').toString(),
      fileName: (map['file_name'] ?? map['fileName'] ?? '').toString(),
    );
  }
}

enum AppointmentFinancialStatus {
  neincasata,
  partial,
  incasata,
  facturareLunara,
  conformContract;

  String get value {
    switch (this) {
      case AppointmentFinancialStatus.neincasata:
        return 'neincasata';
      case AppointmentFinancialStatus.partial:
        return 'partial';
      case AppointmentFinancialStatus.incasata:
        return 'incasata';
      case AppointmentFinancialStatus.facturareLunara:
        return 'facturare_lunara';
      case AppointmentFinancialStatus.conformContract:
        return 'conform_contract';
    }
  }

  String get label {
    switch (this) {
      case AppointmentFinancialStatus.neincasata:
        return 'Neincasata';
      case AppointmentFinancialStatus.partial:
        return 'Incasata partial';
      case AppointmentFinancialStatus.incasata:
        return 'Incasata';
      case AppointmentFinancialStatus.facturareLunara:
        return 'Facturare lunara';
      case AppointmentFinancialStatus.conformContract:
        return 'Conform contract';
    }
  }

  static AppointmentFinancialStatus fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final item in AppointmentFinancialStatus.values) {
      if (item.value == value) {
        return item;
      }
    }
    return AppointmentFinancialStatus.neincasata;
  }
}

enum PartnerPaymentStatus {
  neplatit,
  platitPartial,
  platit,
  conformContract;

  String get value {
    switch (this) {
      case PartnerPaymentStatus.neplatit:
        return 'neplatit';
      case PartnerPaymentStatus.platitPartial:
        return 'platit_partial';
      case PartnerPaymentStatus.platit:
        return 'platit';
      case PartnerPaymentStatus.conformContract:
        return 'conform_contract';
    }
  }

  String get label {
    switch (this) {
      case PartnerPaymentStatus.neplatit:
        return 'Neplatit';
      case PartnerPaymentStatus.platitPartial:
        return 'Platit parțial';
      case PartnerPaymentStatus.platit:
        return 'Platit';
      case PartnerPaymentStatus.conformContract:
        return 'Conform contract';
    }
  }

  static PartnerPaymentStatus fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final item in PartnerPaymentStatus.values) {
      if (item.value == value) return item;
    }
    return PartnerPaymentStatus.neplatit;
  }
}

class AppointmentMaterialUsageLine {
  const AppointmentMaterialUsageLine({
    required this.id,
    required this.materialId,
    required this.name,
    required this.unit,
    required this.quantity,
    this.unitCost = 0,
    this.isVariableLength = false,
    this.quantityPerLinearMeter = 0,
  });

  final String id;
  final String materialId;
  final String name;
  final String unit;
  final double quantity;
  final double unitCost;
  final bool isVariableLength;
  final double quantityPerLinearMeter;

  AppointmentMaterialUsageLine copyWith({
    String? id,
    String? materialId,
    String? name,
    String? unit,
    double? quantity,
    double? unitCost,
    bool? isVariableLength,
    double? quantityPerLinearMeter,
  }) {
    return AppointmentMaterialUsageLine(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      isVariableLength: isVariableLength ?? this.isVariableLength,
      quantityPerLinearMeter:
          quantityPerLinearMeter ?? this.quantityPerLinearMeter,
    );
  }

  double get totalCost => quantity * unitCost;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'material_id': materialId,
      'name': name,
      'unit': unit,
      'quantity': quantity,
      'unit_cost': unitCost,
      'is_variable_length': isVariableLength,
      'quantity_per_linear_meter': quantityPerLinearMeter,
    };
  }

  factory AppointmentMaterialUsageLine.fromMap(Map<String, dynamic> map) {
    return AppointmentMaterialUsageLine(
      id: (map['id'] ?? '').toString(),
      materialId: (map['material_id'] ?? map['materialId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      unit: (map['unit'] ?? '').toString(),
      quantity: _parseDouble(map['quantity']),
      unitCost: _parseDouble(map['unit_cost'] ?? map['unitCost']),
      isVariableLength:
          map['is_variable_length'] == true || map['isVariableLength'] == true,
      quantityPerLinearMeter: _parseDouble(
        map['quantity_per_linear_meter'] ?? map['quantityPerLinearMeter'],
      ),
    );
  }
}

class AppointmentMaterialUsage {
  const AppointmentMaterialUsage({
    this.kitTemplateId = '',
    this.kitTemplateName = '',
    this.linearMetersUsed = 0,
    this.lines = const <AppointmentMaterialUsageLine>[],
    this.notes = '',
    this.facturabilPartener = true,
  });

  final String kitTemplateId;
  final String kitTemplateName;
  final double linearMetersUsed;
  final List<AppointmentMaterialUsageLine> lines;
  final String notes;
  /// Dacă true (default), costul materialelor/kitului se recuperează de la
  /// partenerul beneficiar și apare în soldul "De încasat". Dacă false,
  /// materialele sunt suportate intern — nu modifică soldul partenerului.
  final bool facturabilPartener;

  AppointmentMaterialUsage copyWith({
    String? kitTemplateId,
    String? kitTemplateName,
    double? linearMetersUsed,
    List<AppointmentMaterialUsageLine>? lines,
    String? notes,
    bool? facturabilPartener,
  }) {
    return AppointmentMaterialUsage(
      kitTemplateId: kitTemplateId ?? this.kitTemplateId,
      kitTemplateName: kitTemplateName ?? this.kitTemplateName,
      linearMetersUsed: linearMetersUsed ?? this.linearMetersUsed,
      lines: lines ?? this.lines,
      notes: notes ?? this.notes,
      facturabilPartener: facturabilPartener ?? this.facturabilPartener,
    );
  }

  double get totalCost =>
      lines.fold<double>(0, (sum, line) => sum + line.totalCost);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'kit_template_id': kitTemplateId,
      'kit_template_name': kitTemplateName,
      'linear_meters_used': linearMetersUsed,
      'lines': lines.map((line) => line.toMap()).toList(growable: false),
      'notes': notes,
      'facturabil_partener': facturabilPartener,
    };
  }

  factory AppointmentMaterialUsage.fromMap(Map<String, dynamic> map) {
    final rawLines = map['lines'];
    final lines = rawLines is List
        ? rawLines
            .map((item) {
              if (item is Map<String, dynamic>) {
                return AppointmentMaterialUsageLine.fromMap(item);
              }
              if (item is Map) {
                return AppointmentMaterialUsageLine.fromMap(
                  Map<String, dynamic>.from(item),
                );
              }
              return null;
            })
            .whereType<AppointmentMaterialUsageLine>()
            .toList(growable: false)
        : const <AppointmentMaterialUsageLine>[];
    return AppointmentMaterialUsage(
      kitTemplateId:
          (map['kit_template_id'] ?? map['kitTemplateId'] ?? '').toString(),
      kitTemplateName:
          (map['kit_template_name'] ?? map['kitTemplateName'] ?? '').toString(),
      linearMetersUsed: _parseDouble(
        map['linear_meters_used'] ?? map['linearMetersUsed'],
      ),
      lines: lines,
      notes: (map['notes'] ?? '').toString(),
      // Backward compat: documente vechi fără câmp → default true (comportament neschimbat)
      facturabilPartener: map['facturabil_partener'] != false,
    );
  }
}

class Appointment {
  const Appointment({
    required this.id,
    required this.clientId,
    this.clientName = '',
    this.contractingClientId = '',
    this.contractingClientName = '',
    this.contactPerson = '',
    this.contactPhone = '',
    this.contactEmail = '',
    required this.title,
    required this.location,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    this.startDateTime,
    this.endDateTime,
    required this.type,
    required this.priority,
    this.colorCode = '',
    required this.status,
    this.jobId = '',
    this.complaintId = '',
    this.complaintNumber = '',
    this.teamId = '',
    this.assignedTeamIds = const <String>[],
    this.assignedUserId = '',
    this.assignedUserEmail = '',
    this.assignedEmployeeIds = const <String>[],
    this.vehicleId = '',
    this.complaintVisitType,
    this.complaintVisitOutcome,
    this.postponementReason = '',
    this.rescheduledFromStartDateTime,
    this.rescheduledFromEndDateTime,
    this.notes = '',
    this.linkedDocuments = const <AppointmentLinkedDocument>[],
    this.recurrenceRule = 'none',
    this.recurringGroupId = '',
    this.forPartnerId = '',
    this.forPartnerName = '',
    this.executingPartnerId = '',
    this.executingPartnerName = '',
    this.equipmentDescription = '',
    this.interventionPrice = 0,
    this.interventionPriceCurrency = 'RON',
    this.adminCollectedAmount = 0,
    this.adminCollectedCurrency = 'RON',
    this.adminFinancialStatus = AppointmentFinancialStatus.neincasata,
    this.adminDueDate,
    this.adminFinancialNotes = '',
    this.materialUsage = const AppointmentMaterialUsage(),
    this.executingPartnerCommission = 0,
    this.executingPartnerCommissionCurrency = 'RON',
    this.executingPartnerPaymentStatus = PartnerPaymentStatus.neplatit,
    this.executingPartnerPaymentDate,
    this.executingPartnerPaymentNotes = '',
    this.forPartnerInvoiceAmount = 0,
    this.forPartnerInvoiceCurrency = 'RON',
    this.forPartnerReceiveStatus = PartnerPaymentStatus.neplatit,
    this.forPartnerReceiveDate,
    this.forPartnerReceiveNotes = '',
    this.clientPhoneNumbers = const <String>[],
    this.stocScazut = false,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String contractingClientId;
  final String contractingClientName;
  final String contactPerson;
  final String contactPhone;
  final String contactEmail;
  final String title;
  final String location;
  final DateTime scheduledDate;
  final String startTime;
  final String endTime;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final String teamId;
  final List<String> assignedTeamIds;
  final String assignedUserId;
  final String assignedUserEmail;
  final List<String> assignedEmployeeIds;
  final String vehicleId;
  final ComplaintVisitType? complaintVisitType;
  final ComplaintVisitOutcome? complaintVisitOutcome;
  final String postponementReason;
  final DateTime? rescheduledFromStartDateTime;
  final DateTime? rescheduledFromEndDateTime;
  final String type;
  final String priority;
  final String colorCode;
  final String status;
  final String jobId;
  final String complaintId;
  final String complaintNumber;
  final String notes;
  final List<AppointmentLinkedDocument> linkedDocuments;

  /// Recurrence rule: 'none', 'annual'
  final String recurrenceRule;

  /// Links all instances of the same recurring series
  final String recurringGroupId;

  /// Partner for whom the work is done (when working on behalf of a partner)
  final String forPartnerId;
  final String forPartnerName;

  /// Partner who was sent to execute the work
  final String executingPartnerId;
  final String executingPartnerName;

  /// Equipment being serviced / installed
  final String equipmentDescription;

  /// Price of the intervention (visible to employees for on-site collection)
  final double interventionPrice;
  final String interventionPriceCurrency;
  final double adminCollectedAmount;
  final String adminCollectedCurrency;
  final AppointmentFinancialStatus adminFinancialStatus;
  final DateTime? adminDueDate;
  final String adminFinancialNotes;
  final AppointmentMaterialUsage materialUsage;

  /// Comision datorat partenerului care execută lucrarea pentru tine
  final double executingPartnerCommission;
  final String executingPartnerCommissionCurrency;
  final PartnerPaymentStatus executingPartnerPaymentStatus;
  final DateTime? executingPartnerPaymentDate;
  final String executingPartnerPaymentNotes;

  /// Sumă de încasat de la partenerul pentru care lucrezi (subcontractare)
  final double forPartnerInvoiceAmount;
  final String forPartnerInvoiceCurrency;
  final PartnerPaymentStatus forPartnerReceiveStatus;
  final DateTime? forPartnerReceiveDate;
  final String forPartnerReceiveNotes;
  final List<String> clientPhoneNumbers;
  /// True dacă stocul a fost deja scăzut pentru materialele acestei programări.
  /// Previne scăderi duble la editări ulterioare.
  final bool stocScazut;

  Appointment copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? contractingClientId,
    String? contractingClientName,
    String? contactPerson,
    String? contactPhone,
    String? contactEmail,
    String? title,
    String? location,
    DateTime? scheduledDate,
    String? startTime,
    String? endTime,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? teamId,
    List<String>? assignedTeamIds,
    String? assignedUserId,
    String? assignedUserEmail,
    List<String>? assignedEmployeeIds,
    String? vehicleId,
    ComplaintVisitType? complaintVisitType,
    bool clearComplaintVisitType = false,
    ComplaintVisitOutcome? complaintVisitOutcome,
    bool clearComplaintVisitOutcome = false,
    String? postponementReason,
    DateTime? rescheduledFromStartDateTime,
    bool clearRescheduledFromStartDateTime = false,
    DateTime? rescheduledFromEndDateTime,
    bool clearRescheduledFromEndDateTime = false,
    String? type,
    String? priority,
    String? colorCode,
    String? status,
    String? jobId,
    String? complaintId,
    String? complaintNumber,
    String? notes,
    List<AppointmentLinkedDocument>? linkedDocuments,
    String? recurrenceRule,
    String? recurringGroupId,
    String? forPartnerId,
    String? forPartnerName,
    String? executingPartnerId,
    String? executingPartnerName,
    String? equipmentDescription,
    double? interventionPrice,
    String? interventionPriceCurrency,
    double? adminCollectedAmount,
    String? adminCollectedCurrency,
    AppointmentFinancialStatus? adminFinancialStatus,
    DateTime? adminDueDate,
    bool clearAdminDueDate = false,
    String? adminFinancialNotes,
    AppointmentMaterialUsage? materialUsage,
    double? executingPartnerCommission,
    String? executingPartnerCommissionCurrency,
    PartnerPaymentStatus? executingPartnerPaymentStatus,
    DateTime? executingPartnerPaymentDate,
    bool clearExecutingPartnerPaymentDate = false,
    String? executingPartnerPaymentNotes,
    double? forPartnerInvoiceAmount,
    String? forPartnerInvoiceCurrency,
    PartnerPaymentStatus? forPartnerReceiveStatus,
    DateTime? forPartnerReceiveDate,
    bool clearForPartnerReceiveDate = false,
    String? forPartnerReceiveNotes,
    List<String>? clientPhoneNumbers,
    bool? stocScazut,
  }) {
    return Appointment(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      contractingClientId: contractingClientId ?? this.contractingClientId,
      contractingClientName:
          contractingClientName ?? this.contractingClientName,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      title: title ?? this.title,
      location: location ?? this.location,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      teamId: teamId ?? this.teamId,
      assignedTeamIds: assignedTeamIds ?? this.assignedTeamIds,
      assignedUserId: assignedUserId ?? this.assignedUserId,
      assignedUserEmail: assignedUserEmail ?? this.assignedUserEmail,
      assignedEmployeeIds: assignedEmployeeIds ?? this.assignedEmployeeIds,
      vehicleId: vehicleId ?? this.vehicleId,
      complaintVisitType: clearComplaintVisitType
          ? null
          : (complaintVisitType ?? this.complaintVisitType),
      complaintVisitOutcome: clearComplaintVisitOutcome
          ? null
          : (complaintVisitOutcome ?? this.complaintVisitOutcome),
      postponementReason: postponementReason ?? this.postponementReason,
      rescheduledFromStartDateTime: clearRescheduledFromStartDateTime
          ? null
          : (rescheduledFromStartDateTime ?? this.rescheduledFromStartDateTime),
      rescheduledFromEndDateTime: clearRescheduledFromEndDateTime
          ? null
          : (rescheduledFromEndDateTime ?? this.rescheduledFromEndDateTime),
      type: type ?? this.type,
      priority: priority ?? this.priority,
      colorCode: colorCode ?? this.colorCode,
      status: status ?? this.status,
      jobId: jobId ?? this.jobId,
      complaintId: complaintId ?? this.complaintId,
      complaintNumber: complaintNumber ?? this.complaintNumber,
      notes: notes ?? this.notes,
      linkedDocuments: linkedDocuments ?? this.linkedDocuments,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurringGroupId: recurringGroupId ?? this.recurringGroupId,
      forPartnerId: forPartnerId ?? this.forPartnerId,
      forPartnerName: forPartnerName ?? this.forPartnerName,
      executingPartnerId: executingPartnerId ?? this.executingPartnerId,
      executingPartnerName: executingPartnerName ?? this.executingPartnerName,
      equipmentDescription: equipmentDescription ?? this.equipmentDescription,
      interventionPrice: interventionPrice ?? this.interventionPrice,
      interventionPriceCurrency:
          interventionPriceCurrency ?? this.interventionPriceCurrency,
      adminCollectedAmount: adminCollectedAmount ?? this.adminCollectedAmount,
      adminCollectedCurrency:
          adminCollectedCurrency ?? this.adminCollectedCurrency,
      adminFinancialStatus:
          adminFinancialStatus ?? this.adminFinancialStatus,
      adminDueDate:
          clearAdminDueDate ? null : (adminDueDate ?? this.adminDueDate),
      adminFinancialNotes: adminFinancialNotes ?? this.adminFinancialNotes,
      materialUsage: materialUsage ?? this.materialUsage,
      executingPartnerCommission:
          executingPartnerCommission ?? this.executingPartnerCommission,
      executingPartnerCommissionCurrency: executingPartnerCommissionCurrency ??
          this.executingPartnerCommissionCurrency,
      executingPartnerPaymentStatus:
          executingPartnerPaymentStatus ?? this.executingPartnerPaymentStatus,
      executingPartnerPaymentDate: clearExecutingPartnerPaymentDate
          ? null
          : (executingPartnerPaymentDate ?? this.executingPartnerPaymentDate),
      executingPartnerPaymentNotes:
          executingPartnerPaymentNotes ?? this.executingPartnerPaymentNotes,
      forPartnerInvoiceAmount:
          forPartnerInvoiceAmount ?? this.forPartnerInvoiceAmount,
      forPartnerInvoiceCurrency:
          forPartnerInvoiceCurrency ?? this.forPartnerInvoiceCurrency,
      forPartnerReceiveStatus:
          forPartnerReceiveStatus ?? this.forPartnerReceiveStatus,
      forPartnerReceiveDate: clearForPartnerReceiveDate
          ? null
          : (forPartnerReceiveDate ?? this.forPartnerReceiveDate),
      forPartnerReceiveNotes:
          forPartnerReceiveNotes ?? this.forPartnerReceiveNotes,
      clientPhoneNumbers: clientPhoneNumbers ?? this.clientPhoneNumbers,
      stocScazut: stocScazut ?? this.stocScazut,
    );
  }

  DateTime get effectiveStartDateTime =>
      startDateTime ?? _combineDateAndTime(scheduledDate, startTime);

  DateTime get effectiveEndDateTime {
    final explicitEnd = endDateTime;
    if (explicitEnd != null) {
      return explicitEnd.isBefore(effectiveStartDateTime)
          ? effectiveStartDateTime
          : explicitEnd;
    }
    final fallbackEnd = _combineDateAndTime(scheduledDate, endTime);
    if (!fallbackEnd.isBefore(effectiveStartDateTime)) {
      return fallbackEnd;
    }
    return effectiveStartDateTime;
  }

  Duration get effectiveDuration =>
      effectiveEndDateTime.difference(effectiveStartDateTime);

  double get estimatedMaterialsCost => materialUsage.totalCost;

  double get estimatedProfit =>
      adminCollectedAmount > 0 ? adminCollectedAmount - estimatedMaterialsCost : 0;

  List<String> get resolvedAssignedTeamIds {
    final values = <String>[];
    void addValue(String value) {
      final id = value.trim();
      if (id.isEmpty || values.contains(id)) {
        return;
      }
      values.add(id);
    }

    for (final value in assignedTeamIds) {
      addValue(value);
    }
    addValue(teamId);
    return List<String>.unmodifiable(values);
  }

  String get primaryAssignedTeamId {
    final resolved = resolvedAssignedTeamIds;
    if (resolved.isEmpty) {
      return teamId.trim();
    }
    return resolved.first;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'client_name': clientName,
      'contracting_client_id': contractingClientId,
      'contracting_client_name': contractingClientName,
      'contact_person': contactPerson,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'title': title,
      'location': location,
      'scheduled_date': scheduledDate.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'start_date_time': startDateTime?.toIso8601String(),
      'end_date_time': endDateTime?.toIso8601String(),
      'team_id': primaryAssignedTeamId,
      'assigned_team_ids': resolvedAssignedTeamIds,
      'assigned_user_id': assignedUserId,
      'assigned_user_email': assignedUserEmail,
      'assigned_employee_ids': assignedEmployeeIds,
      'vehicle_id': vehicleId,
      'complaint_visit_type': complaintVisitType?.value ?? '',
      'complaint_visit_outcome': complaintVisitOutcome?.value ?? '',
      'postponement_reason': postponementReason,
      'rescheduled_from_start_date_time':
          rescheduledFromStartDateTime?.toIso8601String(),
      'rescheduled_from_end_date_time':
          rescheduledFromEndDateTime?.toIso8601String(),
      'type': type,
      'priority': priority,
      'color_code': colorCode,
      'status': status,
      'job_id': jobId,
      'complaint_id': complaintId,
      'complaint_number': complaintNumber,
      'notes': notes,
      'linked_documents':
          linkedDocuments.map((entry) => entry.toMap()).toList(growable: false),
      'recurrence_rule': recurrenceRule,
      'recurring_group_id': recurringGroupId,
      'for_partner_id': forPartnerId,
      'for_partner_name': forPartnerName,
      'executing_partner_id': executingPartnerId,
      'executing_partner_name': executingPartnerName,
      'equipment_description': equipmentDescription,
      'intervention_price': interventionPrice,
      'intervention_price_currency': interventionPriceCurrency,
      'admin_collected_amount': adminCollectedAmount,
      'admin_collected_currency': adminCollectedCurrency,
      'admin_financial_status': adminFinancialStatus.value,
      'admin_due_date': adminDueDate?.toIso8601String(),
      'admin_financial_notes': adminFinancialNotes,
      'material_usage': materialUsage.toMap(),
      'executing_partner_commission': executingPartnerCommission,
      'executing_partner_commission_currency':
          executingPartnerCommissionCurrency,
      'executing_partner_payment_status': executingPartnerPaymentStatus.value,
      'executing_partner_payment_date':
          executingPartnerPaymentDate?.toIso8601String(),
      'executing_partner_payment_notes': executingPartnerPaymentNotes,
      'for_partner_invoice_amount': forPartnerInvoiceAmount,
      'for_partner_invoice_currency': forPartnerInvoiceCurrency,
      'for_partner_receive_status': forPartnerReceiveStatus.value,
      'for_partner_receive_date': forPartnerReceiveDate?.toIso8601String(),
      'for_partner_receive_notes': forPartnerReceiveNotes,
      'client_phone_numbers': clientPhoneNumbers,
      'stoc_scazut': stocScazut,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    DateTime? parseDateTime(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    List<String> parseIdList(dynamic raw) {
      if (raw is List) {
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
      return const <String>[];
    }

    List<AppointmentLinkedDocument> parseLinkedDocuments(dynamic raw) {
      if (raw is! List) {
        return const <AppointmentLinkedDocument>[];
      }
      return raw
          .map((entry) {
            if (entry is Map<String, dynamic>) {
              return AppointmentLinkedDocument.fromMap(entry);
            }
            if (entry is Map) {
              return AppointmentLinkedDocument.fromMap(
                Map<String, dynamic>.from(entry),
              );
            }
            return null;
          })
          .whereType<AppointmentLinkedDocument>()
          .where((entry) => entry.filePath.trim().isNotEmpty)
          .toList(growable: false);
    }

    AppointmentMaterialUsage parseMaterialUsage(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return AppointmentMaterialUsage.fromMap(raw);
      }
      if (raw is Map) {
        return AppointmentMaterialUsage.fromMap(Map<String, dynamic>.from(raw));
      }
      return const AppointmentMaterialUsage();
    }

    final legacyTeamId = (map['team_id'] ?? map['teamId'] ?? '').toString();
    final assignedTeamIds = parseIdList(
      map['assigned_team_ids'] ?? map['assignedTeamIds'],
    );
    final resolvedAssignedTeamIds = <String>[
      ...assignedTeamIds,
      if (legacyTeamId.trim().isNotEmpty &&
          !assignedTeamIds.contains(legacyTeamId.trim()))
        legacyTeamId.trim(),
    ];

    return Appointment(
      id: (map['id'] ?? '').toString(),
      clientId: (map['client_id'] ?? '').toString(),
      clientName: (map['client_name'] ?? map['clientName'] ?? '').toString(),
      contractingClientId:
          (map['contracting_client_id'] ?? map['contractingClientId'] ?? '')
              .toString(),
      contractingClientName:
          (map['contracting_client_name'] ?? map['contractingClientName'] ?? '')
              .toString(),
      contactPerson:
          (map['contact_person'] ?? map['contactPerson'] ?? '').toString(),
      contactPhone:
          (map['contact_phone'] ?? map['contactPhone'] ?? '').toString(),
      contactEmail:
          (map['contact_email'] ?? map['contactEmail'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      scheduledDate: DateTime.tryParse(
            (map['scheduled_date'] ?? '').toString(),
          ) ??
          DateTime.now(),
      startTime: (map['start_time'] ?? '').toString(),
      endTime: (map['end_time'] ?? '').toString(),
      startDateTime: parseDateTime(
        map['start_date_time'] ?? map['startDateTime'],
      ),
      endDateTime: parseDateTime(
        map['end_date_time'] ?? map['endDateTime'],
      ),
      teamId: legacyTeamId,
      assignedTeamIds: resolvedAssignedTeamIds,
      assignedUserId:
          (map['assigned_user_id'] ?? map['assignedUserId'] ?? '').toString(),
      assignedUserEmail:
          (map['assigned_user_email'] ?? map['assignedUserEmail'] ?? '')
              .toString(),
      assignedEmployeeIds: parseIdList(
        map['assigned_employee_ids'] ?? map['assignedEmployeeIds'],
      ),
      vehicleId: (map['vehicle_id'] ?? '').toString(),
      complaintVisitType: ComplaintVisitType.fromValue(
        (map['complaint_visit_type'] ?? map['complaintVisitType'] ?? '')
            .toString(),
      ),
      complaintVisitOutcome: ComplaintVisitOutcome.fromValue(
        (map['complaint_visit_outcome'] ?? map['complaintVisitOutcome'] ?? '')
            .toString(),
      ),
      postponementReason:
          (map['postponement_reason'] ?? map['postponementReason'] ?? '')
              .toString(),
      rescheduledFromStartDateTime: parseDateTime(
        map['rescheduled_from_start_date_time'] ??
            map['rescheduledFromStartDateTime'],
      ),
      rescheduledFromEndDateTime: parseDateTime(
        map['rescheduled_from_end_date_time'] ??
            map['rescheduledFromEndDateTime'],
      ),
      type: (map['type'] ?? '').toString(),
      priority: (map['priority'] ?? '').toString(),
      colorCode: (map['color_code'] ?? map['colorCode'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      jobId: (map['job_id'] ?? map['jobId'] ?? '').toString(),
      complaintId: (map['complaint_id'] ?? map['complaintId'] ?? '').toString(),
      complaintNumber:
          (map['complaint_number'] ?? map['complaintNumber'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      linkedDocuments: parseLinkedDocuments(
        map['linked_documents'] ?? map['linkedDocuments'],
      ),
      recurrenceRule:
          (map['recurrence_rule'] ?? map['recurrenceRule'] ?? 'none')
              .toString(),
      recurringGroupId:
          (map['recurring_group_id'] ?? map['recurringGroupId'] ?? '')
              .toString(),
      forPartnerId:
          (map['for_partner_id'] ?? map['forPartnerId'] ?? '').toString(),
      forPartnerName:
          (map['for_partner_name'] ?? map['forPartnerName'] ?? '').toString(),
      executingPartnerId:
          (map['executing_partner_id'] ?? map['executingPartnerId'] ?? '')
              .toString(),
      executingPartnerName:
          (map['executing_partner_name'] ?? map['executingPartnerName'] ?? '')
              .toString(),
      equipmentDescription:
          (map['equipment_description'] ?? map['equipmentDescription'] ?? '')
              .toString(),
      interventionPrice: () {
        final raw = map['intervention_price'] ?? map['interventionPrice'];
        if (raw is num) return raw.toDouble();
        return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
      }(),
      interventionPriceCurrency: (map['intervention_price_currency'] ??
                  map['interventionPriceCurrency'] ??
                  'RON')
              .toString()
              .trim()
              .isEmpty
          ? 'RON'
          : (map['intervention_price_currency'] ??
                  map['interventionPriceCurrency'] ??
                  'RON')
              .toString()
              .trim(),
      adminCollectedAmount: _parseDouble(
        map['admin_collected_amount'] ?? map['adminCollectedAmount'],
      ),
      adminCollectedCurrency: (map['admin_collected_currency'] ??
                  map['adminCollectedCurrency'] ??
                  'RON')
              .toString()
              .trim()
              .isEmpty
          ? 'RON'
          : (map['admin_collected_currency'] ??
                  map['adminCollectedCurrency'] ??
                  'RON')
              .toString()
              .trim(),
      adminFinancialStatus: AppointmentFinancialStatus.fromValue(
        (map['admin_financial_status'] ?? map['adminFinancialStatus'] ?? '')
            .toString(),
      ),
      adminDueDate: parseDateTime(
        map['admin_due_date'] ?? map['adminDueDate'],
      ),
      adminFinancialNotes: (map['admin_financial_notes'] ??
              map['adminFinancialNotes'] ??
              '')
          .toString(),
      materialUsage: parseMaterialUsage(
        map['material_usage'] ?? map['materialUsage'],
      ),
      executingPartnerCommission: _parseDouble(
        map['executing_partner_commission'] ??
            map['executingPartnerCommission'],
      ),
      executingPartnerCommissionCurrency: (() {
        final v = (map['executing_partner_commission_currency'] ??
                map['executingPartnerCommissionCurrency'] ??
                'RON')
            .toString()
            .trim();
        return v.isEmpty ? 'RON' : v;
      })(),
      executingPartnerPaymentStatus: PartnerPaymentStatus.fromValue(
        (map['executing_partner_payment_status'] ??
                map['executingPartnerPaymentStatus'] ??
                '')
            .toString(),
      ),
      executingPartnerPaymentDate: parseDateTime(
        map['executing_partner_payment_date'] ??
            map['executingPartnerPaymentDate'],
      ),
      executingPartnerPaymentNotes: (map['executing_partner_payment_notes'] ??
              map['executingPartnerPaymentNotes'] ??
              '')
          .toString(),
      forPartnerInvoiceAmount: _parseDouble(
        map['for_partner_invoice_amount'] ?? map['forPartnerInvoiceAmount'],
      ),
      forPartnerInvoiceCurrency: (() {
        final v = (map['for_partner_invoice_currency'] ??
                map['forPartnerInvoiceCurrency'] ??
                'RON')
            .toString()
            .trim();
        return v.isEmpty ? 'RON' : v;
      })(),
      forPartnerReceiveStatus: PartnerPaymentStatus.fromValue(
        (map['for_partner_receive_status'] ??
                map['forPartnerReceiveStatus'] ??
                '')
            .toString(),
      ),
      forPartnerReceiveDate: parseDateTime(
        map['for_partner_receive_date'] ?? map['forPartnerReceiveDate'],
      ),
      forPartnerReceiveNotes: (map['for_partner_receive_notes'] ??
              map['forPartnerReceiveNotes'] ??
              '')
          .toString(),
      stocScazut: (map['stoc_scazut'] ?? map['stocScazut'] ?? false) == true,
      clientPhoneNumbers: (() {
        final raw = map['client_phone_numbers'] ?? map['clientPhoneNumbers'];
        if (raw is List) {
          return List<String>.from(
            raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
          );
        }
        // Fallback: migrare din contactPhone
        final single = (map['contact_phone'] ?? '').toString().trim();
        return single.isNotEmpty ? [single] : const <String>[];
      })(),
    );
  }

  static DateTime _combineDateAndTime(DateTime date, String rawTime) {
    final trimmed = rawTime.trim();
    final parts = trimmed.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}

double _parseDouble(dynamic raw) {
  if (raw is num) {
    return raw.toDouble();
  }
  return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
}
