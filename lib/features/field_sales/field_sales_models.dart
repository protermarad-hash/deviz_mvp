enum FieldLeadInterestType {
  produs,
  serviciu,
  programare,
  oferta;

  String get value {
    switch (this) {
      case FieldLeadInterestType.produs:
        return 'produs';
      case FieldLeadInterestType.serviciu:
        return 'serviciu';
      case FieldLeadInterestType.programare:
        return 'programare';
      case FieldLeadInterestType.oferta:
        return 'oferta';
    }
  }

  String get label {
    switch (this) {
      case FieldLeadInterestType.produs:
        return 'Produs';
      case FieldLeadInterestType.serviciu:
        return 'Serviciu';
      case FieldLeadInterestType.programare:
        return 'Programare';
      case FieldLeadInterestType.oferta:
        return 'Oferta';
    }
  }

  static FieldLeadInterestType fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return FieldLeadInterestType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => FieldLeadInterestType.serviciu,
    );
  }
}

enum FieldLeadStatus {
  nou,
  inAsteptare,
  contactat,
  programat,
  convertit,
  pierdut;

  String get value {
    switch (this) {
      case FieldLeadStatus.nou:
        return 'nou';
      case FieldLeadStatus.inAsteptare:
        return 'in_asteptare';
      case FieldLeadStatus.contactat:
        return 'contactat';
      case FieldLeadStatus.programat:
        return 'programat';
      case FieldLeadStatus.convertit:
        return 'convertit';
      case FieldLeadStatus.pierdut:
        return 'pierdut';
    }
  }

  String get label {
    switch (this) {
      case FieldLeadStatus.nou:
        return 'Nou';
      case FieldLeadStatus.inAsteptare:
        return 'In asteptare';
      case FieldLeadStatus.contactat:
        return 'Contactat';
      case FieldLeadStatus.programat:
        return 'Programat';
      case FieldLeadStatus.convertit:
        return 'Convertit';
      case FieldLeadStatus.pierdut:
        return 'Pierdut';
    }
  }

  static FieldLeadStatus fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return FieldLeadStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => FieldLeadStatus.nou,
    );
  }
}

enum FieldSalesRequestType {
  vanzareProdus,
  serviciu,
  programare,
  oferta;

  String get value {
    switch (this) {
      case FieldSalesRequestType.vanzareProdus:
        return 'vanzare_produs';
      case FieldSalesRequestType.serviciu:
        return 'serviciu';
      case FieldSalesRequestType.programare:
        return 'programare';
      case FieldSalesRequestType.oferta:
        return 'oferta';
    }
  }

  String get label {
    switch (this) {
      case FieldSalesRequestType.vanzareProdus:
        return 'Vanzare produs';
      case FieldSalesRequestType.serviciu:
        return 'Serviciu';
      case FieldSalesRequestType.programare:
        return 'Programare';
      case FieldSalesRequestType.oferta:
        return 'Oferta';
    }
  }

  static FieldSalesRequestType fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return FieldSalesRequestType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => FieldSalesRequestType.serviciu,
    );
  }
}

enum FieldSalesRequestApprovalStatus {
  draft,
  trimisa,
  aprobata,
  respinsa;

  String get value {
    switch (this) {
      case FieldSalesRequestApprovalStatus.draft:
        return 'draft';
      case FieldSalesRequestApprovalStatus.trimisa:
        return 'trimisa';
      case FieldSalesRequestApprovalStatus.aprobata:
        return 'aprobata';
      case FieldSalesRequestApprovalStatus.respinsa:
        return 'respinsa';
    }
  }

  String get label {
    switch (this) {
      case FieldSalesRequestApprovalStatus.draft:
        return 'Draft';
      case FieldSalesRequestApprovalStatus.trimisa:
        return 'Trimisa';
      case FieldSalesRequestApprovalStatus.aprobata:
        return 'Aprobata';
      case FieldSalesRequestApprovalStatus.respinsa:
        return 'Respinsa';
    }
  }

  static FieldSalesRequestApprovalStatus fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return FieldSalesRequestApprovalStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => FieldSalesRequestApprovalStatus.draft,
    );
  }
}

