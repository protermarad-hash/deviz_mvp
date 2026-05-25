enum FieldCloudEntityType {
  users,
  teams,
  appointments,
  jobs,
  documents;

  String get value {
    switch (this) {
      case FieldCloudEntityType.users:
        return 'users';
      case FieldCloudEntityType.teams:
        return 'teams';
      case FieldCloudEntityType.appointments:
        return 'appointments';
      case FieldCloudEntityType.jobs:
        return 'jobs';
      case FieldCloudEntityType.documents:
        return 'documents';
    }
  }
}

class FieldCloudSyncItem {
  const FieldCloudSyncItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.syncedAt,
    this.retryCount = 0,
  });

  final String id;
  final FieldCloudEntityType entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final int retryCount;

  FieldCloudSyncItem copyWith({
    String? id,
    FieldCloudEntityType? entityType,
    String? entityId,
    String? operation,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    DateTime? syncedAt,
    int? retryCount,
  }) {
    return FieldCloudSyncItem(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'entity_type': entityType.value,
      'entity_id': entityId,
      'operation': operation,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  factory FieldCloudSyncItem.fromMap(Map<String, dynamic> map) {
    FieldCloudEntityType parseType(String raw) {
      for (final type in FieldCloudEntityType.values) {
        if (type.value == raw) return type;
      }
      return FieldCloudEntityType.documents;
    }

    return FieldCloudSyncItem(
      id: (map['id'] ?? '').toString(),
      entityType: parseType((map['entity_type'] ?? '').toString()),
      entityId: (map['entity_id'] ?? '').toString(),
      operation: (map['operation'] ?? '').toString(),
      payload: Map<String, dynamic>.from((map['payload'] ?? const {}) as Map),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      syncedAt: DateTime.tryParse((map['synced_at'] ?? '').toString()),
      retryCount: (map['retry_count'] is num)
          ? (map['retry_count'] as num).toInt()
          : int.tryParse('${map['retry_count'] ?? 0}') ?? 0,
    );
  }
}
