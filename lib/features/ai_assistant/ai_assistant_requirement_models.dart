enum AiRequirementItemCategory {
  material,
  equipment,
  service,
  labor,
  accessory,
  consumable,
  unknown,
}

extension AiRequirementItemCategoryX on AiRequirementItemCategory {
  String get value {
    switch (this) {
      case AiRequirementItemCategory.material:
        return 'material';
      case AiRequirementItemCategory.equipment:
        return 'equipment';
      case AiRequirementItemCategory.service:
        return 'service';
      case AiRequirementItemCategory.labor:
        return 'labor';
      case AiRequirementItemCategory.accessory:
        return 'accessory';
      case AiRequirementItemCategory.consumable:
        return 'consumable';
      case AiRequirementItemCategory.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case AiRequirementItemCategory.material:
        return 'Materiale';
      case AiRequirementItemCategory.equipment:
        return 'Echipamente';
      case AiRequirementItemCategory.service:
        return 'Servicii';
      case AiRequirementItemCategory.labor:
        return 'Manopera';
      case AiRequirementItemCategory.accessory:
        return 'Accesorii';
      case AiRequirementItemCategory.consumable:
        return 'Consumabile';
      case AiRequirementItemCategory.unknown:
        return 'Necesita clarificare';
    }
  }

  static AiRequirementItemCategory fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return AiRequirementItemCategory.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AiRequirementItemCategory.unknown,
    );
  }
}

enum AiRequirementConfidenceBand {
  sure,
  probable,
  needsReview,
}

extension AiRequirementConfidenceBandX on AiRequirementConfidenceBand {
  String get label {
    switch (this) {
      case AiRequirementConfidenceBand.sure:
        return 'sigur';
      case AiRequirementConfidenceBand.probable:
        return 'probabil';
      case AiRequirementConfidenceBand.needsReview:
        return 'necesita verificare';
    }
  }
}

class AiRequirementCatalogMatch {
  const AiRequirementCatalogMatch({
    required this.productId,
    required this.productLabel,
    required this.score,
    this.notes = '',
    this.isAlternative = false,
    this.isMissing = false,
  });

  final String productId;
  final String productLabel;
  final double score;
  final String notes;
  final bool isAlternative;
  final bool isMissing;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'product_id': productId,
      'product_label': productLabel,
      'score': score,
      'notes': notes,
      'is_alternative': isAlternative,
      'is_missing': isMissing,
    };
  }

  factory AiRequirementCatalogMatch.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ?? 0;
    }

    return AiRequirementCatalogMatch(
      productId:
          (map['product_id'] ?? map['productId'] ?? '').toString().trim(),
      productLabel:
          (map['product_label'] ?? map['productLabel'] ?? '').toString().trim(),
      score: parseDouble(map['score']),
      notes: (map['notes'] ?? '').toString().trim(),
      isAlternative:
          map['is_alternative'] == true || map['isAlternative'] == true,
      isMissing: map['is_missing'] == true || map['isMissing'] == true,
    );
  }
}

class AiRequirementRecognizedItem {
  const AiRequirementRecognizedItem({
    required this.id,
    required this.sourceText,
    required this.normalizedName,
    required this.category,
    required this.unitOfMeasure,
    required this.quantity,
    required this.technicalSpecs,
    required this.brand,
    required this.model,
    required this.notes,
    required this.confidence,
    required this.needsReview,
    this.suggestedQuestions = const <String>[],
    this.flags = const <String>[],
    this.catalogMatches = const <AiRequirementCatalogMatch>[],
  });

  final String id;
  final String sourceText;
  final String normalizedName;
  final AiRequirementItemCategory category;
  final String unitOfMeasure;
  final double quantity;
  final String technicalSpecs;
  final String brand;
  final String model;
  final String notes;
  final double confidence;
  final bool needsReview;
  final List<String> suggestedQuestions;
  final List<String> flags;
  final List<AiRequirementCatalogMatch> catalogMatches;

  AiRequirementConfidenceBand get confidenceBand {
    if (needsReview || confidence < 0.45) {
      return AiRequirementConfidenceBand.needsReview;
    }
    if (confidence < 0.8) {
      return AiRequirementConfidenceBand.probable;
    }
    return AiRequirementConfidenceBand.sure;
  }

