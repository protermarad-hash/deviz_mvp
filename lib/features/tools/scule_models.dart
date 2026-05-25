enum ToolInventoryStatus {
  disponibila,
  atribuita,
  service,
  lipsa,
  casata;

  String get value {
    switch (this) {
      case ToolInventoryStatus.disponibila:
        return 'disponibila';
      case ToolInventoryStatus.atribuita:
        return 'atribuita';
      case ToolInventoryStatus.service:
        return 'service';
      case ToolInventoryStatus.lipsa:
        return 'lipsa';
      case ToolInventoryStatus.casata:
        return 'casata';
    }
  }

  String get label {
    switch (this) {
      case ToolInventoryStatus.disponibila:
        return 'Disponibila';
      case ToolInventoryStatus.atribuita:
        return 'Atribuita';
      case ToolInventoryStatus.service:
        return 'Service';
      case ToolInventoryStatus.lipsa:
        return 'Lipsa';
      case ToolInventoryStatus.casata:
        return 'Casata';
    }
  }

  static ToolInventoryStatus fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final item in ToolInventoryStatus.values) {
      if (item.value == value) return item;
    }
    return ToolInventoryStatus.disponibila;
  }
}

enum ToolMovementEventType {
  atribuita,
  retrasa,
  service,
  lipsa,
  casata,
  editata,
  cerereMutareCreata,
  cerereMutareAprobata,
  cerereMutareRespinsa,
  mutareEfectuata;

  String get value {
    switch (this) {
      case ToolMovementEventType.atribuita:
        return 'atribuita';
      case ToolMovementEventType.retrasa:
        return 'retrasa';
      case ToolMovementEventType.service:
        return 'service';
      case ToolMovementEventType.lipsa:
        return 'lipsa';
      case ToolMovementEventType.casata:
        return 'casata';
      case ToolMovementEventType.editata:
        return 'editata';
      case ToolMovementEventType.cerereMutareCreata:
        return 'cerere_mutare_creata';
      case ToolMovementEventType.cerereMutareAprobata:
        return 'cerere_mutare_aprobata';
      case ToolMovementEventType.cerereMutareRespinsa:
        return 'cerere_mutare_respinsa';
      case ToolMovementEventType.mutareEfectuata:
        return 'mutare_efectuata';
    }
  }

  String get label {
    switch (this) {
      case ToolMovementEventType.atribuita:
        return 'Atribuita';
      case ToolMovementEventType.retrasa:
        return 'Retrasa';
      case ToolMovementEventType.service:
        return 'Service';
      case ToolMovementEventType.lipsa:
        return 'Lipsa';
      case ToolMovementEventType.casata:
        return 'Casata';
      case ToolMovementEventType.editata:
        return 'Editata';
      case ToolMovementEventType.cerereMutareCreata:
        return 'Cerere mutare creata';
      case ToolMovementEventType.cerereMutareAprobata:
        return 'Cerere mutare aprobata';
      case ToolMovementEventType.cerereMutareRespinsa:
        return 'Cerere mutare respinsa';
      case ToolMovementEventType.mutareEfectuata:
        return 'Mutare efectuata';
    }
  }

  static ToolMovementEventType fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final item in ToolMovementEventType.values) {
      if (item.value == value) return item;
    }
    return ToolMovementEventType.editata;
  }
}

