/// Modele pentru pontajul zilnic pe lucrări (iul 2026).
///
/// Evidență de sine stătătoare — NU se leagă de calculele economice
/// existente ale lucrării și NU atinge modulul Financiar parteneri.
/// Catalogul partner_workers se folosește STRICT read-only ca sursă
/// de nume pentru autosearch.
library;

/// Sursa persoanei pontate.
enum SursaPersoanaPontaj {
  /// Angajat propriu (MasterEmployee).
  propriu,

  /// Muncitor al unui partener (PartnerWorkerRecord — read-only).
  partener,

  /// Nume liber, persoană neînregistrată în cataloage.
  liber;

  String get value {
    switch (this) {
      case SursaPersoanaPontaj.propriu:
        return 'propriu';
      case SursaPersoanaPontaj.partener:
        return 'partener';
      case SursaPersoanaPontaj.liber:
        return 'liber';
    }
  }

  String get label {
    switch (this) {
      case SursaPersoanaPontaj.propriu:
        return 'Propriu';
      case SursaPersoanaPontaj.partener:
        return 'Partener';
      case SursaPersoanaPontaj.liber:
        return 'Liber';
    }
  }

  static SursaPersoanaPontaj fromValue(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'partener':
        return SursaPersoanaPontaj.partener;
      case 'liber':
        return SursaPersoanaPontaj.liber;
      default:
        return SursaPersoanaPontaj.propriu;
    }
  }
}

/// O zi de pontaj pentru o persoană pe o lucrare.
///
/// Valorile de tarif/diurnă/cazare sunt SNAPSHOT-uri fixate la salvare —
/// modificarea ulterioară a cataloagelor NU rescrie pontajele existente.
class PontajZiLucrare {
  const PontajZiLucrare({
    required this.id,
    required this.lucrareId,
    required this.data,
    required this.persoanaNume,
    required this.sursaPersoana,
    this.persoanaRefId,
    this.partenerNume,
    this.tarifZilnicSnapshot = 0.0,
    this.diurnaSnapshot = 0.0,
    this.cazareSnapshot = 0.0,
    this.includeDiurna = false,
    this.includeCazare = false,
    this.observatii = '',
    this.revision = 1,
    this.createdBy = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// JobRecord.id al lucrării.
  final String lucrareId;

  /// Ziua calendaristică pontată (ora se ignoră — se normalizează la 00:00).
  final DateTime data;

  final String persoanaNume;
  final SursaPersoanaPontaj sursaPersoana;

  /// Id din MasterEmployee sau PartnerWorkerRecord dacă persoana a fost
  /// selectată din catalog; null la nume liber.
  final String? persoanaRefId;

  /// Numele partenerului — doar pentru sursaPersoana=partener.
  final String? partenerNume;

  // Snapshot-uri fixate la salvare (nu se recalculează din cataloage).
  final double tarifZilnicSnapshot;
  final double diurnaSnapshot;
  final double cazareSnapshot;

  final bool includeDiurna;
  final bool includeCazare;

  final String observatii;

  // Audit standard.
  final int revision;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Costul zilei = tarif + diurnă (dacă inclusă) + cazare (dacă inclusă).
  double get costZi =>
      tarifZilnicSnapshot +
      (includeDiurna ? diurnaSnapshot : 0) +
      (includeCazare ? cazareSnapshot : 0);

  /// Zi calendaristică normalizată (fără oră) — cheie de grupare.
  DateTime get ziCalendaristica => DateTime(data.year, data.month, data.day);

  PontajZiLucrare copyWith({
    String? id,
    String? lucrareId,
    DateTime? data,
    String? persoanaNume,
    SursaPersoanaPontaj? sursaPersoana,
    String? persoanaRefId,
    String? partenerNume,
    double? tarifZilnicSnapshot,
    double? diurnaSnapshot,
    double? cazareSnapshot,
    bool? includeDiurna,
    bool? includeCazare,
    String? observatii,
    int? revision,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PontajZiLucrare(
      id: id ?? this.id,
      lucrareId: lucrareId ?? this.lucrareId,
      data: data ?? this.data,
      persoanaNume: persoanaNume ?? this.persoanaNume,
      sursaPersoana: sursaPersoana ?? this.sursaPersoana,
      persoanaRefId: persoanaRefId ?? this.persoanaRefId,
      partenerNume: partenerNume ?? this.partenerNume,
      tarifZilnicSnapshot: tarifZilnicSnapshot ?? this.tarifZilnicSnapshot,
      diurnaSnapshot: diurnaSnapshot ?? this.diurnaSnapshot,
      cazareSnapshot: cazareSnapshot ?? this.cazareSnapshot,
      includeDiurna: includeDiurna ?? this.includeDiurna,
      includeCazare: includeCazare ?? this.includeCazare,
      observatii: observatii ?? this.observatii,
      revision: revision ?? this.revision,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'lucrare_id': lucrareId,
      'data': ziCalendaristica.toIso8601String(),
      'persoana_nume': persoanaNume,
      'sursa_persoana': sursaPersoana.value,
      'persoana_ref_id': persoanaRefId,
      'partener_nume': partenerNume,
      'tarif_zilnic_snapshot': tarifZilnicSnapshot,
      'diurna_snapshot': diurnaSnapshot,
      'cazare_snapshot': cazareSnapshot,
      'include_diurna': includeDiurna,
      'include_cazare': includeCazare,
      'observatii': observatii,
      'revision': revision,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PontajZiLucrare.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse((raw ?? '0').toString().replaceAll(',', '.')) ??
          0.0;
    }

    bool parseBool(dynamic raw) {
      if (raw is bool) return raw;
      final text = (raw ?? '').toString().trim().toLowerCase();
      return text == 'true' || text == '1' || text == 'da';
    }

    String? parseNullableString(dynamic raw) {
      final text = (raw ?? '').toString().trim();
      return text.isEmpty ? null : text;
    }

    return PontajZiLucrare(
      id: (map['id'] ?? '').toString().trim(),
      lucrareId:
          (map['lucrare_id'] ?? map['lucrareId'] ?? '').toString().trim(),
      data: DateTime.tryParse((map['data'] ?? '').toString()) ?? now,
      persoanaNume:
          (map['persoana_nume'] ?? map['persoanaNume'] ?? '').toString().trim(),
      sursaPersoana: SursaPersoanaPontaj.fromValue(
        (map['sursa_persoana'] ?? map['sursaPersoana'])?.toString(),
      ),
      persoanaRefId:
          parseNullableString(map['persoana_ref_id'] ?? map['persoanaRefId']),
      partenerNume:
          parseNullableString(map['partener_nume'] ?? map['partenerNume']),
      tarifZilnicSnapshot: parseDouble(
        map['tarif_zilnic_snapshot'] ?? map['tarifZilnicSnapshot'],
      ),
      diurnaSnapshot:
          parseDouble(map['diurna_snapshot'] ?? map['diurnaSnapshot']),
      cazareSnapshot:
          parseDouble(map['cazare_snapshot'] ?? map['cazareSnapshot']),
      includeDiurna:
          parseBool(map['include_diurna'] ?? map['includeDiurna']),
      includeCazare:
          parseBool(map['include_cazare'] ?? map['includeCazare']),
      observatii: (map['observatii'] ?? '').toString().trim(),
      revision: (map['revision'] as num?)?.toInt() ?? 1,
      createdBy: (map['created_by'] ?? map['createdBy'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ?? now,
      updatedAt:
          DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? now,
    );
  }
}
