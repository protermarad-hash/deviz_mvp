enum ProductSaleStatus {
  draft,
  ofertat,
  inAsteptare,
  vandut,
  rezervat,
  anulat;

  String get value {
    switch (this) {
      case ProductSaleStatus.draft:
        return 'draft';
      case ProductSaleStatus.ofertat:
        return 'ofertat';
      case ProductSaleStatus.inAsteptare:
        return 'in_asteptare';
      case ProductSaleStatus.vandut:
        return 'vandut';
      case ProductSaleStatus.rezervat:
        return 'rezervat';
      case ProductSaleStatus.anulat:
        return 'anulat';
    }
  }

  String get label {
    switch (this) {
      case ProductSaleStatus.draft:
        return 'Draft';
      case ProductSaleStatus.ofertat:
        return 'Ofertat';
      case ProductSaleStatus.inAsteptare:
        return 'In asteptare';
      case ProductSaleStatus.vandut:
        return 'Vandut';
      case ProductSaleStatus.rezervat:
        return 'Rezervat';
      case ProductSaleStatus.anulat:
        return 'Anulat';
    }
  }

  static ProductSaleStatus fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return ProductSaleStatus.values.firstWhere(
      (item) => item.value == normalized,
      orElse: () => ProductSaleStatus.draft,
    );
  }
}

enum InstallerType {
  ownCompany,
  partner;

  String get value {
    switch (this) {
      case InstallerType.ownCompany:
        return 'own_company';
      case InstallerType.partner:
        return 'partner';
    }
  }

  String get label {
    switch (this) {
      case InstallerType.ownCompany:
        return 'Societatea mea';
      case InstallerType.partner:
        return 'Colaborator';
    }
  }

  static InstallerType fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return InstallerType.values.firstWhere(
      (item) => item.value == normalized,
      orElse: () => InstallerType.ownCompany,
    );
  }
}

enum WarrantyCertificateSourceType {
  sale,
  job,
  manual;

  String get value {
    switch (this) {
      case WarrantyCertificateSourceType.sale:
        return 'sale';
      case WarrantyCertificateSourceType.job:
        return 'job';
      case WarrantyCertificateSourceType.manual:
        return 'manual';
    }
  }

  String get label {
    switch (this) {
      case WarrantyCertificateSourceType.sale:
        return 'Vanzari';
      case WarrantyCertificateSourceType.job:
        return 'Lucrari';
      case WarrantyCertificateSourceType.manual:
        return 'Manual / istoric';
    }
  }

  static WarrantyCertificateSourceType fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return WarrantyCertificateSourceType.values.firstWhere(
      (item) => item.value == normalized,
      orElse: () => WarrantyCertificateSourceType.sale,
    );
  }
}

enum WarrantyCoverageStatus {
  unknown,
  inWarranty,
  postWarranty;

  String get value {
    switch (this) {
      case WarrantyCoverageStatus.unknown:
        return 'unknown';
      case WarrantyCoverageStatus.inWarranty:
        return 'in_warranty';
      case WarrantyCoverageStatus.postWarranty:
        return 'post_warranty';
    }
  }

  String get label {
    switch (this) {
      case WarrantyCoverageStatus.unknown:
        return 'Necunoscut';
      case WarrantyCoverageStatus.inWarranty:
        return 'In garantie';
      case WarrantyCoverageStatus.postWarranty:
        return 'Post-garantie';
    }
  }
}