class ToolInventoryItem {
  const ToolInventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.model,
    required this.description,
    required this.serialNumber,
    required this.inventoryCode,
    this.purchaseDate,
    required this.purchaseValue,
    this.usefulLifeMonths = 36,
    required this.unit,
    required this.status,
    required this.notes,
    required this.assignedTeamId,
    required this.assignedTeamName,
    required this.assignedEmployeeId,
    required this.assignedEmployeeName,
    this.assignedAt,
    required this.assignedByUserId,
    required this.assignedByUserEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final String brand;
  final String model;
  final String description;
  final String serialNumber;
  final String inventoryCode;
  final DateTime? purchaseDate;
  final double purchaseValue;
  final int usefulLifeMonths;
  final String unit;
  final ToolInventoryStatus status;
  final String notes;
  final String assignedTeamId;
  final String assignedTeamName;
  final String assignedEmployeeId;
  final String assignedEmployeeName;
  final DateTime? assignedAt;
  final String assignedByUserId;
  final String assignedByUserEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  ToolInventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    String? brand,
    String? model,
    String? description,
    String? serialNumber,
    String? inventoryCode,
    DateTime? purchaseDate,
    bool clearPurchaseDate = false,
    double? purchaseValue,
    int? usefulLifeMonths,
    String? unit,
    ToolInventoryStatus? status,
    String? notes,
    String? assignedTeamId,
    String? assignedTeamName,
    String? assignedEmployeeId,
    String? assignedEmployeeName,
    DateTime? assignedAt,
    bool clearAssignedAt = false,
    String? assignedByUserId,
    String? assignedByUserEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ToolInventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      description: description ?? this.description,
      serialNumber: serialNumber ?? this.serialNumber,
      inventoryCode: inventoryCode ?? this.inventoryCode,
      purchaseDate: clearPurchaseDate ? null : (purchaseDate ?? this.purchaseDate),
      purchaseValue: purchaseValue ?? this.purchaseValue,
      usefulLifeMonths: usefulLifeMonths ?? this.usefulLifeMonths,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      assignedTeamId: assignedTeamId ?? this.assignedTeamId,
      assignedTeamName: assignedTeamName ?? this.assignedTeamName,
      assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
      assignedEmployeeName: assignedEmployeeName ?? this.assignedEmployeeName,
      assignedAt: clearAssignedAt ? null : (assignedAt ?? this.assignedAt),
      assignedByUserId: assignedByUserId ?? this.assignedByUserId,
      assignedByUserEmail: assignedByUserEmail ?? this.assignedByUserEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category': category,
      'brand': brand,
      'model': model,
      'description': description,
      'serial_number': serialNumber,
      'inventory_code': inventoryCode,
      'purchase_date': purchaseDate?.toIso8601String(),
      'purchase_value': purchaseValue,
      'useful_life_months': usefulLifeMonths,
      'unit': unit,
      'status': status.value,
      'notes': notes,
      'assigned_team_id': assignedTeamId,
      'assigned_team_name': assignedTeamName,
      'assigned_employee_id': assignedEmployeeId,
      'assigned_employee_name': assignedEmployeeName,
      'assigned_at': assignedAt?.toIso8601String(),
      'assigned_by_user_id': assignedByUserId,
      'assigned_by_user_email': assignedByUserEmail,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ToolInventoryItem.fromMap(Map<String, dynamic> map) {
    DateTime? asDate(dynamic raw) {
      if (raw == null) return null;
      final text = raw.toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    double asDouble(dynamic raw) {
      if (raw == null) return 0;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString().replaceAll(',', '.').trim()) ?? 0;
    }
    int asInt(dynamic raw, {int fallback = 0}) {
      if (raw == null) return fallback;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString().trim()) ?? fallback;
    }

    final now = DateTime.now();
    return ToolInventoryItem(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      category: (map['category'] ?? '').toString().trim(),
      brand: (map['brand'] ?? '').toString().trim(),
      model: (map['model'] ?? '').toString().trim(),
      description: (map['description'] ?? map['descriere'] ?? '')
          .toString()
          .trim(),
      serialNumber: (map['serial_number'] ?? map['serialNumber'] ?? '')
          .toString()
          .trim(),
      inventoryCode: (map['inventory_code'] ?? map['inventoryCode'] ?? '')
          .toString()
          .trim(),
      purchaseDate: asDate(map['purchase_date'] ?? map['purchaseDate']),
      purchaseValue: asDouble(map['purchase_value'] ?? map['purchaseValue']),
      usefulLifeMonths: asInt(
        map['useful_life_months'] ?? map['usefulLifeMonths'],
        fallback: 36,
      ),
      unit: (map['unit'] ?? '').toString().trim(),
      status: ToolInventoryStatus.fromValue(map['status']?.toString()),
      notes: (map['notes'] ?? '').toString().trim(),
      assignedTeamId:
          (map['assigned_team_id'] ?? map['assignedTeamId'] ?? '').toString().trim(),
      assignedTeamName: (map['assigned_team_name'] ?? map['assignedTeamName'] ?? '')
          .toString()
          .trim(),
      assignedEmployeeId: (map['assigned_employee_id'] ??
              map['assignedEmployeeId'] ??
              '')
          .toString()
          .trim(),
      assignedEmployeeName: (map['assigned_employee_name'] ??
              map['assignedEmployeeName'] ??
              '')
          .toString()
          .trim(),
      assignedAt: asDate(map['assigned_at'] ?? map['assignedAt']),
      assignedByUserId: (map['assigned_by_user_id'] ?? map['assignedByUserId'] ?? '')
          .toString()
          .trim(),
      assignedByUserEmail:
          (map['assigned_by_user_email'] ?? map['assignedByUserEmail'] ?? '')
              .toString()
              .trim(),
      createdAt: asDate(map['created_at'] ?? map['createdAt']) ?? now,
      updatedAt: asDate(map['updated_at'] ?? map['updatedAt']) ?? now,
    );
  }
}

