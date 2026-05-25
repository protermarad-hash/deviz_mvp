class OfferCommercialPackageMaterialTemplate {
  const OfferCommercialPackageMaterialTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.unit = 'buc',
    this.quantity = 1,
    this.unitPrice = 0,
    this.materialId = '',
  });

  final String id;
  final String name;
  final String description;
  final String unit;
  final double quantity;
  final double unitPrice;
  final String materialId;

  OfferCommercialPackageMaterialTemplate copyWith({
    String? id,
    String? name,
    String? description,
    String? unit,
    double? quantity,
    double? unitPrice,
    String? materialId,
  }) {
    return OfferCommercialPackageMaterialTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      materialId: materialId ?? this.materialId,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'unit': unit,
      'quantity': quantity,
      'unit_price': unitPrice,
      'material_id': materialId,
    };
  }

  factory OfferCommercialPackageMaterialTemplate.fromMap(
    Map<String, dynamic> map,
  ) {
    double asDouble(dynamic raw) {
      if (raw is num) {
        return raw.toDouble();
      }
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    return OfferCommercialPackageMaterialTemplate(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      unit: (map['unit'] ?? 'buc').toString(),
      quantity: asDouble(map['quantity']),
      unitPrice: asDouble(map['unit_price'] ?? map['unitPrice']),
      materialId: (map['material_id'] ?? map['materialId'] ?? '').toString(),
    );
  }
}

class OfferCommercialPackageLaborTemplate {
  const OfferCommercialPackageLaborTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.unit = 'ore',
    this.quantity = 1,
    this.unitPrice = 0,
    this.laborTemplateId = '',
  });

  final String id;
  final String name;
  final String description;
  final String unit;
  final double quantity;
  final double unitPrice;
  final String laborTemplateId;

  OfferCommercialPackageLaborTemplate copyWith({
    String? id,
    String? name,
    String? description,
    String? unit,
    double? quantity,
    double? unitPrice,
    String? laborTemplateId,
  }) {
    return OfferCommercialPackageLaborTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      laborTemplateId: laborTemplateId ?? this.laborTemplateId,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'unit': unit,
      'quantity': quantity,
      'unit_price': unitPrice,
      'labor_template_id': laborTemplateId,
    };
  }

  factory OfferCommercialPackageLaborTemplate.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic raw) {
      if (raw is num) {
        return raw.toDouble();
      }
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    return OfferCommercialPackageLaborTemplate(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      unit: (map['unit'] ?? 'ore').toString(),
      quantity: asDouble(map['quantity']),
      unitPrice: asDouble(map['unit_price'] ?? map['unitPrice']),
      laborTemplateId:
          (map['labor_template_id'] ?? map['laborTemplateId'] ?? '').toString(),
    );
  }
}

class OfferCommercialPackageClauseTemplate {
  const OfferCommercialPackageClauseTemplate({
    required this.id,
    required this.title,
    required this.content,
    this.templateId = '',
    this.category = '',
  });

  final String id;
  final String title;
  final String content;
  final String templateId;
  final String category;

  OfferCommercialPackageClauseTemplate copyWith({
    String? id,
    String? title,
    String? content,
    String? templateId,
    String? category,
  }) {
    return OfferCommercialPackageClauseTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      templateId: templateId ?? this.templateId,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'template_id': templateId,
      'category': category,
    };
  }

  factory OfferCommercialPackageClauseTemplate.fromMap(
    Map<String, dynamic> map,
  ) {
    return OfferCommercialPackageClauseTemplate(
      id: (map['id'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      templateId: (map['template_id'] ?? map['templateId'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
    );
  }
}

class OfferCommercialPackageTemplate {
  const OfferCommercialPackageTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.isActive = true,
    this.materials = const <OfferCommercialPackageMaterialTemplate>[],
    this.standardLabor = const <OfferCommercialPackageLaborTemplate>[],
    this.commercialClauses = const <OfferCommercialPackageClauseTemplate>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final bool isActive;
  final List<OfferCommercialPackageMaterialTemplate> materials;
  final List<OfferCommercialPackageLaborTemplate> standardLabor;
  final List<OfferCommercialPackageClauseTemplate> commercialClauses;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OfferCommercialPackageTemplate copyWith({
    String? id,
    String? name,
    String? description,
    bool? isActive,
    List<OfferCommercialPackageMaterialTemplate>? materials,
    List<OfferCommercialPackageLaborTemplate>? standardLabor,
    List<OfferCommercialPackageClauseTemplate>? commercialClauses,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfferCommercialPackageTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      materials: materials ?? this.materials,
      standardLabor: standardLabor ?? this.standardLabor,
      commercialClauses: commercialClauses ?? this.commercialClauses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'is_active': isActive,
      'materials': materials.map((item) => item.toMap()).toList(growable: false),
      'standard_labor':
          standardLabor.map((item) => item.toMap()).toList(growable: false),
      'commercial_clauses':
          commercialClauses.map((item) => item.toMap()).toList(growable: false),
      'created_at': createdAt?.toIso8601String() ?? '',
      'updated_at': updatedAt?.toIso8601String() ?? '',
    };
  }

  factory OfferCommercialPackageTemplate.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty) {
        return null;
      }
      return DateTime.tryParse(text);
    }

    List<T> parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic> row) parser,
    ) {
      if (raw is! List) {
        return <T>[];
      }
      return raw
          .whereType<Map>()
          .map((item) => parser(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    return OfferCommercialPackageTemplate(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      isActive: map['is_active'] == null
          ? ((map['isActive'] ?? true) == true)
          : map['is_active'] == true,
      materials: parseList(
        map['materials'],
        OfferCommercialPackageMaterialTemplate.fromMap,
      ),
      standardLabor: parseList(
        map['standard_labor'] ?? map['standardLabor'],
        OfferCommercialPackageLaborTemplate.fromMap,
      ),
      commercialClauses: parseList(
        map['commercial_clauses'] ?? map['commercialClauses'],
        OfferCommercialPackageClauseTemplate.fromMap,
      ),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}
