import 'package:uuid/uuid.dart';

/// Categoria de alocare a unei încasări — cu ce datorie stinge plata primită.
/// Backward compat: date vechi fără câmpul acesta → tratate ca 'general'.
enum PartnerCollectionCategory {
  general,    // nealocată / legacy — scade din totalul general
  work,       // lucrări / manoperă
  materials,  // materiale / kituri
  products,   // vânzări produse
  mixed;      // mixtă (sumasplit pe subcâmpuri allocatedWork/Materials/Products)

  String get value => name;

  String get label {
    switch (this) {
      case PartnerCollectionCategory.general:   return 'Încasare generală';
      case PartnerCollectionCategory.work:      return 'Lucrări / manoperă';
      case PartnerCollectionCategory.materials: return 'Materiale / kituri';
      case PartnerCollectionCategory.products:  return 'Produse';
      case PartnerCollectionCategory.mixed:     return 'Mixtă';
    }
  }

  static PartnerCollectionCategory fromValue(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    for (final item in PartnerCollectionCategory.values) {
      if (item.value == v) return item;
    }
    return PartnerCollectionCategory.general;
  }
}

enum PartnerTransactionType {
  incasareProgramare,
  plataProgramare,
  vanzareProdus,
  achizitieProodus,
  plataManuala,
  incasareManuala,
  consumMateriale; // materiale/kituri folosite pentru lucrarea partenerului

  String get value {
    switch (this) {
      case PartnerTransactionType.incasareProgramare:
        return 'incasare_programare';
      case PartnerTransactionType.plataProgramare:
        return 'plata_programare';
      case PartnerTransactionType.vanzareProdus:
        return 'vanzare_produs';
      case PartnerTransactionType.achizitieProodus:
        return 'achizitie_produs';
      case PartnerTransactionType.plataManuala:
        return 'plata_manuala';
      case PartnerTransactionType.incasareManuala:
        return 'incasare_manuala';
      case PartnerTransactionType.consumMateriale:
        return 'consum_materiale';
    }
  }

  String get label {
    switch (this) {
      case PartnerTransactionType.incasareProgramare:
        return 'Încasare programare';
      case PartnerTransactionType.plataProgramare:
        return 'Plată programare';
      case PartnerTransactionType.vanzareProdus:
        return 'Vânzare produs';
      case PartnerTransactionType.achizitieProodus:
        return 'Achiziție produs';
      case PartnerTransactionType.plataManuala:
        return 'Plată manuală';
      case PartnerTransactionType.incasareManuala:
        return 'Încasare manuală';
      case PartnerTransactionType.consumMateriale:
        return 'Materiale folosite';
    }
  }

  static PartnerTransactionType fromValue(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    for (final item in PartnerTransactionType.values) {
      if (item.value == v) return item;
    }
    // Default sigur: incasareProgramare adaugă la De Încasat (credit_neincasat).
    // incasareManuala ca default era periculos — tranzacțiile cu tip necunoscut/gol
    // deveneau automat plăți primite (plata_primita) și reduceau De Încasat fals.
    return PartnerTransactionType.incasareProgramare;
  }
}

// ---------------------------------------------------------------------------
// Linie de material (pentru transparență în fișa partenerului)
// ---------------------------------------------------------------------------

class PartnerMaterialLine {
  const PartnerMaterialLine({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.unitCost,
  });

  final String name;
  final String unit;
  final double quantity;
  final double unitCost;

  double get totalCost => quantity * unitCost;

  Map<String, dynamic> toMap() => {
        'name': name,
        'unit': unit,
        'quantity': quantity,
        'unit_cost': unitCost,
      };

  factory PartnerMaterialLine.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    return PartnerMaterialLine(
      name: (map['name'] ?? '').toString(),
      unit: (map['unit'] ?? '').toString(),
      quantity: parseDouble(map['quantity']),
      unitCost: parseDouble(map['unit_cost'] ?? map['unitCost']),
    );
  }
}

enum PartnerTransactionDirection {
  intrare,
  iesire;

  String get value => name;

  String get label {
    switch (this) {
      case PartnerTransactionDirection.intrare:
        return 'Intrare';
      case PartnerTransactionDirection.iesire:
        return 'Ieșire';
    }
  }

  static PartnerTransactionDirection fromValue(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    return v == 'iesire'
        ? PartnerTransactionDirection.iesire
        : PartnerTransactionDirection.intrare;
  }
}

enum PartnerTransactionPaymentMethod {
  cash,
  transfer,
  card;