class ToolHandoverLine {
  const ToolHandoverLine({
    required this.name,
    required this.category,
    required this.brandModel,
    required this.inventoryCode,
    required this.serialNumber,
    required this.statusLabel,
    required this.notes,
  });

  final String name;
  final String category;
  final String brandModel;
  final String inventoryCode;
  final String serialNumber;
  final String statusLabel;
  final String notes;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'category': category,
      'brand_model': brandModel,
      'inventory_code': inventoryCode,
      'serial_number': serialNumber,
      'status_label': statusLabel,
      'notes': notes,
    };
  }

  factory ToolHandoverLine.fromMap(Map<String, dynamic> map) {
    return ToolHandoverLine(
      name: (map['name'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      brandModel: (map['brand_model'] ?? map['brandModel'] ?? '').toString(),
      inventoryCode:
          (map['inventory_code'] ?? map['inventoryCode'] ?? '').toString(),
      serialNumber:
          (map['serial_number'] ?? map['serialNumber'] ?? '').toString(),
      statusLabel:
          (map['status_label'] ?? map['statusLabel'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
    );
  }
}

class ToolHandoverDocument {
  const ToolHandoverDocument({
    required this.id,
    required this.documentNumber,
    required this.documentDate,
    required this.teamId,
    required this.teamName,
    required this.responsibleName,
    required this.toolIds,
    required this.lines,
    required this.filePath,
    required this.createdByUserId,
    required this.createdByUserEmail,
    required this.createdAt,
  });

  final String id;
  final String documentNumber;
  final DateTime documentDate;
  final String teamId;
  final String teamName;
  final String responsibleName;
  final List<String> toolIds;
  final List<ToolHandoverLine> lines;
  final String filePath;
  final String createdByUserId;
  final String createdByUserEmail;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'document_number': documentNumber,
      'document_date': documentDate.toIso8601String(),
      'team_id': teamId,
      'team_name': teamName,
      'responsible_name': responsibleName,
      'tool_ids': toolIds,
      'lines': lines.map((item) => item.toMap()).toList(growable: false),
      'file_path': filePath,
      'created_by_user_id': createdByUserId,
      'created_by_user_email': createdByUserEmail,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ToolHandoverDocument.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final parsed = DateTime.tryParse((raw ?? '').toString().trim());
      return parsed ?? DateTime.now();
    }

    final idsRaw = map['tool_ids'];
    final ids = idsRaw is List
        ? idsRaw.map((item) => item.toString()).toList(growable: false)
        : const <String>[];
    final linesRaw = map['lines'];
    final lines = linesRaw is List
        ? linesRaw
            .whereType<Map>()
            .map((item) => ToolHandoverLine.fromMap(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <ToolHandoverLine>[];
    return ToolHandoverDocument(
      id: (map['id'] ?? '').toString(),
      documentNumber: (map['document_number'] ?? map['documentNumber'] ?? '')
          .toString(),
      documentDate: parseDate(map['document_date'] ?? map['documentDate']),
      teamId: (map['team_id'] ?? map['teamId'] ?? '').toString(),
      teamName: (map['team_name'] ?? map['teamName'] ?? '').toString(),
      responsibleName:
          (map['responsible_name'] ?? map['responsibleName'] ?? '').toString(),
      toolIds: ids,
      lines: lines,
      filePath: (map['file_path'] ?? map['filePath'] ?? '').toString(),
      createdByUserId:
          (map['created_by_user_id'] ?? map['createdByUserId'] ?? '').toString(),
      createdByUserEmail: (map['created_by_user_email'] ??
              map['createdByUserEmail'] ??
              '')
          .toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
    );
  }
}

class ToolMovementEvent {
  const ToolMovementEvent({
    required this.id,
    required this.toolId,
    required this.eventType,
    required this.eventDate,
    required this.teamId,
    required this.teamName,
    required this.performedByUserId,
    required this.performedByUserEmail,
    required this.notes,
  });

  final String id;
  final String toolId;
  final ToolMovementEventType eventType;
  final DateTime eventDate;
  final String teamId;
  final String teamName;
  final String performedByUserId;
  final String performedByUserEmail;
  final String notes;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'tool_id': toolId,
      'event_type': eventType.value,
      'event_date': eventDate.toIso8601String(),
      'team_id': teamId,
      'team_name': teamName,
      'performed_by_user_id': performedByUserId,
      'performed_by_user_email': performedByUserEmail,
      'notes': notes,
    };
  }

  factory ToolMovementEvent.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final parsed = DateTime.tryParse((raw ?? '').toString().trim());
      return parsed ?? DateTime.now();
    }

    return ToolMovementEvent(
      id: (map['id'] ?? '').toString().trim(),
      toolId: (map['tool_id'] ?? map['toolId'] ?? '').toString().trim(),
      eventType: ToolMovementEventType.fromValue(
        map['event_type']?.toString() ?? map['eventType']?.toString(),
      ),
      eventDate: parseDate(map['event_date'] ?? map['eventDate']),
      teamId: (map['team_id'] ?? map['teamId'] ?? '').toString().trim(),
      teamName: (map['team_name'] ?? map['teamName'] ?? '').toString().trim(),
      performedByUserId: (map['performed_by_user_id'] ??
              map['performedByUserId'] ??
              '')
          .toString()
          .trim(),
      performedByUserEmail: (map['performed_by_user_email'] ??
              map['performedByUserEmail'] ??
              '')
          .toString()
          .trim(),
      notes: (map['notes'] ?? '').toString().trim(),
    );
  }
}