class FieldSalesProductSelection {
  const FieldSalesProductSelection({
    required this.productId,
    required this.productName,
    this.quantity = 1,
    this.unitPrice = 0,
    this.currency = 'RON',
    this.notes = '',
  });

  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final String currency;
  final String notes;

  double get lineTotal => quantity * unitPrice;

  FieldSalesProductSelection copyWith({
    String? productId,
    String? productName,
    double? quantity,
    double? unitPrice,
    String? currency,
    String? notes,
  }) {
    return FieldSalesProductSelection(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'currency': currency,
      'notes': notes,
    };
  }

  factory FieldSalesProductSelection.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    return FieldSalesProductSelection(
      productId:
          (map['product_id'] ?? map['productId'] ?? '').toString().trim(),
      productName:
          (map['product_name'] ?? map['productName'] ?? '').toString().trim(),
      quantity: parseDouble(map['quantity']),
      unitPrice: parseDouble(map['unit_price'] ?? map['unitPrice']),
      currency: (map['currency'] ?? 'RON').toString().trim(),
      notes: (map['notes'] ?? '').toString().trim(),
    );
  }
}

class FieldSalesServicePresetSelection {
  const FieldSalesServicePresetSelection({
    required this.code,
    required this.label,
    this.category = '',
    this.laborTemplateId = '',
    this.unit = 'serv',
    this.quantity = 1,
    this.unitPrice = 0,
    this.currency = 'RON',
    this.notes = '',
    this.includedServices = '',
  });

  final String code;
  final String label;
  final String category;
  final String laborTemplateId;
  final String unit;
  final double quantity;
  final double unitPrice;
  final String currency;
  final String notes;
  final String includedServices;

  double get lineTotal => quantity * unitPrice;

  FieldSalesServicePresetSelection copyWith({
    String? code,
    String? label,
    String? category,
    String? laborTemplateId,
    String? unit,
    double? quantity,
    double? unitPrice,
    String? currency,
    String? notes,
    String? includedServices,
  }) {
    return FieldSalesServicePresetSelection(
      code: code ?? this.code,
      label: label ?? this.label,
      category: category ?? this.category,
      laborTemplateId: laborTemplateId ?? this.laborTemplateId,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      includedServices: includedServices ?? this.includedServices,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'code': code,
      'label': label,
      'category': category,
      'labor_template_id': laborTemplateId,
      'unit': unit,
      'quantity': quantity,
      'unit_price': unitPrice,
      'currency': currency,
      'notes': notes,
      'included_services': includedServices,
    };
  }

  factory FieldSalesServicePresetSelection.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    return FieldSalesServicePresetSelection(
      code: (map['code'] ?? '').toString().trim(),
      label: (map['label'] ?? '').toString().trim(),
      category: (map['category'] ?? '').toString().trim(),
      laborTemplateId:
          (map['labor_template_id'] ?? map['laborTemplateId'] ?? '')
              .toString()
              .trim(),
      unit: (map['unit'] ?? 'serv').toString().trim(),
      quantity: parseDouble(map['quantity']),
      unitPrice: parseDouble(map['unit_price'] ?? map['unitPrice']),
      currency: (map['currency'] ?? 'RON').toString().trim(),
      notes: (map['notes'] ?? '').toString().trim(),
      includedServices:
          (map['included_services'] ?? map['includedServices'] ?? '')
              .toString()
              .trim(),
    );
  }
}

class FieldSalesServicePresetDefinition {
  const FieldSalesServicePresetDefinition({
    required this.code,
    required this.label,
    this.unit = 'serv',
  });

  final String code;
  final String label;
  final String unit;
}

const List<FieldSalesServicePresetDefinition> kFieldSalesServicePresets =
    <FieldSalesServicePresetDefinition>[
  FieldSalesServicePresetDefinition(code: 'montaj', label: 'Montaj'),
  FieldSalesServicePresetDefinition(
    code: 'traseu_frigorific',
    label: 'Traseu frigorific',
    unit: 'ml',
  ),
  FieldSalesServicePresetDefinition(
    code: 'punere_in_functiune',
    label: 'PIF',
  ),
  FieldSalesServicePresetDefinition(
    code: 'servicii_baza',
    label: 'Alte servicii de baza',
  ),
];

