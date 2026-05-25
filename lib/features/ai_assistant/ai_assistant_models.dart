import 'dart:convert';

enum AiAssistantContextType {
  offers,
  complaints,
  fieldSales,
  jobs,
}

extension AiAssistantContextTypeX on AiAssistantContextType {
  String get value {
    switch (this) {
      case AiAssistantContextType.offers:
        return 'offers';
      case AiAssistantContextType.complaints:
        return 'complaints';
      case AiAssistantContextType.fieldSales:
        return 'field_sales';
      case AiAssistantContextType.jobs:
        return 'jobs';
    }
  }

  String get label {
    switch (this) {
      case AiAssistantContextType.offers:
        return 'Oferte';
      case AiAssistantContextType.complaints:
        return 'Reclamatii / Garantie';
      case AiAssistantContextType.fieldSales:
        return 'Agent teren';
      case AiAssistantContextType.jobs:
        return 'Lucrări / PV / PIF';
    }
  }
}

enum AiAssistantSessionStatus {
  idle,
  generating,
  ready,
  unavailable,
  error,
}

extension AiAssistantSessionStatusX on AiAssistantSessionStatus {
  String get value {
    switch (this) {
      case AiAssistantSessionStatus.idle:
        return 'idle';
      case AiAssistantSessionStatus.generating:
        return 'generating';
      case AiAssistantSessionStatus.ready:
        return 'ready';
      case AiAssistantSessionStatus.unavailable:
        return 'unavailable';
      case AiAssistantSessionStatus.error:
        return 'error';
    }
  }
}

enum AiAssistantMessageRole {
  system,
  user,
  assistant,
  tool,
}

extension AiAssistantMessageRoleX on AiAssistantMessageRole {
  String get value {
    switch (this) {
      case AiAssistantMessageRole.system:
        return 'system';
      case AiAssistantMessageRole.user:
        return 'user';
      case AiAssistantMessageRole.assistant:
        return 'assistant';
      case AiAssistantMessageRole.tool:
        return 'tool';
    }
  }
}

enum AiAssistantDraftStatus {
  suggestion,
  saved,
  approved,
}

extension AiAssistantDraftStatusX on AiAssistantDraftStatus {
  String get label {
    switch (this) {
      case AiAssistantDraftStatus.suggestion:
        return 'Sugestie AI';
      case AiAssistantDraftStatus.saved:
        return 'Draft salvat';
      case AiAssistantDraftStatus.approved:
        return 'Text aprobat';
    }
  }
}

enum AiAssistantInsertMode {
  replace,
  append,
}