enum ToolTransferRequestStatus {
  inAsteptareAprobare,
  aprobata,
  respinsa;

  String get value {
    switch (this) {
      case ToolTransferRequestStatus.inAsteptareAprobare:
        return 'in_asteptare_aprobare';
      case ToolTransferRequestStatus.aprobata:
        return 'aprobata';
      case ToolTransferRequestStatus.respinsa:
        return 'respinsa';
    }
  }

  String get label {
    switch (this) {
      case ToolTransferRequestStatus.inAsteptareAprobare:
        return 'In asteptare aprobare';
      case ToolTransferRequestStatus.aprobata:
        return 'Aprobata';
      case ToolTransferRequestStatus.respinsa:
        return 'Respinsa';
    }
  }

  static ToolTransferRequestStatus fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final item in ToolTransferRequestStatus.values) {
      if (item.value == value) return item;
    }
    return ToolTransferRequestStatus.inAsteptareAprobare;
  }
}

class ToolTransferRequest {
  const ToolTransferRequest({
    required this.id,
    required this.toolId,
    required this.inventoryCode,
    required this.toolName,
    required this.sourceEmployeeId,
    required this.sourceEmployeeName,
    required this.targetEmployeeId,
    required this.targetEmployeeName,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.createdByUserId,
    required this.createdByUserEmail,
    this.processedAt,
    this.processedByUserId = '',
    this.processedByUserEmail = '',
    this.decisionNotes = '',
  });

  final String id;
  final String toolId;
  final String inventoryCode;
  final String toolName;
  final String sourceEmployeeId;
  final String sourceEmployeeName;
  final String targetEmployeeId;
  final String targetEmployeeName;
  final String notes;
  final ToolTransferRequestStatus status;
  final DateTime createdAt;
  final String createdByUserId;
  final String createdByUserEmail;
  final DateTime? processedAt;
  final String processedByUserId;
  final String processedByUserEmail;
  final String decisionNotes;