class FieldLeadRecord {
  const FieldLeadRecord({
    required this.id,
    this.clientId = '',
    required this.clientName,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.address,
    required this.sourceModule,
    required this.sourceEntityId,
    required this.sourceLabel,
    required this.interestedInType,
    this.interestedProductIds = const <String>[],
    this.notes = '',
    this.status = FieldLeadStatus.nou,
    this.assignedUserId = '',
    this.createdByUserId = '',
    this.convertedAt,
    this.convertedByUserId = '',
    this.convertedEntityType = '',
    this.convertedEntityId = '',
    this.convertedEntityLabel = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String contactName;
  final String phone;
  final String email;
  final String address;
  final String sourceModule;
  final String sourceEntityId;
  final String sourceLabel;
  final FieldLeadInterestType interestedInType;
  final List<String> interestedProductIds;
  final String notes;
  final FieldLeadStatus status;
  final String assignedUserId;
  final String createdByUserId;
  final DateTime? convertedAt;
  final String convertedByUserId;
  final String convertedEntityType;
  final String convertedEntityId;
  final String convertedEntityLabel;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isConverted =>
      status == FieldLeadStatus.convertit ||
      convertedEntityId.trim().isNotEmpty;

  FieldLeadRecord copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? sourceModule,
    String? sourceEntityId,
    String? sourceLabel,
    FieldLeadInterestType? interestedInType,
    List<String>? interestedProductIds,
    String? notes,
    FieldLeadStatus? status,
    String? assignedUserId,
    String? createdByUserId,
    DateTime? convertedAt,
    bool clearConvertedAt = false,
    String? convertedByUserId,
    String? convertedEntityType,
    String? convertedEntityId,
    String? convertedEntityLabel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FieldLeadRecord(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      sourceModule: sourceModule ?? this.sourceModule,
      sourceEntityId: sourceEntityId ?? this.sourceEntityId,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      interestedInType: interestedInType ?? this.interestedInType,
      interestedProductIds: interestedProductIds ?? this.interestedProductIds,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      assignedUserId: assignedUserId ?? this.assignedUserId,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      convertedAt: clearConvertedAt ? null : (convertedAt ?? this.convertedAt),
      convertedByUserId: convertedByUserId ?? this.convertedByUserId,
      convertedEntityType: convertedEntityType ?? this.convertedEntityType,
      convertedEntityId: convertedEntityId ?? this.convertedEntityId,
      convertedEntityLabel: convertedEntityLabel ?? this.convertedEntityLabel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'client_id': clientId,
      'client_name': clientName,
      'contact_name': contactName,
      'phone': phone,
      'email': email,
      'address': address,
      'source_module': sourceModule,
      'source_entity_id': sourceEntityId,
      'source_label': sourceLabel,
      'interested_in_type': interestedInType.value,
      'interested_product_ids': interestedProductIds,
      'notes': notes,
      'status': status.value,
      'assigned_user_id': assignedUserId,
      'created_by_user_id': createdByUserId,
      'converted_at': convertedAt?.toIso8601String(),
      'converted_by_user_id': convertedByUserId,
      'converted_entity_type': convertedEntityType,
      'converted_entity_id': convertedEntityId,
      'converted_entity_label': convertedEntityLabel,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FieldLeadRecord.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) =>
        DateTime.tryParse((raw ?? '').toString()) ?? DateTime.now();
    List<String> parseList(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return FieldLeadRecord(
      id: (map['id'] ?? '').toString().trim(),
      clientId: (map['client_id'] ?? map['clientId'] ?? '').toString().trim(),
      clientName:
          (map['client_name'] ?? map['clientName'] ?? '').toString().trim(),
      contactName:
          (map['contact_name'] ?? map['contactName'] ?? '').toString().trim(),
      phone: (map['phone'] ?? '').toString().trim(),
      email: (map['email'] ?? '').toString().trim(),
      address: (map['address'] ?? '').toString().trim(),
      sourceModule:
          (map['source_module'] ?? map['sourceModule'] ?? '').toString().trim(),
      sourceEntityId: (map['source_entity_id'] ?? map['sourceEntityId'] ?? '')
          .toString()
          .trim(),
      sourceLabel:
          (map['source_label'] ?? map['sourceLabel'] ?? '').toString().trim(),
      interestedInType: FieldLeadInterestType.fromValue(
        (map['interested_in_type'] ?? map['interestedInType'] ?? '').toString(),
      ),
      interestedProductIds: parseList(
        map['interested_product_ids'] ?? map['interestedProductIds'],
      ),
      notes: (map['notes'] ?? '').toString(),
      status: FieldLeadStatus.fromValue(
        (map['status'] ?? '').toString(),
      ),
      assignedUserId: (map['assigned_user_id'] ?? map['assignedUserId'] ?? '')
          .toString()
          .trim(),
      createdByUserId:
          (map['created_by_user_id'] ?? map['createdByUserId'] ?? '')
              .toString()
              .trim(),
      convertedAt: DateTime.tryParse(
        (map['converted_at'] ?? map['convertedAt'] ?? '').toString(),
      ),
      convertedByUserId:
          (map['converted_by_user_id'] ?? map['convertedByUserId'] ?? '')
              .toString()
              .trim(),
      convertedEntityType:
          (map['converted_entity_type'] ?? map['convertedEntityType'] ?? '')
              .toString()
              .trim(),
      convertedEntityId:
          (map['converted_entity_id'] ?? map['convertedEntityId'] ?? '')
              .toString()
              .trim(),
      convertedEntityLabel:
          (map['converted_entity_label'] ?? map['convertedEntityLabel'] ?? '')
              .toString()
              .trim(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class FieldSalesRequestRecord {
  const FieldSalesRequestRecord({
    required this.id,
    this.leadId = '',
    this.clientId = '',
    required this.clientName,
    required this.requestType,
    this.requestedProductIds = const <String>[],
    this.requestedProducts = const <FieldSalesProductSelection>[],
    this.requestedServicePresets = const <FieldSalesServicePresetSelection>[],
    this.requestedServiceLabel = '',
    this.requestedPriceListId = '',
    this.requestedSubtotalValue = 0,
    this.requestedDiscountPercent = 0,
    this.requestedDiscountValue = 0,
    this.requestedTotalValue = 0,
    this.currency = 'RON',
    this.requestedByUserId = '',
    this.requestedByName = '',
    this.approvalStatus = FieldSalesRequestApprovalStatus.draft,
    this.approvedByUserId = '',
    this.approvedAt,
    this.notes = '',
    this.generatedDocumentPath = '',
    this.generatedDocumentFileName = '',
    this.generatedAt,
    this.generatedDocumentType = '',
    this.isConverted = false,
    this.convertedAt,
    this.convertedByUserId = '',
    this.convertedEntityType = '',
    this.convertedEntityId = '',
    this.convertedEntityLabel = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String leadId;
  final String clientId;
  final String clientName;
  final FieldSalesRequestType requestType;
  final List<String> requestedProductIds;
  final List<FieldSalesProductSelection> requestedProducts;
  final List<FieldSalesServicePresetSelection> requestedServicePresets;
  final String requestedServiceLabel;
  final String requestedPriceListId;
  final double requestedSubtotalValue;
  final double requestedDiscountPercent;
  final double requestedDiscountValue;
  final double requestedTotalValue;
  final String currency;
  final String requestedByUserId;
  final String requestedByName;
  final FieldSalesRequestApprovalStatus approvalStatus;
  final String approvedByUserId;
  final DateTime? approvedAt;
  final String notes;
  final String generatedDocumentPath;
  final String generatedDocumentFileName;
  final DateTime? generatedAt;
  final String generatedDocumentType;
  final bool isConverted;
  final DateTime? convertedAt;
  final String convertedByUserId;
  final String convertedEntityType;
  final String convertedEntityId;
  final String convertedEntityLabel;
  final DateTime createdAt;
  final DateTime updatedAt;

  FieldSalesRequestRecord copyWith({
    String? id,
    String? leadId,
    String? clientId,
    String? clientName,
    FieldSalesRequestType? requestType,
    List<String>? requestedProductIds,
    List<FieldSalesProductSelection>? requestedProducts,
    List<FieldSalesServicePresetSelection>? requestedServicePresets,
    String? requestedServiceLabel,
    String? requestedPriceListId,
    double? requestedSubtotalValue,
    double? requestedDiscountPercent,
    double? requestedDiscountValue,
    double? requestedTotalValue,
    String? currency,
    String? requestedByUserId,
    String? requestedByName,
    FieldSalesRequestApprovalStatus? approvalStatus,
    String? approvedByUserId,
    DateTime? approvedAt,
    bool clearApprovedAt = false,
    String? notes,
    String? generatedDocumentPath,
    String? generatedDocumentFileName,
    DateTime? generatedAt,
    bool clearGeneratedAt = false,
    String? generatedDocumentType,
    bool? isConverted,
    DateTime? convertedAt,
    bool clearConvertedAt = false,
    String? convertedByUserId,
    String? convertedEntityType,
    String? convertedEntityId,
    String? convertedEntityLabel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FieldSalesRequestRecord(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      requestType: requestType ?? this.requestType,
      requestedProductIds: requestedProductIds ?? this.requestedProductIds,
      requestedProducts: requestedProducts ?? this.requestedProducts,
      requestedServicePresets:
          requestedServicePresets ?? this.requestedServicePresets,
      requestedServiceLabel:
          requestedServiceLabel ?? this.requestedServiceLabel,
      requestedPriceListId: requestedPriceListId ?? this.requestedPriceListId,
      requestedSubtotalValue:
          requestedSubtotalValue ?? this.requestedSubtotalValue,
      requestedDiscountPercent:
          requestedDiscountPercent ?? this.requestedDiscountPercent,
      requestedDiscountValue:
          requestedDiscountValue ?? this.requestedDiscountValue,
      requestedTotalValue: requestedTotalValue ?? this.requestedTotalValue,
      currency: currency ?? this.currency,
      requestedByUserId: requestedByUserId ?? this.requestedByUserId,
      requestedByName: requestedByName ?? this.requestedByName,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      approvedAt: clearApprovedAt ? null : (approvedAt ?? this.approvedAt),
      notes: notes ?? this.notes,
      generatedDocumentPath:
          generatedDocumentPath ?? this.generatedDocumentPath,
      generatedDocumentFileName:
          generatedDocumentFileName ?? this.generatedDocumentFileName,
      generatedAt: clearGeneratedAt ? null : (generatedAt ?? this.generatedAt),
      generatedDocumentType:
          generatedDocumentType ?? this.generatedDocumentType,
      isConverted: isConverted ?? this.isConverted,
      convertedAt: clearConvertedAt ? null : (convertedAt ?? this.convertedAt),
      convertedByUserId: convertedByUserId ?? this.convertedByUserId,
      convertedEntityType: convertedEntityType ?? this.convertedEntityType,
      convertedEntityId: convertedEntityId ?? this.convertedEntityId,
      convertedEntityLabel: convertedEntityLabel ?? this.convertedEntityLabel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'lead_id': leadId,
      'client_id': clientId,
      'client_name': clientName,
      'request_type': requestType.value,
      'requested_product_ids': requestedProductIds,
      'requested_products':
          requestedProducts.map((item) => item.toMap()).toList(growable: false),
      'requested_service_presets': requestedServicePresets
          .map((item) => item.toMap())
          .toList(growable: false),
      'requested_service_label': requestedServiceLabel,
      'requested_price_list_id': requestedPriceListId,
      'requested_subtotal_value': requestedSubtotalValue,
      'requested_discount_percent': requestedDiscountPercent,
      'requested_discount_value': requestedDiscountValue,
      'requested_total_value': requestedTotalValue,
      'currency': currency,
      'requested_by_user_id': requestedByUserId,
      'requested_by_name': requestedByName,
      'approval_status': approvalStatus.value,
      'approved_by_user_id': approvedByUserId,
      'approved_at': approvedAt?.toIso8601String(),
      'notes': notes,
      'generated_document_path': generatedDocumentPath,
      'generated_document_file_name': generatedDocumentFileName,
      'generated_at': generatedAt?.toIso8601String(),
      'generated_document_type': generatedDocumentType,
      'is_converted': isConverted,
      'converted_at': convertedAt?.toIso8601String(),
      'converted_by_user_id': convertedByUserId,
      'converted_entity_type': convertedEntityType,
      'converted_entity_id': convertedEntityId,
      'converted_entity_label': convertedEntityLabel,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FieldSalesRequestRecord.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic raw) =>
        DateTime.tryParse((raw ?? '').toString()) ?? DateTime.now();
    DateTime? parseNullableDate(dynamic raw) =>
        DateTime.tryParse((raw ?? '').toString());
    List<String> parseList(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    List<FieldSalesProductSelection> parseProducts(dynamic raw) {
      if (raw is! List) return const <FieldSalesProductSelection>[];
      return raw
          .whereType<Map>()
          .map(
            (item) => FieldSalesProductSelection.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    }

    List<FieldSalesServicePresetSelection> parseServicePresets(dynamic raw) {
      if (raw is! List) {
        return const <FieldSalesServicePresetSelection>[];
      }
      return raw
          .whereType<Map>()
          .map(
            (item) => FieldSalesServicePresetSelection.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    }

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    return FieldSalesRequestRecord(
      id: (map['id'] ?? '').toString().trim(),
      leadId: (map['lead_id'] ?? map['leadId'] ?? '').toString().trim(),
      clientId: (map['client_id'] ?? map['clientId'] ?? '').toString().trim(),
      clientName:
          (map['client_name'] ?? map['clientName'] ?? '').toString().trim(),
      requestType: FieldSalesRequestType.fromValue(
        (map['request_type'] ?? map['requestType'] ?? '').toString(),
      ),
      requestedProductIds: parseList(
        map['requested_product_ids'] ?? map['requestedProductIds'],
      ),
      requestedProducts: parseProducts(
        map['requested_products'] ?? map['requestedProducts'],
      ),
      requestedServicePresets: parseServicePresets(
        map['requested_service_presets'] ?? map['requestedServicePresets'],
      ),
      requestedServiceLabel:
          (map['requested_service_label'] ?? map['requestedServiceLabel'] ?? '')
              .toString()
              .trim(),
      requestedPriceListId:
          (map['requested_price_list_id'] ?? map['requestedPriceListId'] ?? '')
              .toString()
              .trim(),
      requestedSubtotalValue: parseDouble(
        map['requested_subtotal_value'] ?? map['requestedSubtotalValue'],
      ),
      requestedDiscountPercent: parseDouble(
        map['requested_discount_percent'] ?? map['requestedDiscountPercent'],
      ),
      requestedDiscountValue: parseDouble(
        map['requested_discount_value'] ?? map['requestedDiscountValue'],
      ),
      requestedTotalValue: parseDouble(
        map['requested_total_value'] ?? map['requestedTotalValue'],
      ),
      currency: (map['currency'] ?? 'RON').toString().trim(),
      requestedByUserId:
          (map['requested_by_user_id'] ?? map['requestedByUserId'] ?? '')
              .toString()
              .trim(),
      requestedByName:
          (map['requested_by_name'] ?? map['requestedByName'] ?? '')
              .toString()
              .trim(),
      approvalStatus: FieldSalesRequestApprovalStatus.fromValue(
        (map['approval_status'] ?? map['approvalStatus'] ?? '').toString(),
      ),
      approvedByUserId:
          (map['approved_by_user_id'] ?? map['approvedByUserId'] ?? '')
              .toString()
              .trim(),
      approvedAt: parseNullableDate(map['approved_at'] ?? map['approvedAt']),
      notes: (map['notes'] ?? '').toString(),
      generatedDocumentPath:
          (map['generated_document_path'] ?? map['generatedDocumentPath'] ?? '')
              .toString()
              .trim(),
      generatedDocumentFileName: (map['generated_document_file_name'] ??
              map['generatedDocumentFileName'] ??
              '')
          .toString()
          .trim(),
      generatedAt: parseNullableDate(map['generated_at'] ?? map['generatedAt']),
      generatedDocumentType:
          (map['generated_document_type'] ?? map['generatedDocumentType'] ?? '')
              .toString()
              .trim(),
      isConverted: map['is_converted'] == true || map['isConverted'] == true,
      convertedAt: parseNullableDate(map['converted_at'] ?? map['convertedAt']),
      convertedByUserId:
          (map['converted_by_user_id'] ?? map['convertedByUserId'] ?? '')
              .toString()
              .trim(),
      convertedEntityType:
          (map['converted_entity_type'] ?? map['convertedEntityType'] ?? '')
              .toString()
              .trim(),
      convertedEntityId:
          (map['converted_entity_id'] ?? map['convertedEntityId'] ?? '')
              .toString()
              .trim(),
      convertedEntityLabel:
          (map['converted_entity_label'] ?? map['convertedEntityLabel'] ?? '')
              .toString()
              .trim(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}
