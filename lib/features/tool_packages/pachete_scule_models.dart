enum ToolPackageStatus {
  disponibil,
  inAsteptareReceptie,
  receptionat,
  inAsteptareRetragere;

  String get value {
    switch (this) {
      case ToolPackageStatus.disponibil:
        return 'disponibil';
      case ToolPackageStatus.inAsteptareReceptie:
        return 'in_asteptare_receptie';
      case ToolPackageStatus.receptionat:
        return 'receptionat';
      case ToolPackageStatus.inAsteptareRetragere:
        return 'in_asteptare_retragere';
    }
  }

  String get label {
    switch (this) {
      case ToolPackageStatus.disponibil:
        return 'Disponibil';
      case ToolPackageStatus.inAsteptareReceptie:
        return 'In asteptare receptie';
      case ToolPackageStatus.receptionat:
        return 'Receptionat';
      case ToolPackageStatus.inAsteptareRetragere:
        return 'In asteptare retragere';
    }
  }

  static ToolPackageStatus fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final item in ToolPackageStatus.values) {
      if (item.value == value) return item;
    }
    return ToolPackageStatus.disponibil;
  }
}

class ToolPackageRecord {
  const ToolPackageRecord({
    required this.id,
    required this.name,
    required this.notes,
    required this.toolIds,
    required this.toolInventoryCodes,
    required this.status,
    required this.assignedTeamId,
    required this.assignedTeamName,
    this.assignedAt,
    required this.assignedByUserId,
    required this.assignedByUserEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String notes;
  final List<String> toolIds;
  final List<String> toolInventoryCodes;
  final ToolPackageStatus status;
  final String assignedTeamId;
  final String assignedTeamName;
  final DateTime? assignedAt;
  final String assignedByUserId;
  final String assignedByUserEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  ToolPackageRecord copyWith({
    String? id,
    String? name,
    String? notes,
    List<String>? toolIds,
    List<String>? toolInventoryCodes,
    ToolPackageStatus? status,
    String? assignedTeamId,
    String? assignedTeamName,
    DateTime? assignedAt,
    bool clearAssignedAt = false,
    String? assignedByUserId,
    String? assignedByUserEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ToolPackageRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      toolIds: toolIds ?? this.toolIds,
      toolInventoryCodes: toolInventoryCodes ?? this.toolInventoryCodes,
      status: status ?? this.status,
      assignedTeamId: assignedTeamId ?? this.assignedTeamId,
      assignedTeamName: assignedTeamName ?? this.assignedTeamName,
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
      'notes': notes,
      'tool_ids': toolIds,
      'tool_inventory_codes': toolInventoryCodes,
      'status': status.value,
      'assigned_team_id': assignedTeamId,
      'assigned_team_name': assignedTeamName,
      'assigned_at': assignedAt?.toIso8601String(),
      'assigned_by_user_id': assignedByUserId,
      'assigned_by_user_email': assignedByUserEmail,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ToolPackageRecord.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final parsed = DateTime.tryParse((raw ?? '').toString().trim());
      return parsed ?? DateTime.now();
    }
    DateTime? parseNullableDate(dynamic raw) {
      final parsed = DateTime.tryParse((raw ?? '').toString().trim());
      return parsed;
    }

    final idsRaw = map['tool_ids'] ?? map['toolIds'];
    final ids = idsRaw is List
        ? idsRaw
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final codesRaw =
        map['tool_inventory_codes'] ?? map['toolInventoryCodes'] ?? idsRaw;
    final codes = codesRaw is List
        ? codesRaw
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    return ToolPackageRecord(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      notes: (map['notes'] ?? '').toString().trim(),
      toolIds: ids,
      toolInventoryCodes: codes,
      status: ToolPackageStatus.fromValue(map['status']?.toString()),
      assignedTeamId:
          (map['assigned_team_id'] ?? map['assignedTeamId'] ?? '').toString().trim(),
      assignedTeamName: (map['assigned_team_name'] ?? map['assignedTeamName'] ?? '')
          .toString()
          .trim(),
      assignedAt: parseNullableDate(map['assigned_at'] ?? map['assignedAt']),
      assignedByUserId: (map['assigned_by_user_id'] ?? map['assignedByUserId'] ?? '')
          .toString()
          .trim(),
      assignedByUserEmail:
          (map['assigned_by_user_email'] ?? map['assignedByUserEmail'] ?? '')
              .toString()
              .trim(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class ToolPackageNotification {
  const ToolPackageNotification({
    required this.id,
    required this.packageId,
    required this.packageName,
    required this.targetTeamId,
    required this.targetTeamName,
    required this.sourceTeamId,
    required this.sourceTeamName,
    required this.eventType,
    required this.message,
    required this.createdAt,
    required this.createdByUserId,
    required this.createdByUserEmail,
    required this.processed,
    this.processedAt,
    required this.processedByUserId,
    required this.processedByUserEmail,
    this.receivedAt,
    required this.receivedByUserId,
    required this.receivedByUserEmail,
  });

  final String id;
  final String packageId;
  final String packageName;
  final String targetTeamId;
  final String targetTeamName;
  final String sourceTeamId;
  final String sourceTeamName;
  final String eventType;
  final String message;
  final DateTime createdAt;
  final String createdByUserId;
  final String createdByUserEmail;
  final bool processed;
  final DateTime? processedAt;
  final String processedByUserId;
  final String processedByUserEmail;
  final DateTime? receivedAt;
  final String receivedByUserId;
  final String receivedByUserEmail;

  ToolPackageNotification copyWith({
    String? id,
    String? packageId,
    String? packageName,
    String? targetTeamId,
    String? targetTeamName,
    String? sourceTeamId,
    String? sourceTeamName,
    String? eventType,
    String? message,
    DateTime? createdAt,
    String? createdByUserId,
    String? createdByUserEmail,
    bool? processed,
    DateTime? processedAt,
    bool clearProcessedAt = false,
    String? processedByUserId,
    String? processedByUserEmail,
    DateTime? receivedAt,
    bool clearReceivedAt = false,
    String? receivedByUserId,
    String? receivedByUserEmail,
  }) {
    return ToolPackageNotification(
      id: id ?? this.id,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      targetTeamId: targetTeamId ?? this.targetTeamId,
      targetTeamName: targetTeamName ?? this.targetTeamName,
      sourceTeamId: sourceTeamId ?? this.sourceTeamId,
      sourceTeamName: sourceTeamName ?? this.sourceTeamName,
      eventType: eventType ?? this.eventType,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByUserEmail: createdByUserEmail ?? this.createdByUserEmail,
      processed: processed ?? this.processed,
      processedAt: clearProcessedAt ? null : (processedAt ?? this.processedAt),
      processedByUserId: processedByUserId ?? this.processedByUserId,
      processedByUserEmail: processedByUserEmail ?? this.processedByUserEmail,
      receivedAt: clearReceivedAt ? null : (receivedAt ?? this.receivedAt),
      receivedByUserId: receivedByUserId ?? this.receivedByUserId,
      receivedByUserEmail: receivedByUserEmail ?? this.receivedByUserEmail,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'package_id': packageId,
      'package_name': packageName,
      'target_team_id': targetTeamId,
      'target_team_name': targetTeamName,
      'source_team_id': sourceTeamId,
      'source_team_name': sourceTeamName,
      'event_type': eventType,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'created_by_user_id': createdByUserId,
      'created_by_user_email': createdByUserEmail,
      'processed': processed,
      'processed_at': processedAt?.toIso8601String(),
      'processed_by_user_id': processedByUserId,
      'processed_by_user_email': processedByUserEmail,
      'received_at': receivedAt?.toIso8601String(),
      'received_by_user_id': receivedByUserId,
      'received_by_user_email': receivedByUserEmail,
    };
  }

  factory ToolPackageNotification.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final parsed = DateTime.tryParse((raw ?? '').toString().trim());
      return parsed ?? DateTime.now();
    }
    DateTime? parseNullableDate(dynamic raw) {
      final parsed = DateTime.tryParse((raw ?? '').toString().trim());
      return parsed;
    }

    return ToolPackageNotification(
      id: (map['id'] ?? '').toString().trim(),
      packageId: (map['package_id'] ?? map['packageId'] ?? '').toString().trim(),
      packageName:
          (map['package_name'] ?? map['packageName'] ?? '').toString().trim(),
      targetTeamId:
          (map['target_team_id'] ?? map['targetTeamId'] ?? '').toString().trim(),
      targetTeamName: (map['target_team_name'] ?? map['targetTeamName'] ?? '')
          .toString()
          .trim(),
      sourceTeamId:
          (map['source_team_id'] ?? map['sourceTeamId'] ?? '').toString().trim(),
      sourceTeamName: (map['source_team_name'] ?? map['sourceTeamName'] ?? '')
          .toString()
          .trim(),
      eventType: (map['event_type'] ?? map['eventType'] ?? '').toString().trim(),
      message: (map['message'] ?? '').toString().trim(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      createdByUserId: (map['created_by_user_id'] ?? map['createdByUserId'] ?? '')
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
      receivedAt: parseNullableDate(map['received_at'] ?? map['receivedAt']),
      receivedByUserId:
          (map['received_by_user_id'] ?? map['receivedByUserId'] ?? '')
              .toString()
              .trim(),
      receivedByUserEmail:
          (map['received_by_user_email'] ?? map['receivedByUserEmail'] ?? '')
              .toString()
              .trim(),
    );
  }
}

class ToolPackageHandoverDocument {
  const ToolPackageHandoverDocument({
    required this.id,
    required this.documentNumber,
    required this.documentDate,
    required this.packageId,
    required this.packageName,
    required this.teamId,
    required this.teamName,
    required this.operationType,
    required this.toolIds,
    required this.filePath,
    required this.createdByUserId,
    required this.createdByUserEmail,
    required this.createdAt,
  });

  final String id;
  final String documentNumber;
  final DateTime documentDate;
  final String packageId;
  final String packageName;
  final String teamId;
  final String teamName;
  final String operationType;
  final List<String> toolIds;
  final String filePath;
  final String createdByUserId;
  final String createdByUserEmail;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'document_number': documentNumber,
      'document_date': documentDate.toIso8601String(),
      'package_id': packageId,
      'package_name': packageName,
      'team_id': teamId,
      'team_name': teamName,
      'operation_type': operationType,
      'tool_ids': toolIds,
      'file_path': filePath,
      'created_by_user_id': createdByUserId,
      'created_by_user_email': createdByUserEmail,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ToolPackageHandoverDocument.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final parsed = DateTime.tryParse((raw ?? '').toString().trim());
      return parsed ?? DateTime.now();
    }

    final toolIdsRaw = map['tool_ids'];
    final toolIds = toolIdsRaw is List
        ? toolIdsRaw
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final operationRaw =
        (map['operation_type'] ?? map['operationType'] ?? 'predare')
            .toString()
            .trim();
    return ToolPackageHandoverDocument(
      id: (map['id'] ?? '').toString().trim(),
      documentNumber: (map['document_number'] ?? map['documentNumber'] ?? '')
          .toString()
          .trim(),
      documentDate: parseDate(map['document_date'] ?? map['documentDate']),
      packageId: (map['package_id'] ?? map['packageId'] ?? '').toString().trim(),
      packageName:
          (map['package_name'] ?? map['packageName'] ?? '').toString().trim(),
      teamId: (map['team_id'] ?? map['teamId'] ?? '').toString().trim(),
      teamName: (map['team_name'] ?? map['teamName'] ?? '').toString().trim(),
      operationType: operationRaw.isEmpty ? 'predare' : operationRaw,
      toolIds: toolIds,
      filePath: (map['file_path'] ?? map['filePath'] ?? '').toString().trim(),
      createdByUserId: (map['created_by_user_id'] ?? map['createdByUserId'] ?? '')
          .toString()
          .trim(),
      createdByUserEmail:
          (map['created_by_user_email'] ?? map['createdByUserEmail'] ?? '')
              .toString()
              .trim(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
    );
  }
}

enum ToolPackageMovementEventType {
  creare,
  editare,
  atribuire,
  retragere,
  receptie,
  initiereRetragere,
  retragereConfirmata,
  initiereMutare,
  mutareReceptionata;

  String get value {
    switch (this) {
      case ToolPackageMovementEventType.creare:
        return 'creare';
      case ToolPackageMovementEventType.editare:
        return 'editare';
      case ToolPackageMovementEventType.atribuire:
        return 'atribuire';
      case ToolPackageMovementEventType.retragere:
        return 'retragere';
      case ToolPackageMovementEventType.receptie:
        return 'receptie';
      case ToolPackageMovementEventType.initiereRetragere:
        return 'initiere_retragere';
      case ToolPackageMovementEventType.retragereConfirmata:
        return 'retragere_confirmata';
      case ToolPackageMovementEventType.initiereMutare:
        return 'initiere_mutare';
      case ToolPackageMovementEventType.mutareReceptionata:
        return 'mutare_receptionata';
    }
  }

  String get label {
    switch (this) {
      case ToolPackageMovementEventType.creare:
        return 'Creare pachet';
      case ToolPackageMovementEventType.editare:
        return 'Editare pachet';
      case ToolPackageMovementEventType.atribuire:
        return 'Atribuire pachet';
      case ToolPackageMovementEventType.retragere:
        return 'Retragere pachet';
      case ToolPackageMovementEventType.receptie:
        return 'Receptie confirmata';
      case ToolPackageMovementEventType.initiereRetragere:
        return 'Initiere retragere';
      case ToolPackageMovementEventType.retragereConfirmata:
        return 'Retragere confirmata';
      case ToolPackageMovementEventType.initiereMutare:
        return 'Initiere mutare';
      case ToolPackageMovementEventType.mutareReceptionata:
        return 'Mutare receptionata';
    }
  }

  static ToolPackageMovementEventType fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final item in ToolPackageMovementEventType.values) {
      if (item.value == value) return item;
    }
    return ToolPackageMovementEventType.editare;
  }
}

class ToolPackageMovementEvent {
  const ToolPackageMovementEvent({
    required this.id,
    required this.packageId,
    required this.packageName,
    required this.eventType,
    required this.eventDate,
    required this.teamId,
    required this.teamName,
    required this.performedByUserId,
    required this.performedByUserEmail,
    required this.notes,
  });

  final String id;
  final String packageId;
  final String packageName;
  final ToolPackageMovementEventType eventType;
  final DateTime eventDate;
  final String teamId;
  final String teamName;
  final String performedByUserId;
  final String performedByUserEmail;
  final String notes;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'package_id': packageId,
      'package_name': packageName,
      'event_type': eventType.value,
      'event_date': eventDate.toIso8601String(),
      'team_id': teamId,
      'team_name': teamName,
      'performed_by_user_id': performedByUserId,
      'performed_by_user_email': performedByUserEmail,
      'notes': notes,
    };
  }

  factory ToolPackageMovementEvent.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) {
      final parsed = DateTime.tryParse((raw ?? '').toString().trim());
      return parsed ?? DateTime.now();
    }

    return ToolPackageMovementEvent(
      id: (map['id'] ?? '').toString().trim(),
      packageId: (map['package_id'] ?? map['packageId'] ?? '').toString().trim(),
      packageName:
          (map['package_name'] ?? map['packageName'] ?? '').toString().trim(),
      eventType: ToolPackageMovementEventType.fromValue(
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
