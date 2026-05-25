enum OfferSmartBillDocumentType {
  estimate,
  invoice;

  String get value {
    switch (this) {
      case OfferSmartBillDocumentType.estimate:
        return 'estimate';
      case OfferSmartBillDocumentType.invoice:
        return 'invoice';
    }
  }

  String get label {
    switch (this) {
      case OfferSmartBillDocumentType.estimate:
        return 'Proforma';
      case OfferSmartBillDocumentType.invoice:
        return 'Factura';
    }
  }

  static OfferSmartBillDocumentType fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return OfferSmartBillDocumentType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => OfferSmartBillDocumentType.estimate,
    );
  }
}

enum OfferSmartBillSyncStatus {
  idle,
  issued,
  error;

  String get value {
    switch (this) {
      case OfferSmartBillSyncStatus.idle:
        return 'idle';
      case OfferSmartBillSyncStatus.issued:
        return 'issued';
      case OfferSmartBillSyncStatus.error:
        return 'error';
    }
  }

  String get label {
    switch (this) {
      case OfferSmartBillSyncStatus.idle:
        return 'Neemis';
      case OfferSmartBillSyncStatus.issued:
        return 'Emis';
      case OfferSmartBillSyncStatus.error:
        return 'Eroare';
    }
  }

  static OfferSmartBillSyncStatus fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return OfferSmartBillSyncStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => OfferSmartBillSyncStatus.idle,
    );
  }
}

class OfferSmartBillPaymentStatus {
  const OfferSmartBillPaymentStatus({
    this.invoiceTotalAmount = 0,
    this.paidAmount = 0,
    this.unpaidAmount = 0,
    this.checkedAt,
  });

  final double invoiceTotalAmount;
  final double paidAmount;
  final double unpaidAmount;
  final DateTime? checkedAt;

  bool get hasValues =>
      invoiceTotalAmount != 0 || paidAmount != 0 || unpaidAmount != 0;

  OfferSmartBillPaymentStatus copyWith({
    double? invoiceTotalAmount,
    double? paidAmount,
    double? unpaidAmount,
    DateTime? checkedAt,
    bool clearCheckedAt = false,
  }) {
    return OfferSmartBillPaymentStatus(
      invoiceTotalAmount: invoiceTotalAmount ?? this.invoiceTotalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      unpaidAmount: unpaidAmount ?? this.unpaidAmount,
      checkedAt: clearCheckedAt ? null : (checkedAt ?? this.checkedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'invoice_total_amount': invoiceTotalAmount,
      'paid_amount': paidAmount,
      'unpaid_amount': unpaidAmount,
      'checked_at': checkedAt?.toIso8601String(),
    };
  }

  factory OfferSmartBillPaymentStatus.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic raw, [double fallback = 0]) {
      if (raw == null) return fallback;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString().replaceAll(',', '.').trim()) ??
          fallback;
    }

    DateTime? parseOptionalDate(dynamic raw) {
      if (raw == null) return null;
      final text = raw.toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    return OfferSmartBillPaymentStatus(
      invoiceTotalAmount: asDouble(
        map['invoice_total_amount'] ?? map['invoiceTotalAmount'],
      ),
      paidAmount: asDouble(map['paid_amount'] ?? map['paidAmount']),
      unpaidAmount: asDouble(map['unpaid_amount'] ?? map['unpaidAmount']),
      checkedAt: parseOptionalDate(map['checked_at'] ?? map['checkedAt']),
    );
  }
}

class OfferSmartBillDocumentState {
  const OfferSmartBillDocumentState({
    required this.documentType,
    this.syncStatus = OfferSmartBillSyncStatus.idle,
    this.seriesName = '',
    this.number = '',
    this.documentUrl = '',
    this.documentViewUrl = '',
    this.publicUrl = '',
    this.documentId = '',
    this.isDraft = false,
    this.issuedAt,
    this.lastSyncedAt,
    this.lastError = '',
    this.paymentStatus = const OfferSmartBillPaymentStatus(),
  });

  final OfferSmartBillDocumentType documentType;
  final OfferSmartBillSyncStatus syncStatus;
  final String seriesName;
  final String number;
  final String documentUrl;
  final String documentViewUrl;
  final String publicUrl;
  final String documentId;
  final bool isDraft;
  final DateTime? issuedAt;
  final DateTime? lastSyncedAt;
  final String lastError;
  final OfferSmartBillPaymentStatus paymentStatus;

