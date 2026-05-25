enum RegistryType {
  intrare,
  iesire;

  String get label {
    switch (this) {
      case RegistryType.intrare:
        return 'Intrare';
      case RegistryType.iesire:
        return 'Iesire';
    }
  }

  String get storageValue {
    switch (this) {
      case RegistryType.intrare:
        return 'intrare';
      case RegistryType.iesire:
        return 'iesire';
    }
  }

  String get defaultPrefix {
    switch (this) {
      case RegistryType.intrare:
        return 'IN';
      case RegistryType.iesire:
        return 'OUT';
    }
  }

  static RegistryType fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return RegistryType.values.firstWhere(
      (item) => item.storageValue == normalized,
      orElse: () => RegistryType.intrare,
    );
  }
}

class RegistryDocumentSeriesCatalog {
  static const String offer = 'offer';
  static const String complaint = 'complaint';
  static const String repairReport = 'repair_report';
  static const String warrantyReport = 'warranty_report';
  static const String complaintCentralizer = 'complaint_centralizer';
  static const String complaintWorkOrder = 'complaint_work_order';
  static const String travelOrder = 'travel_order';
  static const String agfrReport = 'agfr_report';

  static const List<String> configurableTypes = <String>[
    offer,
    complaint,
    repairReport,
    warrantyReport,
    complaintCentralizer,
    complaintWorkOrder,
    travelOrder,
    agfrReport,
  ];

  static const Map<String, String> _defaultPrefixes = <String, String>{
    offer: 'OFR',
    complaint: 'REC',
    repairReport: 'PVR',
    warrantyReport: 'PVG',
    complaintCentralizer: 'CTR',
    complaintWorkOrder: 'CMD',
    travelOrder: 'ORD',
    agfrReport: 'AGFR',
  };

  static String normalizeType(String rawType) {
    final normalized = rawType.trim().toLowerCase();
    return configurableTypes.contains(normalized) ? normalized : rawType;
  }

  static String defaultPrefix(String type) {
    return _defaultPrefixes[normalizeType(type)] ?? 'DOC';
  }

  static bool includeYear(String type) {
    switch (normalizeType(type)) {
      case travelOrder:
      case agfrReport:
        return true;
      default:
        return false;
    }
  }

  static String label(String type) {
    switch (normalizeType(type)) {
      case offer:
        return 'Oferta';
      case complaint:
        return 'Reclamatie';
      case repairReport:
        return 'PV reparatie';
      case warrantyReport:
        return 'PV garantie';
      case complaintCentralizer:
        return 'Centralizator reclamatii';
      case complaintWorkOrder:
        return 'Comanda lucrari';
      case travelOrder:
        return 'Ordin deplasare';
      case agfrReport:
        return 'Raport AGFR';
      default:
        return type;
    }
  }

  static String example(String type, {String? prefix, int? year}) {
    final rawPrefix = (prefix ?? defaultPrefix(type)).trim();
    final resolvedPrefix =
        rawPrefix.isEmpty ? defaultPrefix(type) : rawPrefix.toUpperCase();
    if (includeYear(type)) {
      return '$resolvedPrefix-${year ?? DateTime.now().year}-0001';
    }
    return '$resolvedPrefix-0001';
  }
}

class RegistrySettings {
  const RegistrySettings({
    this.incomingPrefix = 'IN',
    this.outgoingPrefix = 'OUT',
    this.resetSequenceYearly = true,
    this.defaultIncomingStatus = 'inregistrat',
    this.defaultOutgoingStatus = 'emis',
    this.documentSeriesPrefixes = const <String, String>{},
  });

  final String incomingPrefix;
  final String outgoingPrefix;
  final bool resetSequenceYearly;
  final String defaultIncomingStatus;
  final String defaultOutgoingStatus;
  final Map<String, String> documentSeriesPrefixes;

  String seriesPrefixFor(String type) {
    final normalizedType = RegistryDocumentSeriesCatalog.normalizeType(type);
    final configured = documentSeriesPrefixes[normalizedType]?.trim() ?? '';
    if (configured.isNotEmpty) {
      return configured.toUpperCase();
    }
    return RegistryDocumentSeriesCatalog.defaultPrefix(normalizedType);
  }

  RegistrySettings copyWith({
    String? incomingPrefix,
    String? outgoingPrefix,
    bool? resetSequenceYearly,
    String? defaultIncomingStatus,
    String? defaultOutgoingStatus,
    Map<String, String>? documentSeriesPrefixes,
  }) {
    return RegistrySettings(
      incomingPrefix: incomingPrefix ?? this.incomingPrefix,
      outgoingPrefix: outgoingPrefix ?? this.outgoingPrefix,
      resetSequenceYearly: resetSequenceYearly ?? this.resetSequenceYearly,
      defaultIncomingStatus:
          defaultIncomingStatus ?? this.defaultIncomingStatus,
      defaultOutgoingStatus:
          defaultOutgoingStatus ?? this.defaultOutgoingStatus,
      documentSeriesPrefixes:
          documentSeriesPrefixes ?? this.documentSeriesPrefixes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incoming_prefix': incomingPrefix,
      'outgoing_prefix': outgoingPrefix,
      'reset_sequence_yearly': resetSequenceYearly,
      'default_incoming_status': defaultIncomingStatus,
      'default_outgoing_status': defaultOutgoingStatus,
      'document_series_prefixes': documentSeriesPrefixes,
    };
  }

