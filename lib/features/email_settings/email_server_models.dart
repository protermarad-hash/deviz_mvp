import 'package:cloud_firestore/cloud_firestore.dart';

enum EmailServerProviderPreset {
  custom,
  outlook365,
  gmail,
  hostinger,
  zoho;

  String get value {
    switch (this) {
      case EmailServerProviderPreset.custom:
        return 'custom_smtp';
      case EmailServerProviderPreset.outlook365:
        return 'outlook_microsoft_365';
      case EmailServerProviderPreset.gmail:
        return 'gmail';
      case EmailServerProviderPreset.hostinger:
        return 'hostinger';
      case EmailServerProviderPreset.zoho:
        return 'zoho';
    }
  }

  String get label {
    switch (this) {
      case EmailServerProviderPreset.custom:
        return 'Custom SMTP';
      case EmailServerProviderPreset.outlook365:
        return 'Outlook / Microsoft 365';
      case EmailServerProviderPreset.gmail:
        return 'Gmail';
      case EmailServerProviderPreset.hostinger:
        return 'Hostinger';
      case EmailServerProviderPreset.zoho:
        return 'Zoho';
    }
  }

  String get defaultHost {
    switch (this) {
      case EmailServerProviderPreset.custom:
        return '';
      case EmailServerProviderPreset.outlook365:
        return 'smtp.office365.com';
      case EmailServerProviderPreset.gmail:
        return 'smtp.gmail.com';
      case EmailServerProviderPreset.hostinger:
        return 'smtp.hostinger.com';
      case EmailServerProviderPreset.zoho:
        return 'smtp.zoho.com';
    }
  }

  int get defaultPort {
    switch (this) {
      case EmailServerProviderPreset.custom:
        return 587;
      case EmailServerProviderPreset.outlook365:
        return 587;
      case EmailServerProviderPreset.gmail:
        return 587;
      case EmailServerProviderPreset.hostinger:
        return 465;
      case EmailServerProviderPreset.zoho:
        return 465;
    }
  }

  bool get defaultSecure {
    switch (this) {
      case EmailServerProviderPreset.custom:
        return false;
      case EmailServerProviderPreset.outlook365:
        return false;
      case EmailServerProviderPreset.gmail:
        return false;
      case EmailServerProviderPreset.hostinger:
        return true;
      case EmailServerProviderPreset.zoho:
        return true;
    }
  }

  static EmailServerProviderPreset fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return EmailServerProviderPreset.values.firstWhere(
      (item) => item.value == normalized,
      orElse: () => EmailServerProviderPreset.custom,
    );
  }
}

