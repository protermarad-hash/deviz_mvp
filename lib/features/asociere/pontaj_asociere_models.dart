enum AsociereAngajator {
  proTerm,
  partener;

  String get value => this == AsociereAngajator.proTerm ? 'pro_term' : 'partener';

  String get label =>
      this == AsociereAngajator.proTerm ? 'PRO TERM' : 'Partener';

  static AsociereAngajator fromValue(String? raw) {
    return (raw ?? '').trim().toLowerCase() == 'partener'
        ? AsociereAngajator.partener
        : AsociereAngajator.proTerm;
  }
}

/// Pontaj pe o Asociere — cost manoperă NU se introduce manual, se
/// calculează (ore × tarif din TarifAsociere după `calificare`), DOAR pentru
/// pontaje cu ambele confirmări = true (vezi `esteConfirmatIntegral`).
///
/// Decizie confirmată: data de RECUNOAȘTERE a costului (pentru încadrarea
/// într-un decont lunar) e `dataConfirmare`, NU `data` lucrată — un pontaj
/// confirmat cu întârziere intră automat în decontul lunii în care a fost
/// confirmat, nu al lunii în care a fost lucrat.
class PontajAsociereRecord {
  const PontajAsociereRecord({
    required this.id,
    required this.asociereId,
    required this.data,
    required this.lucratorNume,
    required this.angajator,
    required this.calificare,
    required this.ore,
    this.activitateZona = '',
    this.confirmatProTerm = false,
    this.confirmatPartener = false,
    this.dataConfirmare,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String asociereId;
  final DateTime data;
  final String lucratorNume;
  final AsociereAngajator angajator;

  /// Referință la TarifAsociereRecord.calificare (text liber, nu FK strict).
  final String calificare;
  final double ore;
  final String activitateZona;
  final bool confirmatProTerm;
  final bool confirmatPartener;
  final DateTime? dataConfirmare;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get esteConfirmatIntegral => confirmatProTerm && confirmatPartener;

  /// Data folosită pentru încadrarea într-un decont lunar — null dacă
  /// pontajul nu e încă confirmat de ambele părți (nu se recunoaște cost).
  DateTime? get dataRecunoastereCost =>
      esteConfirmatIntegral ? dataConfirmare : null;

  PontajAsociereRecord copyWith({
    DateTime? data,
    String? lucratorNume,
    AsociereAngajator? angajator,
    String? calificare,
    double? ore,
    String? activitateZona,
    bool? confirmatProTerm,
    bool? confirmatPartener,
    Object? dataConfirmare = _unset,
    DateTime? updatedAt,
  }) {
    return PontajAsociereRecord(
      id: id,
      asociereId: asociereId,
      data: data ?? this.data,
      lucratorNume: lucratorNume ?? this.lucratorNume,
      angajator: angajator ?? this.angajator,
      calificare: calificare ?? this.calificare,
      ore: ore ?? this.ore,
      activitateZona: activitateZona ?? this.activitateZona,
      confirmatProTerm: confirmatProTerm ?? this.confirmatProTerm,
      confirmatPartener: confirmatPartener ?? this.confirmatPartener,
      dataConfirmare: identical(dataConfirmare, _unset)
          ? this.dataConfirmare
          : dataConfirmare as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'asociere_id': asociereId,
      'data': data.toIso8601String(),
      'lucrator_nume': lucratorNume,
      'angajator': angajator.value,
      'calificare': calificare,
      'ore': ore,
      'activitate_zona': activitateZona,
      'confirmat_pro_term': confirmatProTerm,
      'confirmat_partener': confirmatPartener,
      'data_confirmare': dataConfirmare?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PontajAsociereRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
    }

    bool parseBool(dynamic raw) {
      if (raw is bool) return raw;
      final text = (raw ?? '').toString().trim().toLowerCase();
      return text == 'true' || text == '1';
    }

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return PontajAsociereRecord(
      id: pick(const <String>['id']),
      asociereId: pick(const <String>['asociere_id', 'asociereId']),
      data: DateTime.tryParse((map['data'] ?? '').toString()) ?? now,
      lucratorNume: pick(const <String>['lucrator_nume', 'lucratorNume']),
      angajator: AsociereAngajator.fromValue(map['angajator']?.toString()),
      calificare: pick(const <String>['calificare']),
      ore: parseDouble(map['ore']),
      activitateZona:
          pick(const <String>['activitate_zona', 'activitateZona']),
      confirmatProTerm:
          parseBool(map['confirmat_pro_term'] ?? map['confirmatProTerm']),
      confirmatPartener:
          parseBool(map['confirmat_partener'] ?? map['confirmatPartener']),
      dataConfirmare:
          DateTime.tryParse((map['data_confirmare'] ?? '').toString()),
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ?? now,
      updatedAt:
          DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? now,
    );
  }
}

const Object _unset = Object();