  ToolTransferRequest copyWith({
    String? id,
    String? toolId,
    String? inventoryCode,
    String? toolName,
    String? sourceEmployeeId,
    String? sourceEmployeeName,
    String? targetEmployeeId,
    String? targetEmployeeName,
    String? notes,
    ToolTransferRequestStatus? status,
    DateTime? createdAt,
    String? createdByUserId,
    String? createdByUserEmail,
    DateTime? processedAt,
    bool clearProcessedAt = false,
    String? processedByUserId,
    String? processedByUserEmail,
    String? decisionNotes,
  }) {
    return ToolTransferRequest(
      id: id ?? this.id,
      toolId: toolId ?? this.toolId,
      inventoryCode: inventoryCode ?? this.inventoryCode,
      toolName: toolName ?? this.toolName,
      sourceEmployeeId: sourceEmployeeId ?? this.sourceEmployeeId,
      sourceEmployeeName: sourceEmployeeName ?? this.sourceEmployeeName,
      targetEmployeeId: targetEmployeeId ?? this.targetEmployeeId,
      targetEmployeeName: targetEmployeeName ?? this.targetEmployeeName,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByUserEmail: createdByUserEmail ?? this.createdByUserEmail,
      processedAt: clearProcessedAt ? null : (processedAt ?? this.processedAt),
      processedByUserId: processedByUserId ?? this.processedByUserId,
      processedByUserEmail: processedByUserEmail ?? this.processedByUserEmail,
      decisionNotes: decisionNotes ?? this.decisionNotes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'tool_id': toolId,
      'inventory_code': inventoryCode,
      'tool_name': toolName,
      'source_employee_id': sourceEmployeeId,
      'source_employee_name': sourceEmployeeName,
      'target_employee_id': targetEmployeeId,
      'target_employee_name': targetEmployeeName,
      'notes': notes,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'created_by_user_id': createdByUserId,
      'created_by_user_email': createdByUserEmail,
      'processed_at': processedAt?.toIso8601String(),
      'processed_by_user_id': processedByUserId,
      'processed_by_user_email': processedByUserEmail,
      'decision_notes': decisionNotes,
    };
  }

  factory ToolTransferRequest.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final parsed = DateTime.tryParse((raw ?? '').toString().trim());
      return parsed ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic raw) {
      final parsed = DateTime.tryParse((raw ?? '').toString().trim());
      return parsed;
    }

    return ToolTransferRequest(
      id: (map['id'] ?? '').toString().trim(),
      toolId: (map['tool_id'] ?? map['toolId'] ?? '').toString().trim(),
      inventoryCode:
          (map['inventory_code'] ?? map['inventoryCode'] ?? '').toString().trim(),
      toolName: (map['tool_name'] ?? map['toolName'] ?? '').toString().trim(),
      sourceEmployeeId:
          (map['source_employee_id'] ?? map['sourceEmployeeId'] ?? '')
              .toString()
              .trim(),
      sourceEmployeeName:
          (map['source_employee_name'] ?? map['sourceEmployeeName'] ?? '')
              .toString()
              .trim(),
      targetEmployeeId:
          (map['target_employee_id'] ?? map['targetEmployeeId'] ?? '')
              .toString()
              .trim(),
      targetEmployeeName:
          (map['target_employee_name'] ?? map['targetEmployeeName'] ?? '')
              .toString()
              .trim(),
      notes: (map['notes'] ?? '').toString().trim(),
      status: ToolTransferRequestStatus.fromValue(map['status']?.toString()),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      createdByUserId:
          (map['created_by_user_id'] ?? map['createdByUserId'] ?? '')
              .toString()
              .trim(),
      createdByUserEmail:
          (map['created_by_user_email'] ?? map['createdByUserEmail'] ?? '')
              .toString()
              .trim(),
      processedAt: parseNullableDate(map['processed_at'] ?? map['processedAt']),
      processedByUserId:
          (map['processed_by_user_id'] ?? map['processedByUserId'] ?? '')
              .toString()
              .trim(),
      processedByUserEmail:
          (map['processed_by_user_email'] ?? map['processedByUserEmail'] ?? '')
              .toString()
              .trim(),
      decisionNotes:
          (map['decision_notes'] ?? map['decisionNotes'] ?? '').toString().trim(),
    );
  }
}

class ToolTransferNotification {
  const ToolTransferNotification({
    required this.id,
    required this.requestId,
    required this.toolId,
    required this.inventoryCode,
    required this.toolName,
    required this.sourceEmployeeId,
    required this.sourceEmployeeName,
    required this.targetEmployeeId,
    required this.targetEmployeeName,
    required this.message,
    required this.createdAt,
    required this.createdByUserId,
    required this.createdByUserEmail,
    required this.processed,
    this.processedAt,
    this.processedByUserId = '',
    this.processedByUserEmail = '',
  });