class EmailServerConfigRecord {
  const EmailServerConfigRecord({
    required this.id,
    required this.provider,
    required this.host,
    required this.port,
    required this.secure,
    required this.username,
    required this.passwordEncrypted,
    required this.fromEmail,
    required this.fromName,
    required this.replyToEmail,
    required this.enabled,
    required this.isActive,
    this.lastTestAt,
    this.lastTestStatus = '',
    this.lastTestError = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final EmailServerProviderPreset provider;
  final String host;
  final int port;
  final bool secure;
  final String username;
  final String passwordEncrypted;
  final String fromEmail;
  final String fromName;
  final String replyToEmail;
  final bool enabled;
  final bool isActive;
  final DateTime? lastTestAt;
  final String lastTestStatus;
  final String lastTestError;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasStoredPassword => passwordEncrypted.trim().isNotEmpty;

  EmailServerConfigRecord copyWith({
    String? id,
    EmailServerProviderPreset? provider,
    String? host,
    int? port,
    bool? secure,
    String? username,
    String? passwordEncrypted,
    String? fromEmail,
    String? fromName,
    String? replyToEmail,
    bool? enabled,
    bool? isActive,
    DateTime? lastTestAt,
    bool clearLastTestAt = false,
    String? lastTestStatus,
    String? lastTestError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmailServerConfigRecord(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      host: host ?? this.host,
      port: port ?? this.port,
      secure: secure ?? this.secure,
      username: username ?? this.username,
      passwordEncrypted: passwordEncrypted ?? this.passwordEncrypted,
      fromEmail: fromEmail ?? this.fromEmail,
      fromName: fromName ?? this.fromName,
      replyToEmail: replyToEmail ?? this.replyToEmail,
      enabled: enabled ?? this.enabled,
      isActive: isActive ?? this.isActive,
      lastTestAt: clearLastTestAt ? null : (lastTestAt ?? this.lastTestAt),
      lastTestStatus: lastTestStatus ?? this.lastTestStatus,
      lastTestError: lastTestError ?? this.lastTestError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'provider': provider.value,
      'host': host,
      'port': port,
      'secure': secure,
      'username': username,
      'password_encrypted': passwordEncrypted,
      'from_email': fromEmail,
      'from_name': fromName,
      'reply_to_email': replyToEmail,
      'enabled': enabled,
      'is_active': isActive,
      'last_test_at': lastTestAt?.toIso8601String(),
      'last_test_status': lastTestStatus,
      'last_test_error': lastTestError,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory EmailServerConfigRecord.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw, DateTime fallback) {
      if (raw is Timestamp) return raw.toDate();
      return DateTime.tryParse((raw ?? '').toString()) ?? fallback;
    }

    DateTime? parseNullableDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      return DateTime.tryParse((raw ?? '').toString());
    }

    bool parseBool(dynamic raw) {
      if (raw is bool) return raw;
      final value = (raw ?? '').toString().trim().toLowerCase();
      return value == 'true' || value == '1' || value == 'yes';
    }

    final now = DateTime.now();
    return EmailServerConfigRecord(
      id: (map['id'] ?? '').toString().trim(),
      provider: EmailServerProviderPreset.fromValue(
        (map['provider'] ?? '').toString(),
      ),
      host: (map['host'] ?? '').toString().trim(),
      port: int.tryParse((map['port'] ?? '0').toString()) ?? 0,
      secure: parseBool(map['secure']),
      username: (map['username'] ?? '').toString().trim(),
      passwordEncrypted:
          (map['password_encrypted'] ?? map['passwordEncrypted'] ?? '')
              .toString()
              .trim(),
      fromEmail:
          (map['from_email'] ?? map['fromEmail'] ?? '').toString().trim(),
      fromName: (map['from_name'] ?? map['fromName'] ?? '').toString().trim(),
      replyToEmail: (map['reply_to_email'] ?? map['replyToEmail'] ?? '')
          .toString()
          .trim(),
      enabled: parseBool(map['enabled']),
      isActive: parseBool(map['is_active'] ?? map['isActive']),
      lastTestAt: parseNullableDate(map['last_test_at'] ?? map['lastTestAt']),
      lastTestStatus: (map['last_test_status'] ?? map['lastTestStatus'] ?? '')
          .toString()
          .trim(),
      lastTestError: (map['last_test_error'] ?? map['lastTestError'] ?? '')
          .toString()
          .trim(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt'], now),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt'], now),
    );
  }
}

enum EmailDeliveryStatus {
  queued,
  sending,
  sent,
  failed;

  String get value {
    switch (this) {
      case EmailDeliveryStatus.queued:
        return 'queued';
      case EmailDeliveryStatus.sending:
        return 'sending';
      case EmailDeliveryStatus.sent:
        return 'sent';
      case EmailDeliveryStatus.failed:
        return 'failed';
    }
  }

  static EmailDeliveryStatus fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return EmailDeliveryStatus.values.firstWhere(
      (item) => item.value == normalized,
      orElse: () => EmailDeliveryStatus.queued,
    );
  }
}

class EmailDeliveryLogRecord {
  const EmailDeliveryLogRecord({
    required this.id,
    required this.sourceModule,
    required this.sourceEntityId,
    required this.to,
    required this.subject,
    required this.status,
    required this.attemptCount,
    required this.errorMessage,
    required this.providerMessageId,
    required this.createdAt,
    this.sentAt,
  });

  final String id;
  final String sourceModule;
  final String sourceEntityId;
  final String to;
  final String subject;
  final EmailDeliveryStatus status;
  final int attemptCount;
  final String errorMessage;
  final String providerMessageId;
  final DateTime createdAt;
  final DateTime? sentAt;

  factory EmailDeliveryLogRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    DateTime parseDate(dynamic raw, DateTime fallback) {
      if (raw is Timestamp) return raw.toDate();
      return DateTime.tryParse((raw ?? '').toString()) ?? fallback;
    }

    DateTime? parseNullableDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      return DateTime.tryParse((raw ?? '').toString());
    }

    return EmailDeliveryLogRecord(
      id: (map['id'] ?? '').toString().trim(),
      sourceModule:
          (map['source_module'] ?? map['sourceModule'] ?? '').toString().trim(),
      sourceEntityId: (map['source_entity_id'] ?? map['sourceEntityId'] ?? '')
          .toString()
          .trim(),
      to: (map['to'] ?? '').toString().trim(),
      subject: (map['subject'] ?? '').toString().trim(),
      status: EmailDeliveryStatus.fromValue(
        (map['status'] ?? '').toString(),
      ),
      attemptCount: int.tryParse(
              (map['attempt_count'] ?? map['attemptCount'] ?? '0')
                  .toString()) ??
          0,
      errorMessage:
          (map['error_message'] ?? map['errorMessage'] ?? '').toString().trim(),
      providerMessageId:
          (map['provider_message_id'] ?? map['providerMessageId'] ?? '')
              .toString()
              .trim(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt'], now),
      sentAt: parseNullableDate(map['sent_at'] ?? map['sentAt']),
    );
  }
}