class AiAssistantMessageRecord {
  const AiAssistantMessageRecord({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final AiAssistantMessageRole role;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  AiAssistantMessageRecord copyWith({
    String? id,
    AiAssistantMessageRole? role,
    String? content,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return AiAssistantMessageRecord(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'role': role.value,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}

class AiAssistantSessionRecord {
  const AiAssistantSessionRecord({
    required this.id,
    required this.module,
    required this.entityId,
    required this.entityLabel,
    required this.userId,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.lastSuggestedAction = '',
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final AiAssistantContextType module;
  final String entityId;
  final String entityLabel;
  final String userId;
  final List<AiAssistantMessageRecord> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AiAssistantSessionStatus status;
  final String lastSuggestedAction;
  final Map<String, dynamic> metadata;

  AiAssistantSessionRecord copyWith({
    String? id,
    AiAssistantContextType? module,
    String? entityId,
    String? entityLabel,
    String? userId,
    List<AiAssistantMessageRecord>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    AiAssistantSessionStatus? status,
    String? lastSuggestedAction,
    Map<String, dynamic>? metadata,
  }) {
    return AiAssistantSessionRecord(
      id: id ?? this.id,
      module: module ?? this.module,
      entityId: entityId ?? this.entityId,
      entityLabel: entityLabel ?? this.entityLabel,
      userId: userId ?? this.userId,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      lastSuggestedAction: lastSuggestedAction ?? this.lastSuggestedAction,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'module': module.value,
      'entity_id': entityId,
      'entity_label': entityLabel,
      'user_id': userId,
      'messages': messages.map((item) => item.toMap()).toList(growable: false),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'status': status.value,
      'last_suggested_action': lastSuggestedAction,
      'metadata': metadata,
    };
  }
}

class AiAssistantInsertionTarget {
  const AiAssistantInsertionTarget({
    required this.key,
    required this.label,
    this.description = '',
    this.insertMode = AiAssistantInsertMode.replace,
  });

  final String key;
  final String label;
  final String description;
  final AiAssistantInsertMode insertMode;
}

class AiAssistantQuickAction {
  const AiAssistantQuickAction({
    required this.id,
    required this.contextType,
    required this.label,
    required this.description,
    required this.defaultPrompt,
    required this.toolNames,
    this.defaultTargetKey = '',
    this.delicate = false,
  });

  final String id;
  final AiAssistantContextType contextType;
  final String label;
  final String description;
  final String defaultPrompt;
  final List<String> toolNames;
  final String defaultTargetKey;
  final bool delicate;
}

class AiAssistantDraft {
  const AiAssistantDraft({
    required this.id,
    required this.actionId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.status,
    this.targetKey = '',
    this.disclaimer = '',
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String actionId;
  final String title;
  final String content;
  final DateTime createdAt;
  final AiAssistantDraftStatus status;
  final String targetKey;
  final String disclaimer;
  final Map<String, dynamic> metadata;

  AiAssistantDraft copyWith({
    String? id,
    String? actionId,
    String? title,
    String? content,
    DateTime? createdAt,
    AiAssistantDraftStatus? status,
    String? targetKey,
    String? disclaimer,
    Map<String, dynamic>? metadata,
  }) {
    return AiAssistantDraft(
      id: id ?? this.id,
      actionId: actionId ?? this.actionId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      targetKey: targetKey ?? this.targetKey,
      disclaimer: disclaimer ?? this.disclaimer,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'action_id': actionId,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'status': status.label,
      'target_key': targetKey,
      'disclaimer': disclaimer,
      'metadata': metadata,
    };
  }
}

class AiAssistantRuntimeContext {
  const AiAssistantRuntimeContext({
    required this.contextType,
    required this.module,
    required this.entityId,
    required this.entityLabel,
    required this.userId,
    required this.contextLabel,
    this.primaryData = const <String, dynamic>{},
    this.relatedData = const <String, dynamic>{},
    this.insertionTargets = const <AiAssistantInsertionTarget>[],
    this.metadata = const <String, dynamic>{},
  });

  final AiAssistantContextType contextType;
  final String module;
  final String entityId;
  final String entityLabel;
  final String userId;
  final String contextLabel;
  final Map<String, dynamic> primaryData;
  final Map<String, dynamic> relatedData;
  final List<AiAssistantInsertionTarget> insertionTargets;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toPromptPayload() {
    return <String, dynamic>{
      'module': module,
      'entity_id': entityId,
      'entity_label': entityLabel,
      'context_label': contextLabel,
      'primary': primaryData,
      'related': relatedData,
      'targets': insertionTargets
          .map(
            (item) => <String, dynamic>{
              'key': item.key,
              'label': item.label,
              'description': item.description,
              'insert_mode': item.insertMode.name,
            },
          )
          .toList(growable: false),
      'metadata': metadata,
    };
  }

  String toPromptJson() => const JsonEncoder.withIndent('  ').convert(
        toPromptPayload(),
      );
}

class AiAssistantToolDefinition {
  const AiAssistantToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toResponsesToolMap() {
    return <String, dynamic>{
      'type': 'function',
      'name': name,
      'description': description,
      'parameters': parameters,
      'strict': false,
    };
  }

  Map<String, dynamic> toClaudeToolMap() {
    return <String, dynamic>{
      'name': name,
      'description': description,
      'input_schema': parameters,
    };
  }
}

class AiAssistantRunResult {
  const AiAssistantRunResult({
    required this.session,
    required this.status,
    this.draft,
    this.rawOutput = '',
    this.unavailableReason = '',
    this.toolTrace = const <Map<String, dynamic>>[],
  });

  final AiAssistantSessionRecord session;
  final AiAssistantSessionStatus status;
  final AiAssistantDraft? draft;
  final String rawOutput;
  final String unavailableReason;
  final List<Map<String, dynamic>> toolTrace;
}