  AiRequirementRecognizedItem copyWith({
    String? id,
    String? sourceText,
    String? normalizedName,
    AiRequirementItemCategory? category,
    String? unitOfMeasure,
    double? quantity,
    String? technicalSpecs,
    String? brand,
    String? model,
    String? notes,
    double? confidence,
    bool? needsReview,
    List<String>? suggestedQuestions,
    List<String>? flags,
    List<AiRequirementCatalogMatch>? catalogMatches,
  }) {
    return AiRequirementRecognizedItem(
      id: id ?? this.id,
      sourceText: sourceText ?? this.sourceText,
      normalizedName: normalizedName ?? this.normalizedName,
      category: category ?? this.category,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      quantity: quantity ?? this.quantity,
      technicalSpecs: technicalSpecs ?? this.technicalSpecs,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      notes: notes ?? this.notes,
      confidence: confidence ?? this.confidence,
      needsReview: needsReview ?? this.needsReview,
      suggestedQuestions: suggestedQuestions ?? this.suggestedQuestions,
      flags: flags ?? this.flags,
      catalogMatches: catalogMatches ?? this.catalogMatches,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'source_text': sourceText,
      'normalized_name': normalizedName,
      'category': category.value,
      'unit_of_measure': unitOfMeasure,
      'quantity': quantity,
      'technical_specs': technicalSpecs,
      'brand': brand,
      'model': model,
      'notes': notes,
      'confidence': confidence,
      'needs_review': needsReview,
      'suggested_questions': suggestedQuestions,
      'flags': flags,
      'catalog_matches':
          catalogMatches.map((item) => item.toMap()).toList(growable: false),
    };
  }

  factory AiRequirementRecognizedItem.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw, [double fallback = 0]) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ??
          fallback;
    }

    List<String> parseStrings(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    List<AiRequirementCatalogMatch> parseMatches(dynamic raw) {
      if (raw is! List) return const <AiRequirementCatalogMatch>[];
      return raw
          .whereType<Map>()
          .map((item) => AiRequirementCatalogMatch.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false);
    }

    return AiRequirementRecognizedItem(
      id: (map['id'] ?? '').toString().trim(),
      sourceText:
          (map['source_text'] ?? map['sourceText'] ?? '').toString().trim(),
      normalizedName: (map['normalized_name'] ?? map['normalizedName'] ?? '')
          .toString()
          .trim(),
      category: AiRequirementItemCategoryX.fromValue(
        (map['category'] ?? '').toString(),
      ),
      unitOfMeasure: (map['unit_of_measure'] ?? map['unitOfMeasure'] ?? '')
          .toString()
          .trim(),
      quantity: parseDouble(map['quantity'], 0),
      technicalSpecs: (map['technical_specs'] ?? map['technicalSpecs'] ?? '')
          .toString()
          .trim(),
      brand: (map['brand'] ?? '').toString().trim(),
      model: (map['model'] ?? '').toString().trim(),
      notes: (map['notes'] ?? '').toString().trim(),
      confidence: parseDouble(map['confidence'], 0),
      needsReview: map['needs_review'] == true || map['needsReview'] == true,
      suggestedQuestions: parseStrings(
        map['suggested_questions'] ?? map['suggestedQuestions'],
      ),
      flags: parseStrings(map['flags']),
      catalogMatches: parseMatches(
        map['catalog_matches'] ?? map['catalogMatches'],
      ),
    );
  }
}

class AiRequirementOfferPositionDraft {
  const AiRequirementOfferPositionDraft({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.unitOfMeasure,
    required this.quantity,
    required this.confidence,
    required this.needsReview,
    this.sourceItemIds = const <String>[],
    this.matchedProductId = '',
    this.matchedProductLabel = '',
    this.servicePresetCode = '',
    this.notes = '',
    this.accepted = true,
    this.alternativeProductLabels = const <String>[],
  });

  final String id;
  final String title;
  final String description;
  final AiRequirementItemCategory category;
  final String unitOfMeasure;
  final double quantity;
  final double confidence;
  final bool needsReview;
  final List<String> sourceItemIds;
  final String matchedProductId;
  final String matchedProductLabel;
  final String servicePresetCode;
  final String notes;
  final bool accepted;
  final List<String> alternativeProductLabels;

  AiRequirementConfidenceBand get confidenceBand {
    if (needsReview || confidence < 0.45) {
      return AiRequirementConfidenceBand.needsReview;
    }
    if (confidence < 0.8) {
      return AiRequirementConfidenceBand.probable;
    }
    return AiRequirementConfidenceBand.sure;
  }