  factory RegistrySettings.fromMap(Map<String, dynamic> map) {
    final documentSeriesPrefixes = <String, String>{};
    final rawSeries = map['document_series_prefixes'];
    if (rawSeries is Map) {
      for (final entry in rawSeries.entries) {
        final key = RegistryDocumentSeriesCatalog.normalizeType(
          entry.key.toString(),
        );
        final value = entry.value.toString().trim();
        if (key.trim().isEmpty || value.isEmpty) {
          continue;
        }
        documentSeriesPrefixes[key] = value.toUpperCase();
      }
    }
    return RegistrySettings(
      incomingPrefix: (map['incoming_prefix'] ?? 'IN').toString(),
      outgoingPrefix: (map['outgoing_prefix'] ?? 'OUT').toString(),
      resetSequenceYearly: map['reset_sequence_yearly'] != false,
      defaultIncomingStatus:
          (map['default_incoming_status'] ?? 'inregistrat').toString(),
      defaultOutgoingStatus:
          (map['default_outgoing_status'] ?? 'emis').toString(),
      documentSeriesPrefixes: documentSeriesPrefixes,
    );
  }
}

class RegistryEntry {
  const RegistryEntry({
    required this.id,
    required this.registryNumber,
    required this.registryType,
    required this.sequenceNumber,
    required this.year,
    required this.registeredAt,
    required this.documentNumber,
    required this.documentDate,
    required this.documentTitle,
    required this.documentCategory,
    required this.issuerName,
    required this.recipientName,
    required this.notes,
    required this.status,
    this.clientId = '',
    this.jobId = '',
    this.offerId = '',
    this.estimateId = '',
    this.contractId = '',
    this.ticketId = '',
    this.filePath = '',
    this.fileName = '',
  });

  final String id;
  final String registryNumber;
  final RegistryType registryType;
  final int sequenceNumber;
  final int year;
  final DateTime registeredAt;
  final String documentNumber;
  final DateTime? documentDate;
  final String documentTitle;
  final String documentCategory;
  final String issuerName;
  final String recipientName;
  final String clientId;
  final String jobId;
  final String offerId;
  final String estimateId;
  final String contractId;
  final String ticketId;
  final String filePath;
  final String fileName;
  final String notes;
  final String status;

  RegistryEntry copyWith({
    String? id,
    String? registryNumber,
    RegistryType? registryType,
    int? sequenceNumber,
    int? year,
    DateTime? registeredAt,
    String? documentNumber,
    DateTime? documentDate,
    String? documentTitle,
    String? documentCategory,
    String? issuerName,
    String? recipientName,
    String? clientId,
    String? jobId,
    String? offerId,
    String? estimateId,
    String? contractId,
    String? ticketId,
    String? filePath,
    String? fileName,
    String? notes,
    String? status,
  }) {
    return RegistryEntry(
      id: id ?? this.id,
      registryNumber: registryNumber ?? this.registryNumber,
      registryType: registryType ?? this.registryType,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      year: year ?? this.year,
      registeredAt: registeredAt ?? this.registeredAt,
      documentNumber: documentNumber ?? this.documentNumber,
      documentDate: documentDate ?? this.documentDate,
      documentTitle: documentTitle ?? this.documentTitle,
      documentCategory: documentCategory ?? this.documentCategory,
      issuerName: issuerName ?? this.issuerName,
      recipientName: recipientName ?? this.recipientName,
      clientId: clientId ?? this.clientId,
      jobId: jobId ?? this.jobId,
      offerId: offerId ?? this.offerId,
      estimateId: estimateId ?? this.estimateId,
      contractId: contractId ?? this.contractId,
      ticketId: ticketId ?? this.ticketId,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'registry_number': registryNumber,
      'registry_type': registryType.storageValue,
      'sequence_number': sequenceNumber,
      'year': year,
      'registered_at': registeredAt.toIso8601String(),
      'document_number': documentNumber,
      'document_date': documentDate?.toIso8601String(),
      'document_title': documentTitle,
      'document_category': documentCategory,
      'issuer_name': issuerName,
      'recipient_name': recipientName,
      'client_id': clientId,
      'job_id': jobId,
      'offer_id': offerId,
      'estimate_id': estimateId,
      'contract_id': contractId,
      'ticket_id': ticketId,
      'file_path': filePath,
      'file_name': fileName,
      'notes': notes,
      'status': status,
    };
  }

  factory RegistryEntry.fromMap(Map<String, dynamic> map) {
    return RegistryEntry(
      id: (map['id'] ?? '').toString(),
      registryNumber: (map['registry_number'] ?? '').toString(),
      registryType: RegistryType.fromValue(
        (map['registry_type'] ?? 'intrare').toString(),
      ),
      sequenceNumber: map['sequence_number'] is num
          ? (map['sequence_number'] as num).toInt()
          : int.tryParse((map['sequence_number'] ?? '0').toString()) ?? 0,
      year: map['year'] is num
          ? (map['year'] as num).toInt()
          : int.tryParse((map['year'] ?? '0').toString()) ??
              DateTime.now().year,
      registeredAt: DateTime.tryParse(
            (map['registered_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      documentNumber: (map['document_number'] ?? '').toString(),
      documentDate: DateTime.tryParse((map['document_date'] ?? '').toString()),
      documentTitle: (map['document_title'] ?? '').toString(),
      documentCategory: (map['document_category'] ?? '').toString(),
      issuerName: (map['issuer_name'] ?? '').toString(),
      recipientName: (map['recipient_name'] ?? '').toString(),
      clientId: (map['client_id'] ?? '').toString(),
      jobId: (map['job_id'] ?? '').toString(),
      offerId: (map['offer_id'] ?? '').toString(),
      estimateId: (map['estimate_id'] ?? '').toString(),
      contractId: (map['contract_id'] ?? '').toString(),
      ticketId: (map['ticket_id'] ?? '').toString(),
      filePath: (map['file_path'] ?? '').toString(),
      fileName: (map['file_name'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
    );
  }
}
