class OfferLaborTemplate {
  const OfferLaborTemplate({
    required this.id,
    required this.name,
    this.category = '',
    required this.description,
    required this.unit,
    required this.defaultQuantity,
    required this.defaultUnitPrice,
    required this.isActive,
    this.notes = '',
    this.includedServices = '',
    this.suggestedProductKeywords = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final String unit;
  final double defaultQuantity;
  final double defaultUnitPrice;
  final bool isActive;
  final String notes;
  final String includedServices;
  final String suggestedProductKeywords;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OfferLaborTemplate copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    String? unit,
    double? defaultQuantity,
    double? defaultUnitPrice,
    bool? isActive,
    String? notes,
    String? includedServices,
    String? suggestedProductKeywords,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfferLaborTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      defaultQuantity: defaultQuantity ?? this.defaultQuantity,
      defaultUnitPrice: defaultUnitPrice ?? this.defaultUnitPrice,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      includedServices: includedServices ?? this.includedServices,
      suggestedProductKeywords:
          suggestedProductKeywords ?? this.suggestedProductKeywords,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'unit': unit,
      'default_quantity': defaultQuantity,
      'default_unit_price': defaultUnitPrice,
      'is_active': isActive,
      'notes': notes,
      'included_services': includedServices,
      'suggested_product_keywords': suggestedProductKeywords,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory OfferLaborTemplate.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic raw, [double fallback = 0]) {
      if (raw == null) return fallback;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString().replaceAll(',', '.').trim()) ??
          fallback;
    }

    DateTime? parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    return OfferLaborTemplate(
      id: (map['id'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      category: (map['category'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString(),
      unit: (map['unit'] ?? '').toString().trim(),
      defaultQuantity:
          asDouble(map['default_quantity'] ?? map['defaultQuantity'], 1),
      defaultUnitPrice:
          asDouble(map['default_unit_price'] ?? map['defaultUnitPrice'], 0),
      isActive: map['is_active'] == null
          ? (map['isActive'] is bool ? map['isActive'] as bool : true)
          : map['is_active'] == true,
      notes: (map['notes'] ?? '').toString(),
      includedServices:
          (map['included_services'] ?? map['includedServices'] ?? '')
              .toString(),
      suggestedProductKeywords: (map['suggested_product_keywords'] ??
              map['suggestedProductKeywords'] ??
              '')
          .toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}

class OfferCommercialClauseTemplate {
  const OfferCommercialClauseTemplate({
    required this.id,
    required this.title,
    required this.content,
    required this.isActive,
    this.category = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final bool isActive;
  final String category;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OfferCommercialClauseTemplate copyWith({
    String? id,
    String? title,
    String? content,
    bool? isActive,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfferCommercialClauseTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      isActive: isActive ?? this.isActive,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'is_active': isActive,
      'category': category,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory OfferCommercialClauseTemplate.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    return OfferCommercialClauseTemplate(
      id: (map['id'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString().trim(),
      content: (map['content'] ?? '').toString(),
      isActive: map['is_active'] == null
          ? (map['isActive'] is bool ? map['isActive'] as bool : true)
          : map['is_active'] == true,
      category: (map['category'] ?? '').toString(),
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
    );
  }
}
