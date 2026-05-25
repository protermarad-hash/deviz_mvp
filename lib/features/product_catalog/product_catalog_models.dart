enum ProductItemType {
  product,
  service;

  String get value => this == ProductItemType.product ? 'product' : 'service';
  String get label => this == ProductItemType.product ? 'Produs' : 'Serviciu';

  static ProductItemType fromValue(String? raw) {
    if ((raw ?? '').trim().toLowerCase() == 'service') {
      return ProductItemType.service;
    }
    return ProductItemType.product;
  }
}

enum PriceListScope {
  standard,
  collaborator,
  dedicatedClient;

  String get value {
    switch (this) {
      case PriceListScope.standard:
        return 'standard';
      case PriceListScope.collaborator:
        return 'collaborator';
      case PriceListScope.dedicatedClient:
        return 'dedicated_client';
    }
  }

  String get label {
    switch (this) {
      case PriceListScope.standard:
        return 'Lista standard';
      case PriceListScope.collaborator:
        return 'Lista colaborator';
      case PriceListScope.dedicatedClient:
        return 'Lista client dedicat';
    }
  }

  static PriceListScope fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return PriceListScope.values.firstWhere(
      (item) => item.value == normalized,
      orElse: () => PriceListScope.standard,
    );
  }
}

enum SalePricingMode {
  markupPercent,
  markupValue,
  targetProfitValue,
  targetProfitPercent;

  String get value {
    switch (this) {
      case SalePricingMode.markupPercent:
        return 'markup_percent';
      case SalePricingMode.markupValue:
        return 'markup_value';
      case SalePricingMode.targetProfitValue:
        return 'target_profit_value';
      case SalePricingMode.targetProfitPercent:
        return 'target_profit_percent';
    }
  }

  String get label {
    switch (this) {
      case SalePricingMode.markupPercent:
        return 'Adaos procentual';
      case SalePricingMode.markupValue:
        return 'Adaos valoric';
      case SalePricingMode.targetProfitValue:
        return 'Profit dorit valoric';
      case SalePricingMode.targetProfitPercent:
        return 'Profit dorit procentual';
    }
  }

  static SalePricingMode fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return SalePricingMode.values.firstWhere(
      (item) => item.value == normalized,
      orElse: () => SalePricingMode.markupPercent,
    );
  }
}

enum PercentageBasis {
  onCost,
  onSalePrice;

  String get value {
    switch (this) {
      case PercentageBasis.onCost:
        return 'on_cost';
      case PercentageBasis.onSalePrice:
        return 'on_sale_price';
    }
  }

  String get label {
    switch (this) {
      case PercentageBasis.onCost:
        return 'Raportat la cost';
      case PercentageBasis.onSalePrice:
        return 'Raportat la pretul de vanzare';
    }
  }

  static PercentageBasis fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return PercentageBasis.values.firstWhere(
      (item) => item.value == normalized,
      orElse: () => PercentageBasis.onCost,
    );
  }
}

enum ProductStockStatus {
  inStock,
  onOrder,
  outOfStock;

  String get value {
    switch (this) {
      case ProductStockStatus.inStock:
        return 'in_stock';
      case ProductStockStatus.onOrder:
        return 'on_order';
      case ProductStockStatus.outOfStock:
        return 'out_of_stock';
    }
  }

  String get label {
    switch (this) {
      case ProductStockStatus.inStock:
        return 'In stoc';
      case ProductStockStatus.onOrder:
        return 'La comanda';
      case ProductStockStatus.outOfStock:
        return 'Indisponibil';
    }
  }

  static ProductStockStatus fromValue(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return ProductStockStatus.values.firstWhere(
      (item) => item.value == normalized,
      orElse: () => ProductStockStatus.inStock,
    );
  }
}