  final String id;
  final String requestId;
  final String toolId;
  final String inventoryCode;
  final String toolName;
  final String sourceEmployeeId;
  final String sourceEmployeeName;
  final String targetEmployeeId;
  final String targetEmployeeName;
  final String message;
  final DateTime createdAt;
  final String createdByUserId;
  final String createdByUserEmail;
  final bool processed;
  final DateTime? processedAt;
  final String processedByUserId;
  final String processedByUserEmail;

  ToolTransferNotification copyWith({
    String? id,
    String? requestId,
    String? toolId,
    String? inventoryCode,
    String? toolName,
    String? sourceEmployeeId,
    String? sourceEmployeeName,
    String? targetEmployeeId,
    String? targetEmployeeName,
    String? message,
    DateTime? createdAt,
    String? createdByUserId,
    String? createdByUserEmail,
    bool? processed,
    DateTime? processedAt,
    bool clearProcessedAt = false,
    String? processedByUserId,
    String? processedByUserEmail,
  }) {
    return ToolTransferNotification(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      toolId: toolId ?? this.toolId,
      inventoryCode: inventoryCode ?? this.inventoryCode,
      toolName: toolName ?? this.toolName,
      sourceEmployeeId: sourceEmployeeId ?? this.sourceEmployeeId,
      sourceEmployeeName: sourceEmployeeName ?? this.sourceEmployeeName,
      targetEmployeeId: targetEmployeeId ?? this.targetEmployeeId,
      targetEmployeeName: targetEmployeeName ?? this.targetEmployeeName,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByUserEmail: createdByUserEmail ?? this.createdByUserEmail,
      processed: processed ?? this.processed,
      processedAt: clearProcessedAt ? null : (processedAt ?? this.processedAt),
      processedByUserId: processedByUserId ?? this.processedByUserId,
      processedByUserEmail: processedByUserEmail ?? this.processedByUserEmail,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'request_id': requestId,
      'tool_id': toolId,
      'inventory_code': inventoryCode,
      'tool_name': toolName,
      'source_employee_id': sourceEmployeeId,
      'source_employee_name': sourceEmployeeName,
      'target_employee_id': targetEmployeeId,
      'target_employee_name': targetEmployeeName,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'created_by_user_id': createdByUserId,
      'created_by_user_email': createdByUserEmail,
      'processed': processed,
      'processed_at': processedAt?.toIso8601String(),
      'processed_by_user_id': processedByUserId,
      'processed_by_user_email': processedByUserEmail,
    };
  }

  factory ToolTransferNotification.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final parsed = DateTime.tryParse((raw ?? '').toString().trim());
      return parsed ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic raw) {
      final parsed = DateTime.tryParse((raw ?? '').toString().trim());
      return parsed;
    }

    return ToolTransferNotification(
      id: (map['id'] ?? '').toString().trim(),
      requestId: (map['request_id'] ?? map['requestId'] ?? '').toString().trim(),
      toolId: (map['tool_id'] ?? map['toolId'] ?? '').toString().trim(),
      inventoryCode:
          (map['inventory_code'] ?? map['inventoryCode'] ?? '').toString().trim(),
      toolName: (map['tool_name'] ?? map['toolName'] ?? '').toString().trim(),
      sourceEmployeeId:
          (map['source_employee_id'] ?? map['sourceEmployeeId'] ?? '')
              .toString()
              .trim(),
      sourceEmployeeName:
          (map['source_employee_name'] ?? map['sourceEmployeeName'] ?? '')
              .toString()
              .trim(),
      targetEmployeeId:
          (map['target_employee_id'] ?? map['targetEmployeeId'] ?? '')
              .toString()
              .trim(),
      targetEmployeeName:
          (map['target_employee_name'] ?? map['targetEmployeeName'] ?? '')
              .toString()
              .trim(),
      message: (map['message'] ?? '').toString().trim(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      createdByUserId:
          (map['created_by_user_id'] ?? map['createdByUserId'] ?? '')
              .toString()
              .trim(),
      createdByUserEmail:
          (map['created_by_user_email'] ?? map['createdByUserEmail'] ?? '')
              .toString()
              .trim(),
      processed: map['processed'] == true,
      processedAt: parseNullableDate(map['processed_at'] ?? map['processedAt']),
      processedByUserId:
          (map['processed_by_user_id'] ?? map['processedByUserId'] ?? '')
              .toString()
              .trim(),
      processedByUserEmail:
          (map['processed_by_user_email'] ?? map['processedByUserEmail'] ?? '')
              .toString()
              .trim(),
    );
  }
}