  bool get hasDocument =>
      seriesName.trim().isNotEmpty && number.trim().isNotEmpty;

  OfferSmartBillDocumentState copyWith({
    OfferSmartBillDocumentType? documentType,
    OfferSmartBillSyncStatus? syncStatus,
    String? seriesName,
    String? number,
    String? documentUrl,
    String? documentViewUrl,
    String? publicUrl,
    String? documentId,
    bool? isDraft,
    DateTime? issuedAt,
    bool clearIssuedAt = false,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
    String? lastError,
    OfferSmartBillPaymentStatus? paymentStatus,
  }) {
    return OfferSmartBillDocumentState(
      documentType: documentType ?? this.documentType,
      syncStatus: syncStatus ?? this.syncStatus,
      seriesName: seriesName ?? this.seriesName,
      number: number ?? this.number,
      documentUrl: documentUrl ?? this.documentUrl,
      documentViewUrl: documentViewUrl ?? this.documentViewUrl,
      publicUrl: publicUrl ?? this.publicUrl,
      documentId: documentId ?? this.documentId,
      isDraft: isDraft ?? this.isDraft,
      issuedAt: clearIssuedAt ? null : (issuedAt ?? this.issuedAt),
      lastSyncedAt:
          clearLastSyncedAt ? null : (lastSyncedAt ?? this.lastSyncedAt),
      lastError: lastError ?? this.lastError,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'document_type': documentType.value,
      'sync_status': syncStatus.value,
      'series_name': seriesName,
      'number': number,
      'document_url': documentUrl,
      'document_view_url': documentViewUrl,
      'public_url': publicUrl,
      'document_id': documentId,
      'is_draft': isDraft,
      'issued_at': issuedAt?.toIso8601String(),
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'last_error': lastError,
      'payment_status': paymentStatus.toMap(),
    };
  }

  factory OfferSmartBillDocumentState.fromMap(
    Map<String, dynamic> map, {
    OfferSmartBillDocumentType? fallbackDocumentType,
  }) {
    DateTime? parseOptionalDate(dynamic raw) {
      if (raw == null) return null;
      final text = raw.toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    bool parseBool(dynamic raw, [bool fallback = false]) {
      if (raw == null) return fallback;
      if (raw is bool) return raw;
      final text = raw.toString().trim().toLowerCase();
      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
      return fallback;
    }

    OfferSmartBillPaymentStatus readPaymentStatus() {
      final raw = map['payment_status'] ?? map['paymentStatus'];
      if (raw is Map<String, dynamic>) {
        return OfferSmartBillPaymentStatus.fromMap(raw);
      }
      if (raw is Map) {
        return OfferSmartBillPaymentStatus.fromMap(
          Map<String, dynamic>.from(raw),
        );
      }
      return const OfferSmartBillPaymentStatus();
    }

    return OfferSmartBillDocumentState(
      documentType: OfferSmartBillDocumentType.fromValue(
        (map['document_type'] ??
                map['documentType'] ??
                fallbackDocumentType?.value)
            ?.toString(),
      ),
      syncStatus: OfferSmartBillSyncStatus.fromValue(
        (map['sync_status'] ?? map['syncStatus'])?.toString(),
      ),
      seriesName:
          (map['series_name'] ?? map['seriesName'] ?? '').toString().trim(),
      number: (map['number'] ?? '').toString().trim(),
      documentUrl:
          (map['document_url'] ?? map['documentUrl'] ?? '').toString().trim(),
      documentViewUrl:
          (map['document_view_url'] ?? map['documentViewUrl'] ?? '')
              .toString()
              .trim(),
      publicUrl:
          (map['public_url'] ?? map['publicUrl'] ?? '').toString().trim(),
      documentId:
          (map['document_id'] ?? map['documentId'] ?? '').toString().trim(),
      isDraft: parseBool(map['is_draft'] ?? map['isDraft']),
      issuedAt: parseOptionalDate(map['issued_at'] ?? map['issuedAt']),
      lastSyncedAt:
          parseOptionalDate(map['last_synced_at'] ?? map['lastSyncedAt']),
      lastError:
          (map['last_error'] ?? map['lastError'] ?? '').toString().trim(),
      paymentStatus: readPaymentStatus(),
    );
  }
}