class ProductCatalogRecord {
  const ProductCatalogRecord({
    required this.id,
    required this.name,
    this.itemType = ProductItemType.product,
    this.category = '',
    this.brand = '',
    this.model = '',
    this.capacity = '',
    this.linkedCapacity = '',
    this.listPrice = 0,
    this.sku = '',
    this.unit = 'buc',
    this.description = '',
    this.commercialDescription = '',
    this.stockQuantity = 0,
    this.stockStatus = ProductStockStatus.inStock,
    this.deliveryLeadTimeText = '',
    this.stockUpdatedAt,
    this.isActive = true,
    this.imagePaths = const <String>[],
    this.pdfPaths = const <String>[],
    this.registryEntryIds = const <String>[],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  /// Tipul înregistrării: produs fizic sau serviciu.
  final ProductItemType itemType;
  final String category;
  final String brand;
  final String model;
  final String capacity;
  /// Doar pentru servicii: capacitatea produsului la care se leagă (ex: "9000 BTU").
  final String linkedCapacity;
  /// Preț de vânzare direct, vizibil în listele de prețuri.
  final double listPrice;
  final String sku;
  final String unit;
  final String description;
  final String commercialDescription;
  final double stockQuantity;
  final ProductStockStatus stockStatus;
  final String deliveryLeadTimeText;
  final DateTime? stockUpdatedAt;
  final bool isActive;
  final List<String> imagePaths;
  final List<String> pdfPaths;
  final List<String> registryEntryIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductCatalogRecord copyWith({
    String? id,
    String? name,
    ProductItemType? itemType,
    String? category,
    String? brand,
    String? model,
    String? capacity,
    String? linkedCapacity,
    double? listPrice,
    String? sku,
    String? unit,
    String? description,
    String? commercialDescription,
    double? stockQuantity,
    ProductStockStatus? stockStatus,
    String? deliveryLeadTimeText,
    DateTime? stockUpdatedAt,
    bool? isActive,
    List<String>? imagePaths,
    List<String>? pdfPaths,
    List<String>? registryEntryIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductCatalogRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      itemType: itemType ?? this.itemType,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      capacity: capacity ?? this.capacity,
      linkedCapacity: linkedCapacity ?? this.linkedCapacity,
      listPrice: listPrice ?? this.listPrice,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      commercialDescription:
          commercialDescription ?? this.commercialDescription,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      stockStatus: stockStatus ?? this.stockStatus,
      deliveryLeadTimeText: deliveryLeadTimeText ?? this.deliveryLeadTimeText,
      stockUpdatedAt: stockUpdatedAt ?? this.stockUpdatedAt,
      isActive: isActive ?? this.isActive,
      imagePaths: imagePaths ?? this.imagePaths,
      pdfPaths: pdfPaths ?? this.pdfPaths,
      registryEntryIds: registryEntryIds ?? this.registryEntryIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'item_type': itemType.value,
      'category': category,
      'brand': brand,
      'model': model,
      'capacity': capacity,
      'linked_capacity': linkedCapacity,
      'list_price': listPrice,
      'sku': sku,
      'unit': unit,
      'description': description,
      'commercial_description': commercialDescription,
      'stock_quantity': stockQuantity,
      'stock_status': stockStatus.value,
      'delivery_lead_time_text': deliveryLeadTimeText,
      'stock_updated_at': stockUpdatedAt?.toIso8601String(),
      'is_active': isActive,
      'image_paths': imagePaths,
      'pdf_paths': pdfPaths,
      'registry_entry_ids': registryEntryIds,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ProductCatalogRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return ProductCatalogRecord(
      id: _stringFromMap(map, const <String>['id']),
      name: _stringFromMap(map, const <String>['name']),
      itemType: ProductItemType.fromValue(
        _stringFromMap(map, const <String>['item_type', 'itemType']),
      ),
      category: _stringFromMap(map, const <String>['category']),
      brand: _stringFromMap(map, const <String>['brand']),
      model: _stringFromMap(map, const <String>['model']),
      capacity: _stringFromMap(map, const <String>['capacity']),
      linkedCapacity: _stringFromMap(
        map,
        const <String>['linked_capacity', 'linkedCapacity'],
      ),
      listPrice: _doubleFromMap(
        map['list_price'] ?? map['listPrice'],
      ),
      sku: _stringFromMap(map, const <String>['sku', 'product_code']),
      unit: _stringFromMap(map, const <String>['unit'], fallback: 'buc'),
      description: _stringFromMap(map, const <String>['description']),
      commercialDescription: _stringFromMap(
        map,
        const <String>['commercial_description', 'commercialDescription'],
      ),
      stockQuantity: _doubleFromMap(
        map['stock_quantity'] ?? map['stockQuantity'],
      ),
      stockStatus: ProductStockStatus.fromValue(
        _stringFromMap(map, const <String>['stock_status', 'stockStatus']),
      ),
      deliveryLeadTimeText: _stringFromMap(
        map,
        const <String>['delivery_lead_time_text', 'deliveryLeadTimeText'],
      ),
      stockUpdatedAt: _nullableDateFromMap(
        map['stock_updated_at'] ?? map['stockUpdatedAt'],
      ),
      isActive:
          _boolFromMap(map['is_active'] ?? map['isActive'], fallback: true),
      imagePaths: _stringListFromMap(map['image_paths'] ?? map['imagePaths']),
      pdfPaths: _stringListFromMap(map['pdf_paths'] ?? map['pdfPaths']),
      registryEntryIds: _stringListFromMap(
        map['registry_entry_ids'] ?? map['registryEntryIds'],
      ),
      createdAt: _dateFromMap(map['created_at'] ?? map['createdAt'], now),
      updatedAt: _dateFromMap(map['updated_at'] ?? map['updatedAt'], now),
    );
  }
}

class SupplierPriceRecord {
  const SupplierPriceRecord({
    required this.id,
    required this.productId,
    this.supplierId = '',
    this.supplierName = '',
    this.currency = 'RON',
    this.basePrice = 0,
    this.priceIncludesVat = false,
    this.vatPercent = 19,
    this.supplierDiscountPercent = 0,
    this.supplierDiscountValue = 0,
    this.greenStampValue = 0,
    this.greenStampIncluded = false,
    this.transportValue = 0,
    this.transportIncluded = false,
    this.otherCostValue = 0,
    this.notes = '',
    this.registryEntryIds = const <String>[],
    this.validFrom,
    this.validTo,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String productId;
  final String supplierId;
  final String supplierName;
  final String currency;
  final double basePrice;
  final bool priceIncludesVat;
  final double vatPercent;
  final double supplierDiscountPercent;
  final double supplierDiscountValue;
  final double greenStampValue;
  final bool greenStampIncluded;
  final double transportValue;
  final bool transportIncluded;
  final double otherCostValue;
  final String notes;
  final List<String> registryEntryIds;
  final DateTime? validFrom;
  final DateTime? validTo;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupplierPriceRecord copyWith({
    String? id,
    String? productId,
    String? supplierId,
    String? supplierName,
    String? currency,
    double? basePrice,
    bool? priceIncludesVat,
    double? vatPercent,
    double? supplierDiscountPercent,
    double? supplierDiscountValue,
    double? greenStampValue,
    bool? greenStampIncluded,
    double? transportValue,
    bool? transportIncluded,
    double? otherCostValue,
    String? notes,
    List<String>? registryEntryIds,
    DateTime? validFrom,
    DateTime? validTo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierPriceRecord(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      currency: currency ?? this.currency,
      basePrice: basePrice ?? this.basePrice,
      priceIncludesVat: priceIncludesVat ?? this.priceIncludesVat,
      vatPercent: vatPercent ?? this.vatPercent,
      supplierDiscountPercent:
          supplierDiscountPercent ?? this.supplierDiscountPercent,
      supplierDiscountValue:
          supplierDiscountValue ?? this.supplierDiscountValue,
      greenStampValue: greenStampValue ?? this.greenStampValue,
      greenStampIncluded: greenStampIncluded ?? this.greenStampIncluded,
      transportValue: transportValue ?? this.transportValue,
      transportIncluded: transportIncluded ?? this.transportIncluded,
      otherCostValue: otherCostValue ?? this.otherCostValue,
      notes: notes ?? this.notes,
      registryEntryIds: registryEntryIds ?? this.registryEntryIds,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'product_id': productId,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'currency': currency,
      'base_price': basePrice,
      'price_includes_vat': priceIncludesVat,
      'vat_percent': vatPercent,
      'supplier_discount_percent': supplierDiscountPercent,
      'supplier_discount_value': supplierDiscountValue,
      'green_stamp_value': greenStampValue,
      'green_stamp_included': greenStampIncluded,
      'transport_value': transportValue,
      'transport_included': transportIncluded,
      'other_cost_value': otherCostValue,
      'notes': notes,
      'registry_entry_ids': registryEntryIds,
      'valid_from': validFrom?.toIso8601String(),
      'valid_to': validTo?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SupplierPriceRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return SupplierPriceRecord(
      id: _stringFromMap(map, const <String>['id']),
      productId: _stringFromMap(map, const <String>['product_id', 'productId']),
      supplierId:
          _stringFromMap(map, const <String>['supplier_id', 'supplierId']),
      supplierName: _stringFromMap(
        map,
        const <String>['supplier_name', 'supplierName'],
      ),
      currency:
          _stringFromMap(map, const <String>['currency'], fallback: 'RON'),
      basePrice: _doubleFromMap(map['base_price'] ?? map['basePrice']),
      priceIncludesVat: _boolFromMap(
        map['price_includes_vat'] ?? map['priceIncludesVat'],
      ),
      vatPercent: _doubleFromMap(map['vat_percent'] ?? map['vatPercent'], 19),
      supplierDiscountPercent: _doubleFromMap(
        map['supplier_discount_percent'] ?? map['supplierDiscountPercent'],
      ),
      supplierDiscountValue: _doubleFromMap(
        map['supplier_discount_value'] ?? map['supplierDiscountValue'],
      ),
      greenStampValue: _doubleFromMap(
        map['green_stamp_value'] ?? map['greenStampValue'],
      ),
      greenStampIncluded: _boolFromMap(
        map['green_stamp_included'] ?? map['greenStampIncluded'],
      ),
      transportValue: _doubleFromMap(
        map['transport_value'] ?? map['transportValue'],
      ),
      transportIncluded: _boolFromMap(
        map['transport_included'] ?? map['transportIncluded'],
      ),
      otherCostValue: _doubleFromMap(
        map['other_cost_value'] ?? map['otherCostValue'],
      ),
      notes: _stringFromMap(map, const <String>['notes']),
      registryEntryIds: _stringListFromMap(
        map['registry_entry_ids'] ?? map['registryEntryIds'],
      ),
      validFrom: _nullableDateFromMap(map['valid_from'] ?? map['validFrom']),
      validTo: _nullableDateFromMap(map['valid_to'] ?? map['validTo']),
      createdAt: _dateFromMap(map['created_at'] ?? map['createdAt'], now),
      updatedAt: _dateFromMap(map['updated_at'] ?? map['updatedAt'], now),
    );
  }
}

class PriceListRecord {
  const PriceListRecord({
    required this.id,
    required this.name,
    this.code = '',
    this.scope = PriceListScope.standard,
    this.currency = 'RON',
    this.clientId = '',
    this.clientName = '',
    this.collaboratorId = '',
    this.collaboratorName = '',
    this.notes = '',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String code;
  final PriceListScope scope;
  final String currency;
  final String clientId;
  final String clientName;
  final String collaboratorId;
  final String collaboratorName;
  final String notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  PriceListRecord copyWith({
    String? id,
    String? name,
    String? code,
    PriceListScope? scope,
    String? currency,
    String? clientId,
    String? clientName,
    String? collaboratorId,
    String? collaboratorName,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PriceListRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      scope: scope ?? this.scope,
      currency: currency ?? this.currency,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      collaboratorId: collaboratorId ?? this.collaboratorId,
      collaboratorName: collaboratorName ?? this.collaboratorName,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'code': code,
      'scope': scope.value,
      'currency': currency,
      'client_id': clientId,
      'client_name': clientName,
      'collaborator_id': collaboratorId,
      'collaborator_name': collaboratorName,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PriceListRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return PriceListRecord(
      id: _stringFromMap(map, const <String>['id']),
      name: _stringFromMap(map, const <String>['name']),
      code: _stringFromMap(map, const <String>['code']),
      scope: PriceListScope.fromValue(
        _stringFromMap(map, const <String>['scope']),
      ),
      currency:
          _stringFromMap(map, const <String>['currency'], fallback: 'RON'),
      clientId: _stringFromMap(map, const <String>['client_id', 'clientId']),
      clientName:
          _stringFromMap(map, const <String>['client_name', 'clientName']),
      collaboratorId: _stringFromMap(
        map,
        const <String>['collaborator_id', 'collaboratorId'],
      ),
      collaboratorName: _stringFromMap(
        map,
        const <String>['collaborator_name', 'collaboratorName'],
      ),
      notes: _stringFromMap(map, const <String>['notes']),
      isActive:
          _boolFromMap(map['is_active'] ?? map['isActive'], fallback: true),
      createdAt: _dateFromMap(map['created_at'] ?? map['createdAt'], now),
      updatedAt: _dateFromMap(map['updated_at'] ?? map['updatedAt'], now),
    );
  }
}

class PriceListEntryRecord {
  const PriceListEntryRecord({
    required this.id,
    required this.priceListId,
    required this.productId,
    this.currency = 'RON',
    this.pricingMode = SalePricingMode.markupPercent,
    this.percentageBasis = PercentageBasis.onCost,
    this.pricingValue = 0,
    this.manualSalePrice = 0,
    this.vatPercent = 19,
    this.priceIncludesVat = false,
    this.referenceSupplierPriceId = '',
    this.referenceSupplierCost = 0,
    this.calculatedSaleNetPrice = 0,
    this.calculatedSaleGrossPrice = 0,
    this.calculatedProfitValue = 0,
    this.calculatedProfitPercentOnCost = 0,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String priceListId;
  final String productId;
  final String currency;
  final SalePricingMode pricingMode;
  final PercentageBasis percentageBasis;
  final double pricingValue;
  final double manualSalePrice;
  final double vatPercent;
  final bool priceIncludesVat;
  final String referenceSupplierPriceId;
  final double referenceSupplierCost;
  final double calculatedSaleNetPrice;
  final double calculatedSaleGrossPrice;
  final double calculatedProfitValue;
  final double calculatedProfitPercentOnCost;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PriceListEntryRecord copyWith({
    String? id,
    String? priceListId,
    String? productId,
    String? currency,
    SalePricingMode? pricingMode,
    PercentageBasis? percentageBasis,
    double? pricingValue,
    double? manualSalePrice,
    double? vatPercent,
    bool? priceIncludesVat,
    String? referenceSupplierPriceId,
    double? referenceSupplierCost,
    double? calculatedSaleNetPrice,
    double? calculatedSaleGrossPrice,
    double? calculatedProfitValue,
    double? calculatedProfitPercentOnCost,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PriceListEntryRecord(
      id: id ?? this.id,
      priceListId: priceListId ?? this.priceListId,
      productId: productId ?? this.productId,
      currency: currency ?? this.currency,
      pricingMode: pricingMode ?? this.pricingMode,
      percentageBasis: percentageBasis ?? this.percentageBasis,
      pricingValue: pricingValue ?? this.pricingValue,
      manualSalePrice: manualSalePrice ?? this.manualSalePrice,
      vatPercent: vatPercent ?? this.vatPercent,
      priceIncludesVat: priceIncludesVat ?? this.priceIncludesVat,
      referenceSupplierPriceId:
          referenceSupplierPriceId ?? this.referenceSupplierPriceId,
      referenceSupplierCost:
          referenceSupplierCost ?? this.referenceSupplierCost,
      calculatedSaleNetPrice:
          calculatedSaleNetPrice ?? this.calculatedSaleNetPrice,
      calculatedSaleGrossPrice:
          calculatedSaleGrossPrice ?? this.calculatedSaleGrossPrice,
      calculatedProfitValue:
          calculatedProfitValue ?? this.calculatedProfitValue,
      calculatedProfitPercentOnCost:
          calculatedProfitPercentOnCost ?? this.calculatedProfitPercentOnCost,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'price_list_id': priceListId,
      'product_id': productId,
      'currency': currency,
      'pricing_mode': pricingMode.value,
      'percentage_basis': percentageBasis.value,
      'pricing_value': pricingValue,
      'manual_sale_price': manualSalePrice,
      'vat_percent': vatPercent,
      'price_includes_vat': priceIncludesVat,
      'reference_supplier_price_id': referenceSupplierPriceId,
      'reference_supplier_cost': referenceSupplierCost,
      'calculated_sale_net_price': calculatedSaleNetPrice,
      'calculated_sale_gross_price': calculatedSaleGrossPrice,
      'calculated_profit_value': calculatedProfitValue,
      'calculated_profit_percent_on_cost': calculatedProfitPercentOnCost,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PriceListEntryRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return PriceListEntryRecord(
      id: _stringFromMap(map, const <String>['id']),
      priceListId: _stringFromMap(
        map,
        const <String>['price_list_id', 'priceListId'],
      ),
      productId: _stringFromMap(map, const <String>['product_id', 'productId']),
      currency:
          _stringFromMap(map, const <String>['currency'], fallback: 'RON'),
      pricingMode: SalePricingMode.fromValue(
        _stringFromMap(map, const <String>['pricing_mode', 'pricingMode']),
      ),
      percentageBasis: PercentageBasis.fromValue(
        _stringFromMap(
          map,
          const <String>['percentage_basis', 'percentageBasis'],
        ),
      ),
      pricingValue: _doubleFromMap(map['pricing_value'] ?? map['pricingValue']),
      manualSalePrice: _doubleFromMap(
        map['manual_sale_price'] ?? map['manualSalePrice'],
      ),
      vatPercent: _doubleFromMap(map['vat_percent'] ?? map['vatPercent'], 19),
      priceIncludesVat: _boolFromMap(
        map['price_includes_vat'] ?? map['priceIncludesVat'],
      ),
      referenceSupplierPriceId: _stringFromMap(
        map,
        const <String>[
          'reference_supplier_price_id',
          'referenceSupplierPriceId',
        ],
      ),
      referenceSupplierCost: _doubleFromMap(
        map['reference_supplier_cost'] ?? map['referenceSupplierCost'],
      ),
      calculatedSaleNetPrice: _doubleFromMap(
        map['calculated_sale_net_price'] ?? map['calculatedSaleNetPrice'],
      ),
      calculatedSaleGrossPrice: _doubleFromMap(
        map['calculated_sale_gross_price'] ?? map['calculatedSaleGrossPrice'],
      ),
      calculatedProfitValue: _doubleFromMap(
        map['calculated_profit_value'] ?? map['calculatedProfitValue'],
      ),
      calculatedProfitPercentOnCost: _doubleFromMap(
        map['calculated_profit_percent_on_cost'] ??
            map['calculatedProfitPercentOnCost'],
      ),
      notes: _stringFromMap(map, const <String>['notes']),
      createdAt: _dateFromMap(map['created_at'] ?? map['createdAt'], now),
      updatedAt: _dateFromMap(map['updated_at'] ?? map['updatedAt'], now),
    );
  }
}

class SupplierCostBreakdown {
  const SupplierCostBreakdown({
    required this.baseSupplierPrice,
    required this.discountValueApplied,
    required this.discountedPrice,
    required this.netSupplierCost,
    required this.greenStampCost,
    required this.transportCost,
    required this.otherCosts,
    required this.finalEntryCost,
    required this.vatValueIncluded,
  });

  final double baseSupplierPrice;
  final double discountValueApplied;
  final double discountedPrice;
  final double netSupplierCost;
  final double greenStampCost;
  final double transportCost;
  final double otherCosts;
  final double finalEntryCost;
  final double vatValueIncluded;
}

class SalePriceBreakdown {
  const SalePriceBreakdown({
    required this.costBeforePricing,
    required this.saleNetPrice,
    required this.saleGrossPrice,
    required this.profitValue,
    required this.profitPercentOnCost,
    required this.pricingMode,
    required this.pricingValue,
  });

  final double costBeforePricing;
  final double saleNetPrice;
  final double saleGrossPrice;
  final double profitValue;
  final double profitPercentOnCost;
  final SalePricingMode pricingMode;
  final double pricingValue;
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

double _doubleFromMap(dynamic raw, [double fallback = 0]) {
  if (raw is num) {
    return raw.toDouble();
  }
  final normalized = (raw ?? '').toString().trim().replaceAll(',', '.');
  return double.tryParse(normalized) ?? fallback;
}

bool _boolFromMap(dynamic raw, {bool fallback = false}) {
  if (raw is bool) {
    return raw;
  }
  final normalized = (raw ?? '').toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'da') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'nu') {
    return false;
  }
  return fallback;
}

DateTime _dateFromMap(dynamic raw, DateTime fallback) {
  return DateTime.tryParse((raw ?? '').toString()) ?? fallback;
}

DateTime? _nullableDateFromMap(dynamic raw) {
  final normalized = (raw ?? '').toString().trim();
  if (normalized.isEmpty) {
    return null;
  }
  return DateTime.tryParse(normalized);
}

List<String> _stringListFromMap(dynamic raw) {
  if (raw is List) {
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final normalized = raw?.toString().trim() ?? '';
  if (normalized.isEmpty) {
    return const <String>[];
  }
  return normalized
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