  AiRequirementOfferPositionDraft copyWith({
    String? id,
    String? title,
    String? description,
    AiRequirementItemCategory? category,
    String? unitOfMeasure,
    double? quantity,
    double? confidence,
    bool? needsReview,
    List<String>? sourceItemIds,
    String? matchedProductId,
    String? matchedProductLabel,
    String? servicePresetCode,
    String? notes,
    bool? accepted,
    List<String>? alternativeProductLabels,
  }) {
    return AiRequirementOfferPositionDraft(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      quantity: quantity ?? this.quantity,
      confidence: confidence ?? this.confidence,
      needsReview: needsReview ?? this.needsReview,
      sourceItemIds: sourceItemIds ?? this.sourceItemIds,
      matchedProductId: matchedProductId ?? this.matchedProductId,
      matchedProductLabel: matchedProductLabel ?? this.matchedProductLabel,
      servicePresetCode: servicePresetCode ?? this.servicePresetCode,
      notes: notes ?? this.notes,
      accepted: accepted ?? this.accepted,
      alternativeProductLabels:
          alternativeProductLabels ?? this.alternativeProductLabels,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'category': category.value,
      'unit_of_measure': unitOfMeasure,
      'quantity': quantity,
      'confidence': confidence,
      'needs_review': needsReview,
      'source_item_ids': sourceItemIds,
      'matched_product_id': matchedProductId,
      'matched_product_label': matchedProductLabel,
      'service_preset_code': servicePresetCode,
      'notes': notes,
      'accepted': accepted,
      'alternative_product_labels': alternativeProductLabels,
    };
  }

  factory AiRequirementOfferPositionDraft.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw, [double fallback = 0]) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '').toString().replaceAll(',', '.')) ??
          fallback;
    }

    List<String> parseStrings(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return AiRequirementOfferPositionDraft(
      id: (map['id'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString().trim(),
      description: (map['description'] ?? '').toString().trim(),
      category: AiRequirementItemCategoryX.fromValue(
        (map['category'] ?? '').toString(),
      ),
      unitOfMeasure: (map['unit_of_measure'] ?? map['unitOfMeasure'] ?? '')
          .toString()
          .trim(),
      quantity: parseDouble(map['quantity'], 0),
      confidence: parseDouble(map['confidence'], 0),
      needsReview: map['needs_review'] == true || map['needsReview'] == true,
      sourceItemIds: parseStrings(
        map['source_item_ids'] ?? map['sourceItemIds'],
      ),
      matchedProductId:
          (map['matched_product_id'] ?? map['matchedProductId'] ?? '')
              .toString()
              .trim(),
      matchedProductLabel:
          (map['matched_product_label'] ?? map['matchedProductLabel'] ?? '')
              .toString()
              .trim(),
      servicePresetCode:
          (map['service_preset_code'] ?? map['servicePresetCode'] ?? '')
              .toString()
              .trim(),
      notes: (map['notes'] ?? '').toString().trim(),
      accepted: map['accepted'] != false,
      alternativeProductLabels: parseStrings(
        map['alternative_product_labels'] ?? map['alternativeProductLabels'],
      ),
    );
  }
}

class AiRequirementAnalysisResult {
  const AiRequirementAnalysisResult({
    required this.originalRequirement,
    required this.recognizedItems,
    required this.offerPositions,
    this.clarificationQuestions = const <String>[],
    this.warnings = const <String>[],
    this.suggestedServices = const <String>[],
    this.suggestedAccessories = const <String>[],
    this.draftNotes = '',
    this.unavailableReason = '',
  });

  final String originalRequirement;
  final List<AiRequirementRecognizedItem> recognizedItems;
  final List<AiRequirementOfferPositionDraft> offerPositions;
  final List<String> clarificationQuestions;
  final List<String> warnings;
  final List<String> suggestedServices;
  final List<String> suggestedAccessories;
  final String draftNotes;
  final String unavailableReason;

  bool get isAvailable => unavailableReason.trim().isEmpty;
  bool get canCreateDraft =>
      isAvailable && offerPositions.any((item) => item.accepted);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'original_requirement': originalRequirement,
      'recognized_items':
          recognizedItems.map((item) => item.toMap()).toList(growable: false),
      'offer_positions':
          offerPositions.map((item) => item.toMap()).toList(growable: false),
      'clarification_questions': clarificationQuestions,
      'warnings': warnings,
      'suggested_services': suggestedServices,
      'suggested_accessories': suggestedAccessories,
      'draft_notes': draftNotes,
      'unavailable_reason': unavailableReason,
    };
  }
}