class WarrantyServiceTicketRecord {
  const WarrantyServiceTicketRecord({
    required this.id,
    this.complaintId = '',
    this.repairReportId = '',
    this.receivedDate,
    this.completedDate,
    this.defect = '',
    this.description = '',
    this.repairReportNumber = '',
    this.serviceSignatureLabel = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String complaintId;
  final String repairReportId;
  final DateTime? receivedDate;
  final DateTime? completedDate;
  final String defect;
  final String description;
  final String repairReportNumber;
  final String serviceSignatureLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WarrantyServiceTicketRecord copyWith({
    String? id,
    String? complaintId,
    String? repairReportId,
    DateTime? receivedDate,
    DateTime? completedDate,
    String? defect,
    String? description,
    String? repairReportNumber,
    String? serviceSignatureLabel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WarrantyServiceTicketRecord(
      id: id ?? this.id,
      complaintId: complaintId ?? this.complaintId,
      repairReportId: repairReportId ?? this.repairReportId,
      receivedDate: receivedDate ?? this.receivedDate,
      completedDate: completedDate ?? this.completedDate,
      defect: defect ?? this.defect,
      description: description ?? this.description,
      repairReportNumber: repairReportNumber ?? this.repairReportNumber,
      serviceSignatureLabel:
          serviceSignatureLabel ?? this.serviceSignatureLabel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'complaint_id': complaintId,
      'repair_report_id': repairReportId,
      'received_date': receivedDate?.toIso8601String(),
      'completed_date': completedDate?.toIso8601String(),
      'defect': defect,
      'description': description,
      'repair_report_number': repairReportNumber,
      'service_signature_label': serviceSignatureLabel,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory WarrantyServiceTicketRecord.fromMap(Map<String, dynamic> map) {
    return WarrantyServiceTicketRecord(
      id: _stringFromMap(map, const <String>['id']),
      complaintId:
          _stringFromMap(map, const <String>['complaint_id', 'complaintId']),
      repairReportId: _stringFromMap(
          map, const <String>['repair_report_id', 'repairReportId']),
      receivedDate:
          _nullableDateFromMap(map['received_date'] ?? map['receivedDate']),
      completedDate:
          _nullableDateFromMap(map['completed_date'] ?? map['completedDate']),
      defect: _stringFromMap(map, const <String>['defect']),
      description: _stringFromMap(map, const <String>['description']),
      repairReportNumber: _stringFromMap(
        map,
        const <String>['repair_report_number', 'repairReportNumber'],
      ),
      serviceSignatureLabel: _stringFromMap(
        map,
        const <String>['service_signature_label', 'serviceSignatureLabel'],
      ),
      createdAt: _nullableDateFromMap(map['created_at'] ?? map['createdAt']),
      updatedAt: _nullableDateFromMap(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class ProductSaleRecord {
  const ProductSaleRecord({
    required this.id,
    required this.productId,
    required this.productName,
    this.clientId = '',
    this.clientName = '',
    this.saleStatus = ProductSaleStatus.draft,
    this.saleDate,
    this.invoiceNumber = '',
    this.serialNumberIndoor = '',
    this.serialNumberOutdoor = '',
    this.warrantyMonths = 24,
    this.installerType = InstallerType.ownCompany,
    this.installerPartnerId = '',
    this.installerDisplayName = '',
    this.notes = '',
    this.warrantyCertificateId = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String productId;
  final String productName;
  final String clientId;
  final String clientName;
  final ProductSaleStatus saleStatus;
  final DateTime? saleDate;
  final String invoiceNumber;
  final String serialNumberIndoor;
  final String serialNumberOutdoor;
  final int warrantyMonths;
  final InstallerType installerType;
  final String installerPartnerId;
  final String installerDisplayName;
  final String notes;
  final String warrantyCertificateId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductSaleRecord copyWith({
    String? id,
    String? productId,
    String? productName,
    String? clientId,
    String? clientName,
    ProductSaleStatus? saleStatus,
    DateTime? saleDate,
    String? invoiceNumber,
    String? serialNumberIndoor,
    String? serialNumberOutdoor,
    int? warrantyMonths,
    InstallerType? installerType,
    String? installerPartnerId,
    String? installerDisplayName,
    String? notes,
    String? warrantyCertificateId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductSaleRecord(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      saleStatus: saleStatus ?? this.saleStatus,
      saleDate: saleDate ?? this.saleDate,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      serialNumberIndoor: serialNumberIndoor ?? this.serialNumberIndoor,
      serialNumberOutdoor: serialNumberOutdoor ?? this.serialNumberOutdoor,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      installerType: installerType ?? this.installerType,
      installerPartnerId: installerPartnerId ?? this.installerPartnerId,
      installerDisplayName: installerDisplayName ?? this.installerDisplayName,
      notes: notes ?? this.notes,
      warrantyCertificateId:
          warrantyCertificateId ?? this.warrantyCertificateId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'client_id': clientId,
      'client_name': clientName,
      'sale_status': saleStatus.value,
      'sale_date': saleDate?.toIso8601String(),
      'invoice_number': invoiceNumber,
      'serial_number_indoor': serialNumberIndoor,
      'serial_number_outdoor': serialNumberOutdoor,
      'warranty_months': warrantyMonths,
      'installer_type': installerType.value,
      'installer_partner_id': installerPartnerId,
      'installer_display_name': installerDisplayName,
      'notes': notes,
      'warranty_certificate_id': warrantyCertificateId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ProductSaleRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return ProductSaleRecord(
      id: _stringFromMap(map, const <String>['id']),
      productId: _stringFromMap(map, const <String>['product_id', 'productId']),
      productName: _stringFromMap(
        map,
        const <String>['product_name', 'productName'],
      ),
      clientId: _stringFromMap(map, const <String>['client_id', 'clientId']),
      clientName:
          _stringFromMap(map, const <String>['client_name', 'clientName']),
      saleStatus: ProductSaleStatus.fromValue(
        _stringFromMap(map, const <String>['sale_status', 'saleStatus']),
      ),
      saleDate: _nullableDateFromMap(map['sale_date'] ?? map['saleDate']),
      invoiceNumber: _stringFromMap(
        map,
        const <String>['invoice_number', 'invoiceNumber'],
      ),
      serialNumberIndoor: _stringFromMap(
        map,
        const <String>['serial_number_indoor', 'serialNumberIndoor'],
      ),
      serialNumberOutdoor: _stringFromMap(
        map,
        const <String>['serial_number_outdoor', 'serialNumberOutdoor'],
      ),
      warrantyMonths:
          _intFromMap(map['warranty_months'] ?? map['warrantyMonths'], 24),
      installerType: InstallerType.fromValue(
        _stringFromMap(map, const <String>['installer_type', 'installerType']),
      ),
      installerPartnerId: _stringFromMap(
        map,
        const <String>['installer_partner_id', 'installerPartnerId'],
      ),
      installerDisplayName: _stringFromMap(
        map,
        const <String>['installer_display_name', 'installerDisplayName'],
      ),
      notes: _stringFromMap(map, const <String>['notes']),
      warrantyCertificateId: _stringFromMap(
        map,
        const <String>['warranty_certificate_id', 'warrantyCertificateId'],
      ),
      createdAt: _dateFromMap(map['created_at'] ?? map['createdAt'], now),
      updatedAt: _dateFromMap(map['updated_at'] ?? map['updatedAt'], now),
    );
  }
}

class WarrantyCertificateRecord {
  const WarrantyCertificateRecord({
    required this.id,
    required this.saleId,
    this.sourceType = WarrantyCertificateSourceType.sale,
    this.jobId = '',
    this.jobTitle = '',
    this.sourceEquipmentId = '',
    this.sourceEquipmentLabel = '',
    this.certificateSeries = '',
    this.certificateNumber = '',
    this.documentDate,
    this.equipmentType = '',
    this.brand = '',
    this.model = '',
    this.serialNumberIndoor = '',
    this.serialNumberOutdoor = '',
    this.invoiceNumber = '',
    this.saleDate,
    this.warrantyMonths = 24,
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.sellerName = '',
    this.sellerAddress = '',
    this.sellerEmail = '',
    this.sellerPhone = '',
    this.sellerTaxId = '',
    this.buyerClientId = '',
    this.buyerName = '',
    this.buyerAddress = '',
    this.buyerPhone = '',
    this.buyerTaxOrCnp = '',
    this.installerName = '',
    this.installerAddress = '',
    this.installerEmail = '',
    this.installerPhone = '',
    this.installerTaxId = '',
    this.installerPersons = '',
    this.installationDate,
    this.termsText = '',
    this.status = 'draft',
    this.registryEntryId = '',
    this.documentType = 'warranty_certificate',
    this.sourceModule = 'product_catalog_sales',
    this.generatedDocumentPath = '',
    this.generatedDocumentFileName = '',
    this.warrantyServiceHistoryIds = const <String>[],
    this.complaintIds = const <String>[],
    this.warrantyServiceTickets = const <WarrantyServiceTicketRecord>[],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String saleId;
  final WarrantyCertificateSourceType sourceType;
  final String jobId;
  final String jobTitle;
  final String sourceEquipmentId;
  final String sourceEquipmentLabel;
  final String certificateSeries;
  final String certificateNumber;
  final DateTime? documentDate;
  final String equipmentType;
  final String brand;
  final String model;
  final String serialNumberIndoor;
  final String serialNumberOutdoor;
  final String invoiceNumber;
  final DateTime? saleDate;
  final int warrantyMonths;
  final DateTime? warrantyStartDate;
  final DateTime? warrantyEndDate;
  final String sellerName;
  final String sellerAddress;
  final String sellerEmail;
  final String sellerPhone;
  final String sellerTaxId;
  final String buyerClientId;
  final String buyerName;
  final String buyerAddress;
  final String buyerPhone;
  final String buyerTaxOrCnp;
  final String installerName;
  final String installerAddress;
  final String installerEmail;
  final String installerPhone;
  final String installerTaxId;
  final String installerPersons;
  final DateTime? installationDate;
  final String termsText;
  final String status;
  final String registryEntryId;
  final String documentType;
  final String sourceModule;
  final String generatedDocumentPath;
  final String generatedDocumentFileName;
  final List<String> warrantyServiceHistoryIds;
  final List<String> complaintIds;
  final List<WarrantyServiceTicketRecord> warrantyServiceTickets;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get fullCertificateNumber {
    if (certificateSeries.trim().isEmpty) {
      return certificateNumber.trim();
    }
    if (certificateNumber.trim().isEmpty) {
      return certificateSeries.trim();
    }
    return '${certificateSeries.trim()} ${certificateNumber.trim()}';
  }

  WarrantyCertificateRecord copyWith({
    String? id,
    String? saleId,
    WarrantyCertificateSourceType? sourceType,
    String? jobId,
    String? jobTitle,
    String? sourceEquipmentId,
    String? sourceEquipmentLabel,
    String? certificateSeries,
    String? certificateNumber,
    DateTime? documentDate,
    String? equipmentType,
    String? brand,
    String? model,
    String? serialNumberIndoor,
    String? serialNumberOutdoor,
    String? invoiceNumber,
    DateTime? saleDate,
    int? warrantyMonths,
    DateTime? warrantyStartDate,
    DateTime? warrantyEndDate,
    String? sellerName,
    String? sellerAddress,
    String? sellerEmail,
    String? sellerPhone,
    String? sellerTaxId,
    String? buyerClientId,
    String? buyerName,
    String? buyerAddress,
    String? buyerPhone,
    String? buyerTaxOrCnp,
    String? installerName,
    String? installerAddress,
    String? installerEmail,
    String? installerPhone,
    String? installerTaxId,
    String? installerPersons,
    DateTime? installationDate,
    String? termsText,
    String? status,
    String? registryEntryId,
    String? documentType,
    String? sourceModule,
    String? generatedDocumentPath,
    String? generatedDocumentFileName,
    List<String>? warrantyServiceHistoryIds,
    List<String>? complaintIds,
    List<WarrantyServiceTicketRecord>? warrantyServiceTickets,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WarrantyCertificateRecord(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      sourceType: sourceType ?? this.sourceType,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      sourceEquipmentId: sourceEquipmentId ?? this.sourceEquipmentId,
      sourceEquipmentLabel: sourceEquipmentLabel ?? this.sourceEquipmentLabel,
      certificateSeries: certificateSeries ?? this.certificateSeries,
      certificateNumber: certificateNumber ?? this.certificateNumber,
      documentDate: documentDate ?? this.documentDate,
      equipmentType: equipmentType ?? this.equipmentType,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumberIndoor: serialNumberIndoor ?? this.serialNumberIndoor,
      serialNumberOutdoor: serialNumberOutdoor ?? this.serialNumberOutdoor,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      saleDate: saleDate ?? this.saleDate,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      warrantyStartDate: warrantyStartDate ?? this.warrantyStartDate,
      warrantyEndDate: warrantyEndDate ?? this.warrantyEndDate,
      sellerName: sellerName ?? this.sellerName,
      sellerAddress: sellerAddress ?? this.sellerAddress,
      sellerEmail: sellerEmail ?? this.sellerEmail,
      sellerPhone: sellerPhone ?? this.sellerPhone,
      sellerTaxId: sellerTaxId ?? this.sellerTaxId,
      buyerClientId: buyerClientId ?? this.buyerClientId,
      buyerName: buyerName ?? this.buyerName,
      buyerAddress: buyerAddress ?? this.buyerAddress,
      buyerPhone: buyerPhone ?? this.buyerPhone,
      buyerTaxOrCnp: buyerTaxOrCnp ?? this.buyerTaxOrCnp,
      installerName: installerName ?? this.installerName,
      installerAddress: installerAddress ?? this.installerAddress,
      installerEmail: installerEmail ?? this.installerEmail,
      installerPhone: installerPhone ?? this.installerPhone,
      installerTaxId: installerTaxId ?? this.installerTaxId,
      installerPersons: installerPersons ?? this.installerPersons,
      installationDate: installationDate ?? this.installationDate,
      termsText: termsText ?? this.termsText,
      status: status ?? this.status,
      registryEntryId: registryEntryId ?? this.registryEntryId,
      documentType: documentType ?? this.documentType,
      sourceModule: sourceModule ?? this.sourceModule,
      generatedDocumentPath:
          generatedDocumentPath ?? this.generatedDocumentPath,
      generatedDocumentFileName:
          generatedDocumentFileName ?? this.generatedDocumentFileName,
      warrantyServiceHistoryIds:
          warrantyServiceHistoryIds ?? this.warrantyServiceHistoryIds,
      complaintIds: complaintIds ?? this.complaintIds,
      warrantyServiceTickets:
          warrantyServiceTickets ?? this.warrantyServiceTickets,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'sale_id': saleId,
      'source_type': sourceType.value,
      'job_id': jobId,
      'job_title': jobTitle,
      'source_equipment_id': sourceEquipmentId,
      'source_equipment_label': sourceEquipmentLabel,
      'certificate_series': certificateSeries,
      'certificate_number': certificateNumber,
      'document_date': documentDate?.toIso8601String(),
      'equipment_type': equipmentType,
      'brand': brand,
      'model': model,
      'serial_number_indoor': serialNumberIndoor,
      'serial_number_outdoor': serialNumberOutdoor,
      'invoice_number': invoiceNumber,
      'sale_date': saleDate?.toIso8601String(),
      'warranty_months': warrantyMonths,
      'warranty_start_date': warrantyStartDate?.toIso8601String(),
      'warranty_end_date': warrantyEndDate?.toIso8601String(),
      'seller_name': sellerName,
      'seller_address': sellerAddress,
      'seller_email': sellerEmail,
      'seller_phone': sellerPhone,
      'seller_tax_id': sellerTaxId,
      'buyer_client_id': buyerClientId,
      'buyer_name': buyerName,
      'buyer_address': buyerAddress,
      'buyer_phone': buyerPhone,
      'buyer_tax_or_cnp': buyerTaxOrCnp,
      'installer_name': installerName,
      'installer_address': installerAddress,
      'installer_email': installerEmail,
      'installer_phone': installerPhone,
      'installer_tax_id': installerTaxId,
      'installer_persons': installerPersons,
      'installation_date': installationDate?.toIso8601String(),
      'terms_text': termsText,
      'status': normalizeWarrantyCertificateStatus(status),
      'registry_entry_id': registryEntryId,
      'document_type': documentType,
      'source_module': sourceModule,
      'generated_document_path': generatedDocumentPath,
      'generated_document_file_name': generatedDocumentFileName,
      'warranty_service_history_ids': warrantyServiceHistoryIds,
      'complaint_ids': complaintIds,
      'warranty_service_tickets':
          warrantyServiceTickets.map((item) => item.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory WarrantyCertificateRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return WarrantyCertificateRecord(
      id: _stringFromMap(map, const <String>['id']),
      saleId: _stringFromMap(map, const <String>['sale_id', 'saleId']),
      sourceType: WarrantyCertificateSourceType.fromValue(
        _stringFromMap(map, const <String>['source_type', 'sourceType']),
      ),
      jobId: _stringFromMap(map, const <String>['job_id', 'jobId']),
      jobTitle: _stringFromMap(map, const <String>['job_title', 'jobTitle']),
      sourceEquipmentId: _stringFromMap(
        map,
        const <String>['source_equipment_id', 'sourceEquipmentId'],
      ),
      sourceEquipmentLabel: _stringFromMap(
        map,
        const <String>['source_equipment_label', 'sourceEquipmentLabel'],
      ),
      certificateSeries: _stringFromMap(
        map,
        const <String>['certificate_series', 'certificateSeries'],
      ),
      certificateNumber: _stringFromMap(
        map,
        const <String>['certificate_number', 'certificateNumber'],
      ),
      documentDate: _nullableDateFromMap(
        map['document_date'] ?? map['documentDate'],
      ),
      equipmentType: _stringFromMap(
        map,
        const <String>['equipment_type', 'equipmentType'],
      ),
      brand: _stringFromMap(map, const <String>['brand']),
      model: _stringFromMap(map, const <String>['model']),
      serialNumberIndoor: _stringFromMap(
        map,
        const <String>['serial_number_indoor', 'serialNumberIndoor'],
      ),
      serialNumberOutdoor: _stringFromMap(
        map,
        const <String>['serial_number_outdoor', 'serialNumberOutdoor'],
      ),
      invoiceNumber: _stringFromMap(
        map,
        const <String>['invoice_number', 'invoiceNumber'],
      ),
      saleDate: _nullableDateFromMap(map['sale_date'] ?? map['saleDate']),
      warrantyMonths:
          _intFromMap(map['warranty_months'] ?? map['warrantyMonths'], 24),
      warrantyStartDate: _nullableDateFromMap(
        map['warranty_start_date'] ?? map['warrantyStartDate'],
      ),
      warrantyEndDate: _nullableDateFromMap(
        map['warranty_end_date'] ?? map['warrantyEndDate'],
      ),
      sellerName:
          _stringFromMap(map, const <String>['seller_name', 'sellerName']),
      sellerAddress: _stringFromMap(
        map,
        const <String>['seller_address', 'sellerAddress'],
      ),
      sellerEmail:
          _stringFromMap(map, const <String>['seller_email', 'sellerEmail']),
      sellerPhone:
          _stringFromMap(map, const <String>['seller_phone', 'sellerPhone']),
      sellerTaxId: _stringFromMap(
        map,
        const <String>['seller_tax_id', 'sellerTaxId'],
      ),
      buyerClientId: _stringFromMap(
        map,
        const <String>['buyer_client_id', 'buyerClientId'],
      ),
      buyerName: _stringFromMap(map, const <String>['buyer_name', 'buyerName']),
      buyerAddress: _stringFromMap(
        map,
        const <String>['buyer_address', 'buyerAddress'],
      ),
      buyerPhone:
          _stringFromMap(map, const <String>['buyer_phone', 'buyerPhone']),
      buyerTaxOrCnp: _stringFromMap(
        map,
        const <String>['buyer_tax_or_cnp', 'buyerTaxOrCnp'],
      ),
      installerName: _stringFromMap(
        map,
        const <String>['installer_name', 'installerName'],
      ),
      installerAddress: _stringFromMap(
        map,
        const <String>['installer_address', 'installerAddress'],
      ),
      installerEmail: _stringFromMap(
        map,
        const <String>['installer_email', 'installerEmail'],
      ),
      installerPhone: _stringFromMap(
        map,
        const <String>['installer_phone', 'installerPhone'],
      ),
      installerTaxId: _stringFromMap(
        map,
        const <String>['installer_tax_id', 'installerTaxId'],
      ),
      installerPersons: _stringFromMap(
        map,
        const <String>['installer_persons', 'installerPersons'],
      ),
      installationDate: _nullableDateFromMap(
        map['installation_date'] ?? map['installationDate'],
      ),
      termsText: _stringFromMap(map, const <String>['terms_text', 'termsText']),
      status: normalizeWarrantyCertificateStatus(
        _stringFromMap(map, const <String>['status'], fallback: 'draft'),
      ),
      registryEntryId: _stringFromMap(
        map,
        const <String>['registry_entry_id', 'registryEntryId'],
      ),
      documentType: _stringFromMap(
        map,
        const <String>['document_type', 'documentType'],
        fallback: 'warranty_certificate',
      ),
      sourceModule: _stringFromMap(
        map,
        const <String>['source_module', 'sourceModule'],
        fallback: 'product_catalog_sales',
      ),
      generatedDocumentPath: _stringFromMap(
        map,
        const <String>['generated_document_path', 'generatedDocumentPath'],
      ),
      generatedDocumentFileName: _stringFromMap(
        map,
        const <String>[
          'generated_document_file_name',
          'generatedDocumentFileName',
        ],
      ),
      warrantyServiceHistoryIds: _stringListFromMap(
        map['warranty_service_history_ids'] ?? map['warrantyServiceHistoryIds'],
      ),
      complaintIds: _stringListFromMap(
        map['complaint_ids'] ?? map['complaintIds'],
      ),
      warrantyServiceTickets: _ticketListFromMap(
        map['warranty_service_tickets'] ?? map['warrantyServiceTickets'],
      ),
      createdAt: _dateFromMap(map['created_at'] ?? map['createdAt'], now),
      updatedAt: _dateFromMap(map['updated_at'] ?? map['updatedAt'], now),
    );
  }
}

const List<String> warrantyCertificateStatusOptions = <String>[
  'draft',
  'emis',
  'transmis',
  'arhivat',
];

String normalizeWarrantyCertificateStatus(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  for (final item in warrantyCertificateStatusOptions) {
    if (item == value) {
      return item;
    }
  }
  return warrantyCertificateStatusOptions.first;
}

String warrantyCertificateStatusLabel(String? raw) {
  switch (normalizeWarrantyCertificateStatus(raw)) {
    case 'emis':
      return 'Emis';
    case 'transmis':
      return 'Transmis';
    case 'arhivat':
      return 'Arhivat';
    case 'draft':
    default:
      return 'Draft';
  }
}

int _intFromMap(dynamic raw, int fallback) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse((raw ?? '').toString().trim()) ?? fallback;
}

String _stringFromMap(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return fallback;
}

DateTime _dateFromMap(dynamic raw, DateTime fallback) {
  if (raw is DateTime) return raw;
  return DateTime.tryParse((raw ?? '').toString()) ?? fallback;
}

DateTime? _nullableDateFromMap(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

List<String> _stringListFromMap(dynamic raw) {
  if (raw is List) {
    return raw
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

List<WarrantyServiceTicketRecord> _ticketListFromMap(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map(
          (item) => WarrantyServiceTicketRecord.fromMap(
              Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }
  return const <WarrantyServiceTicketRecord>[];
}