  String get value => name;

  String get label {
    switch (this) {
      case PartnerTransactionPaymentMethod.cash:
        return 'Numerar';
      case PartnerTransactionPaymentMethod.transfer:
        return 'Transfer bancar';
      case PartnerTransactionPaymentMethod.card:
        return 'Card';
    }
  }

  static PartnerTransactionPaymentMethod fromValue(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    for (final item in PartnerTransactionPaymentMethod.values) {
      if (item.value == v) return item;
    }
    return PartnerTransactionPaymentMethod.cash;
  }
}

enum PartnerTransactionStatus {
  neplatit,
  partial,
  platit;

  String get value => name;

  String get label {
    switch (this) {
      case PartnerTransactionStatus.neplatit:
        return 'Neîncasat';
      case PartnerTransactionStatus.partial:
        return 'Parțial';
      case PartnerTransactionStatus.platit:
        return 'Plătit';
    }
  }

  static PartnerTransactionStatus fromValue(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    for (final item in PartnerTransactionStatus.values) {
      if (item.value == v) return item;
    }
    return PartnerTransactionStatus.neplatit;
  }
}

class PartnerTransaction {
  PartnerTransaction({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.type,
    required this.direction,
    required this.amount,
    required this.date,
    required this.description,
    this.referenceId = '',
    this.referenceType = '',
    this.paymentMethod = PartnerTransactionPaymentMethod.cash,
    this.status = PartnerTransactionStatus.neplatit,
    this.createdBy = '',
    this.notes = '',
    this.kitName = '',
    this.materialLines = const <PartnerMaterialLine>[],
    this.isRefacturable = false,
    this.collectionCategory = PartnerCollectionCategory.general,
    this.allocatedWorkAmount = 0,
    this.allocatedMaterialsAmount = 0,
    this.allocatedProductsAmount = 0,
    this.settlementId = '',
    this.isLocked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String partnerId;
  final String partnerName;
  final PartnerTransactionType type;
  final PartnerTransactionDirection direction;
  final double amount;
  final DateTime date;
  final String description;
  final String referenceId;
  final String referenceType;
  final PartnerTransactionPaymentMethod paymentMethod;
  final PartnerTransactionStatus status;
  final String createdBy;
  final String notes;
  /// Numele kitului folosit (dacă tipul e consumMateriale)
  final String kitName;
  /// Linii de materiale detaliate (backward compatible — default [])
  final List<PartnerMaterialLine> materialLines;
  /// Dacă true, costul materialelor consumate se refacturează partenerului
  /// și intră în soldul De Încasat (credit_neincasat).
  /// Dacă false (default), sunt cost intern separat — nu modifică soldul.
  final bool isRefacturable;

  // ── Câmpuri alocare încasare (Etapa 2) ─────────────────────────────────────
  /// Categorie alocare — cu ce datorie stinge această încasare.
  /// Relevantă doar pentru type == incasareManuala.
  /// Default 'general' → backward compat cu date vechi.
  final PartnerCollectionCategory collectionCategory;
  /// Sumă alocată lucrărilor (relevant pentru mixed)
  final double allocatedWorkAmount;
  /// Sumă alocată materialelor (relevant pentru mixed)
  final double allocatedMaterialsAmount;
  /// Sumă alocată produselor (relevant pentru mixed)
  final double allocatedProductsAmount;

  // ── Câmpuri reconciliere (Etapa 4) ─────────────────────────────────────────
  /// ID-ul perioadei de reconciliere în care e inclusă această tranzacție.
  /// Gol (default) = tranzacție liberă, neinclusă în nicio reconciliere.
  final String settlementId;
  /// Dacă true, tranzacția e blocată — nu poate fi editată sau ștearsă.
  /// Se setează la true când perioada de reconciliere se închide.
  final bool isLocked;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Direcție financiară standardizată — calculată din type + status.
  /// Valori posibile:
  ///   'credit_neincasat'          – credit de la partener, neîncasat
  ///   'credit_incasat'            – credit de la partener, marcat plătit direct
  ///   'plata_primita'             – bani primiți efectiv (incasareManuala, MEREU)
  ///   'plata_efectuata'           – datorie a noastră, neachitată
  ///   'plata_efectuata_achitata'  – datorie a noastră, achitată
  ///   'cost_materiale'            – exclus din sold (banner portocaliu separat)
  String get financialDirection {
    switch (type) {
      case PartnerTransactionType.consumMateriale:
        // Materialele/kiturile folosite la lucrările partenerului sunt MEREU
        // de recuperat — apar separat de manoperă în sumar și liste.
        return 'credit_neincasat';

      case PartnerTransactionType.incasareManuala:
        // Plată PRIMITĂ efectiv de la partener — MEREU reduce soldul,
        // indiferent de câmpul status (date vechi pot fi status=neplatit).
        return 'plata_primita';

      case PartnerTransactionType.incasareProgramare:
      case PartnerTransactionType.vanzareProdus:
        return status == PartnerTransactionStatus.platit
            ? 'credit_incasat'
            : 'credit_neincasat';

      case PartnerTransactionType.plataManuala:
      case PartnerTransactionType.plataProgramare:
      case PartnerTransactionType.achizitieProodus:
        return status == PartnerTransactionStatus.platit
            ? 'plata_efectuata_achitata'
            : 'plata_efectuata';
    }
  }

  static String generateId() => const Uuid().v4();

  PartnerTransaction copyWith({
    String? id,
    String? partnerId,
    String? partnerName,
    PartnerTransactionType? type,
    PartnerTransactionDirection? direction,
    double? amount,
    DateTime? date,
    String? description,
    String? referenceId,
    String? referenceType,
    PartnerTransactionPaymentMethod? paymentMethod,
    PartnerTransactionStatus? status,
    String? createdBy,
    String? notes,
    String? kitName,
    List<PartnerMaterialLine>? materialLines,
    bool? isRefacturable,
    PartnerCollectionCategory? collectionCategory,
    double? allocatedWorkAmount,
    double? allocatedMaterialsAmount,
    double? allocatedProductsAmount,
    String? settlementId,
    bool? isLocked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PartnerTransaction(
      id: id ?? this.id,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      notes: notes ?? this.notes,
      kitName: kitName ?? this.kitName,
      materialLines: materialLines ?? this.materialLines,
      isRefacturable: isRefacturable ?? this.isRefacturable,
      collectionCategory: collectionCategory ?? this.collectionCategory,
      allocatedWorkAmount: allocatedWorkAmount ?? this.allocatedWorkAmount,
      allocatedMaterialsAmount:
          allocatedMaterialsAmount ?? this.allocatedMaterialsAmount,
      allocatedProductsAmount:
          allocatedProductsAmount ?? this.allocatedProductsAmount,
      settlementId: settlementId ?? this.settlementId,
      isLocked: isLocked ?? this.isLocked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'partner_id': partnerId,
      'partner_name': partnerName,
      'type': type.value,
      'financial_direction': financialDirection,
      'direction': direction.value,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'payment_method': paymentMethod.value,
      'status': status.value,
      'created_by': createdBy,
      'notes': notes,
      'kit_name': kitName,
      'material_lines':
          materialLines.map((l) => l.toMap()).toList(growable: false),
      'is_refacturable': isRefacturable,
      'collection_category': collectionCategory.value,
      'allocated_work_amount': allocatedWorkAmount,
      'allocated_materials_amount': allocatedMaterialsAmount,
      'allocated_products_amount': allocatedProductsAmount,
      'settlement_id': settlementId,
      'is_locked': isLocked,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PartnerTransaction.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    // Parsează liniile de materiale (backward compatible — default [])
    final rawLines = map['material_lines'] ?? map['materialLines'];
    final materialLines = rawLines is List
        ? rawLines
            .whereType<Map>()
            .map((item) => PartnerMaterialLine.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false)
        : const <PartnerMaterialLine>[];

    return PartnerTransaction(
      id: pick(const ['id']),
      partnerId: pick(const ['partner_id', 'partnerId']),
      partnerName: pick(const ['partner_name', 'partnerName']),
      type: PartnerTransactionType.fromValue(
        pick(const ['type']),
      ),
      direction: PartnerTransactionDirection.fromValue(
        pick(const ['direction']),
      ),
      amount: parseDouble(map['amount']),
      date: DateTime.tryParse(pick(const ['date'])) ?? now,
      description: pick(const ['description']),
      referenceId: pick(const ['reference_id', 'referenceId']),
      referenceType: pick(const ['reference_type', 'referenceType']),
      paymentMethod: PartnerTransactionPaymentMethod.fromValue(
        pick(const ['payment_method', 'paymentMethod']),
      ),
      status: PartnerTransactionStatus.fromValue(
        pick(const ['status']),
      ),
      createdBy: pick(const ['created_by', 'createdBy']),
      notes: pick(const ['notes']),
      kitName: pick(const ['kit_name', 'kitName']),
      materialLines: materialLines,
      isRefacturable: (map['is_refacturable'] ?? map['isRefacturable'] ?? false) == true,
      collectionCategory: PartnerCollectionCategory.fromValue(
        (map['collection_category'] ?? map['collectionCategory'] ?? '').toString(),
      ),
      allocatedWorkAmount: parseDouble(
        map['allocated_work_amount'] ?? map['allocatedWorkAmount'] ?? 0,
      ),
      allocatedMaterialsAmount: parseDouble(
        map['allocated_materials_amount'] ?? map['allocatedMaterialsAmount'] ?? 0,
      ),
      allocatedProductsAmount: parseDouble(
        map['allocated_products_amount'] ?? map['allocatedProductsAmount'] ?? 0,
      ),
      settlementId:
          (map['settlement_id'] ?? map['settlementId'] ?? '').toString(),
      isLocked:
          (map['is_locked'] ?? map['isLocked'] ?? false) == true,
      createdAt: DateTime.tryParse(pick(const ['created_at'])) ?? now,
      updatedAt: DateTime.tryParse(pick(const ['updated_at'])) ?? now,
    );
  }
}

class PartnerFinancialSummary {
  const PartnerFinancialSummary({
    required this.partnerId,
    this.partnerName = '',
    this.totalDeIncasat = 0,
    this.totalDePlata = 0,
    this.totalIncasat = 0,
    this.totalPlatit = 0,
    this.lastTransactionDate,
    this.transactionCount = 0,
    required this.updatedAt,
  });

  final String partnerId;
  final String partnerName;
  /// Credite neîncasate — ce mai ai de primit de la partener
  final double totalDeIncasat;
  /// Debite neachitate — ce mai ai de plătit partenerului
  final double totalDePlata;
  /// Credite deja încasate (informativ)
  final double totalIncasat;
  /// Debite deja achitate (informativ)
  final double totalPlatit;
  final DateTime? lastTransactionDate;
  final int transactionCount;
  final DateTime updatedAt;

  double get soldNet => totalDeIncasat - totalDePlata;

  PartnerFinancialSummary copyWith({
    String? partnerId,
    String? partnerName,
    double? totalDeIncasat,
    double? totalDePlata,
    double? totalIncasat,
    double? totalPlatit,
    DateTime? lastTransactionDate,
    bool clearLastTransactionDate = false,
    int? transactionCount,
    DateTime? updatedAt,
  }) {
    return PartnerFinancialSummary(
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      totalDeIncasat: totalDeIncasat ?? this.totalDeIncasat,
      totalDePlata: totalDePlata ?? this.totalDePlata,
      totalIncasat: totalIncasat ?? this.totalIncasat,
      totalPlatit: totalPlatit ?? this.totalPlatit,
      lastTransactionDate: clearLastTransactionDate
          ? null
          : (lastTransactionDate ?? this.lastTransactionDate),
      transactionCount: transactionCount ?? this.transactionCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'partner_id': partnerId,
      'partner_name': partnerName,
      'total_de_incasat': totalDeIncasat,
      'total_de_plata': totalDePlata,
      'total_incasat': totalIncasat,
      'total_platit': totalPlatit,
      'sold_net': soldNet,
      'last_transaction_date': lastTransactionDate?.toIso8601String(),
      'transaction_count': transactionCount,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PartnerFinancialSummary.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return PartnerFinancialSummary(
      partnerId: pick(const ['partner_id', 'partnerId']),
      partnerName: pick(const ['partner_name', 'partnerName']),
      totalDeIncasat: parseDouble(
        map['total_de_incasat'] ?? map['totalDeIncasat'],
      ),
      totalDePlata: parseDouble(
        map['total_de_plata'] ?? map['totalDePlata'],
      ),
      totalIncasat: parseDouble(
        map['total_incasat'] ?? map['totalIncasat'] ?? 0,
      ),
      totalPlatit: parseDouble(
        map['total_platit'] ?? map['totalPlatit'] ?? 0,
      ),
      lastTransactionDate: DateTime.tryParse(
        pick(const ['last_transaction_date', 'lastTransactionDate']),
      ),
      transactionCount:
          (map['transaction_count'] ?? map['transactionCount'] ?? 0) is int
              ? (map['transaction_count'] ?? map['transactionCount'] ?? 0) as int
              : ((map['transaction_count'] ?? map['transactionCount'] ?? 0)
                      as num)
                  .toInt(),
      updatedAt: DateTime.tryParse(pick(const ['updated_at'])) ?? now,
    );
  }

  factory PartnerFinancialSummary.empty(String partnerId,
      {String partnerName = ''}) {
    return PartnerFinancialSummary(
      partnerId: partnerId,
      partnerName: partnerName,
      updatedAt: DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECONCILIERE PERIOADE (Etapa 4)
// ─────────────────────────────────────────────────────────────────────────────

enum PartnerSettlementStatus {
  closed,
  cancelled;

  String get value => name;

  String get label {
    switch (this) {
      case PartnerSettlementStatus.closed:
        return 'Închisă';
      case PartnerSettlementStatus.cancelled:
        return 'Anulată';
    }
  }

  static PartnerSettlementStatus fromValue(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v == 'cancelled') return PartnerSettlementStatus.cancelled;
    return PartnerSettlementStatus.closed;
  }
}

class PartnerSettlementPeriod {
  PartnerSettlementPeriod({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.totalDatorat,
    required this.totalIncasat,
    required this.restDeIncasat,
    required this.totalDePlata,
    required this.soldNet,
    this.adjustmentAmount = 0,
    this.adjustmentNote = '',
    this.lockedTransactionIds = const [],
    this.closedBy = '',
    this.closedByName = '',
    this.closedAt,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String partnerId;
  final String partnerName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final PartnerSettlementStatus status;

  // Sumarul calculat la momentul închiderii
  final double totalDatorat;
  final double totalIncasat;
  final double restDeIncasat;
  final double totalDePlata;
  final double soldNet;

  // Ajustare manuală opțională (echilibrare discrepanțe mici)
  final double adjustmentAmount;
  final String adjustmentNote;

  // IDs-urile tranzacțiilor incluse și blocate
  final List<String> lockedTransactionIds;

  // Audit trail
  final String closedBy;
  final String closedByName;
  final DateTime? closedAt;
  final String notes;

  final DateTime createdAt;
  final DateTime updatedAt;

  static String generateId() => const Uuid().v4();

  Map<String, dynamic> toMap() => {
        'id': id,
        'partner_id': partnerId,
        'partner_name': partnerName,
        'period_start': periodStart.toIso8601String(),
        'period_end': periodEnd.toIso8601String(),
        'status': status.value,
        'total_datorat': totalDatorat,
        'total_incasat': totalIncasat,
        'rest_de_incasat': restDeIncasat,
        'total_de_plata': totalDePlata,
        'sold_net': soldNet,
        'adjustment_amount': adjustmentAmount,
        'adjustment_note': adjustmentNote,
        'locked_transaction_ids': lockedTransactionIds,
        'closed_by': closedBy,
        'closed_by_name': closedByName,
        'closed_at': closedAt?.toIso8601String() ?? '',
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PartnerSettlementPeriod.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final rawIds = map['locked_transaction_ids'];
    final lockedIds = rawIds is List
        ? rawIds.map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    return PartnerSettlementPeriod(
      id: pick(const ['id']),
      partnerId: pick(const ['partner_id', 'partnerId']),
      partnerName: pick(const ['partner_name', 'partnerName']),
      periodStart:
          DateTime.tryParse(pick(const ['period_start'])) ?? now,
      periodEnd:
          DateTime.tryParse(pick(const ['period_end'])) ?? now,
      status: PartnerSettlementStatus.fromValue(pick(const ['status'])),
      totalDatorat: parseDouble(map['total_datorat'] ?? 0),
      totalIncasat: parseDouble(map['total_incasat'] ?? 0),
      restDeIncasat: parseDouble(map['rest_de_incasat'] ?? 0),
      totalDePlata: parseDouble(map['total_de_plata'] ?? 0),
      soldNet: parseDouble(map['sold_net'] ?? 0),
      adjustmentAmount: parseDouble(map['adjustment_amount'] ?? 0),
      adjustmentNote:
          (map['adjustment_note'] ?? '').toString(),
      lockedTransactionIds: lockedIds,
      closedBy: pick(const ['closed_by']),
      closedByName: pick(const ['closed_by_name']),
      closedAt: DateTime.tryParse(pick(const ['closed_at'])),
      notes: pick(const ['notes']),
      createdAt: DateTime.tryParse(pick(const ['created_at'])) ?? now,
      updatedAt: DateTime.tryParse(pick(const ['updated_at'])) ?? now,
    );
  }
}
