/// Tarife unificate per calificare, negociate per-asociere (nu globale) —
/// folosite pentru calculul automat al costului de manoperă din
/// PontajAsociere (ore × tarifRonOra).
class TarifAsociereRecord {
  const TarifAsociereRecord({
    required this.id,
    required this.asociereId,
    required this.calificare,
    required this.tarifRonOra,
    this.tarifRonKm = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String asociereId;

  /// Text liber (enum extensibil la nivel de UI, nu impus strict în model —
  /// permite calificări noi fără migrare de schemă).
  final String calificare;
  final double tarifRonOra;

  /// Tarif pentru deplasări cu auto propriu (RON/km).
  final double tarifRonKm;

  final DateTime createdAt;
  final DateTime updatedAt;

  TarifAsociereRecord copyWith({
    String? calificare,
    double? tarifRonOra,
    double? tarifRonKm,
    DateTime? updatedAt,
  }) {
    return TarifAsociereRecord(
      id: id,
      asociereId: asociereId,
      calificare: calificare ?? this.calificare,
      tarifRonOra: tarifRonOra ?? this.tarifRonOra,
      tarifRonKm: tarifRonKm ?? this.tarifRonKm,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'asociere_id': asociereId,
      'calificare': calificare,
      'tarif_ron_ora': tarifRonOra,
      'tarif_ron_km': tarifRonKm,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TarifAsociereRecord.fromMap(Map<String, dynamic> map) {
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

    return TarifAsociereRecord(
      id: pick(const <String>['id']),
      asociereId: pick(const <String>['asociere_id', 'asociereId']),
      calificare: pick(const <String>['calificare']),
      tarifRonOra: parseDouble(map['tarif_ron_ora'] ?? map['tarifRonOra']),
      tarifRonKm: parseDouble(map['tarif_ron_km'] ?? map['tarifRonKm']),
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ?? now,
      updatedAt:
          DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? now,
    );
  }
}

/// Calificări predefinite (sugestii UI) — lista rămâne extensibilă, nu e
/// impusă ca enum strict pe model (vezi TarifAsociereRecord.calificare).
const List<String> asociereCalificariPredefinite = <String>[
  'manager_santier',
  'frigotehnist_fgaze',
  'instalator',
  'electrician',
  'necalificat',
];
