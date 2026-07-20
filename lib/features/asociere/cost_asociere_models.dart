enum AsociereCostCategorie {
  material,
  manoperaCalculata,
  management,
  transport,
  altele;

  String get value {
    switch (this) {
      case AsociereCostCategorie.material:
        return 'material';
      case AsociereCostCategorie.manoperaCalculata:
        return 'manopera_calculata';
      case AsociereCostCategorie.management:
        return 'management';
      case AsociereCostCategorie.transport:
        return 'transport';
      case AsociereCostCategorie.altele:
        return 'altele';
    }
  }

  String get label {
    switch (this) {
      case AsociereCostCategorie.material:
        return 'Material';
      case AsociereCostCategorie.manoperaCalculata:
        return 'Manoperă (calculată)';
      case AsociereCostCategorie.management:
        return 'Management';
      case AsociereCostCategorie.transport:
        return 'Transport';
      case AsociereCostCategorie.altele:
        return 'Altele';
    }
  }

  static AsociereCostCategorie fromValue(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'manopera_calculata':
        return AsociereCostCategorie.manoperaCalculata;
      case 'management':
        return AsociereCostCategorie.management;
      case 'transport':
        return AsociereCostCategorie.transport;
      case 'altele':
        return AsociereCostCategorie.altele;
      case 'material':
      default:
        return AsociereCostCategorie.material;
    }
  }
}

enum AsociereParte {
  proTerm,
  partener;

  String get value => this == AsociereParte.proTerm ? 'pro_term' : 'partener';

  String get label => this == AsociereParte.proTerm ? 'PRO TERM' : 'Partener';

  static AsociereParte fromValue(String? raw) {
    return (raw ?? '').trim().toLowerCase() == 'partener'
        ? AsociereParte.partener
        : AsociereParte.proTerm;
  }
}

/// Cost pe o Asociere. `necesitaAprobare` se calculează la creare
/// (vezi `computeNecesitaAprobare`) din valoareFaraTva vs.
/// AsociereRecord.pragAprobareRON — NU e recalculat retroactiv dacă pragul
/// se schimbă ulterior pe asociere.
///
/// Decizie confirmată: un cost care necesită aprobare și nu o are încă NU
/// intră în decontul lunii curente — se recunoaște automat în luna în care
/// `dataAprobare` cade (vezi `dataRecunoastereCost`), nu în luna lui `data`.
class CostAsociereRecord {
  const CostAsociereRecord({
    required this.id,
    required this.asociereId,
    required this.categorie,
    required this.data,
    required this.descriere,
    required this.valoareFaraTva,
    required this.asociatPlatitor,
    this.documentJustificativUrl,
    this.necesitaAprobare = false,
    this.aprobatProTerm = false,
    this.aprobatPartener = false,
    this.dataAprobare,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String asociereId;
  final AsociereCostCategorie categorie;
  final DateTime data;
  final String descriere;
  final double valoareFaraTva;

  /// Cine a plătit efectiv acest cost (nu cine îl "datorează" din cotă).
  final AsociereParte asociatPlatitor;

  /// Nullable, dar obligatoriu (validare UI/repository) pentru orice
  /// categorie diferită de manoperaCalculata.
  final String? documentJustificativUrl;
  final bool necesitaAprobare;
  final bool aprobatProTerm;
  final bool aprobatPartener;
  final DateTime? dataAprobare;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get esteAprobatIntegral => aprobatProTerm && aprobatPartener;

  /// Data folosită pentru încadrarea într-un decont lunar:
  /// - dacă nu necesită aprobare → `data` (recunoscut imediat)
  /// - dacă necesită aprobare → `dataAprobare` DOAR când ambele aprobări
  ///   există; altfel null (nerecunoscut încă, exclus din orice decont).
  DateTime? get dataRecunoastereCost {
    if (!necesitaAprobare) return data;
    return esteAprobatIntegral ? dataAprobare : null;
  }

  /// Regula de calcul a lui `necesitaAprobare` la creare — nu se
  /// recalculează retroactiv. Apelată din repository/UI cu pragul curent
  /// al asocierii (AsociereRecord.pragAprobareRON).
  static bool computeNecesitaAprobare(double valoareFaraTva, double pragRON) {
    return valoareFaraTva > pragRON;
  }

  CostAsociereRecord copyWith({
    AsociereCostCategorie? categorie,
    DateTime? data,
    String? descriere,
    double? valoareFaraTva,
    AsociereParte? asociatPlatitor,
    Object? documentJustificativUrl = _unset,
    bool? necesitaAprobare,
    bool? aprobatProTerm,
    bool? aprobatPartener,
    Object? dataAprobare = _unset,
    DateTime? updatedAt,
  }) {
    return CostAsociereRecord(
      id: id,
      asociereId: asociereId,
      categorie: categorie ?? this.categorie,
      data: data ?? this.data,
      descriere: descriere ?? this.descriere,
      valoareFaraTva: valoareFaraTva ?? this.valoareFaraTva,
      asociatPlatitor: asociatPlatitor ?? this.asociatPlatitor,
      documentJustificativUrl: identical(documentJustificativUrl, _unset)
          ? this.documentJustificativUrl
          : documentJustificativUrl as String?,
      necesitaAprobare: necesitaAprobare ?? this.necesitaAprobare,
      aprobatProTerm: aprobatProTerm ?? this.aprobatProTerm,
      aprobatPartener: aprobatPartener ?? this.aprobatPartener,
      dataAprobare: identical(dataAprobare, _unset)
          ? this.dataAprobare
          : dataAprobare as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'asociere_id': asociereId,
      'categorie': categorie.value,
      'data': data.toIso8601String(),
      'descriere': descriere,
      'valoare_fara_tva': valoareFaraTva,
      'asociat_platitor': asociatPlatitor.value,
      'document_justificativ_url': documentJustificativUrl,
      'necesita_aprobare': necesitaAprobare,
      'aprobat_pro_term': aprobatProTerm,
      'aprobat_partener': aprobatPartener,
      'data_aprobare': dataAprobare?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CostAsociereRecord.fromMap(Map<String, dynamic> map) {
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

    final docUrl =
        pick(const <String>['document_justificativ_url', 'documentJustificativUrl']);

    return CostAsociereRecord(
      id: pick(const <String>['id']),
      asociereId: pick(const <String>['asociere_id', 'asociereId']),
      categorie: AsociereCostCategorie.fromValue(map['categorie']?.toString()),
      data: DateTime.tryParse((map['data'] ?? '').toString()) ?? now,
      descriere: pick(const <String>['descriere']),
      valoareFaraTva:
          parseDouble(map['valoare_fara_tva'] ?? map['valoareFaraTva']),
      asociatPlatitor:
          AsociereParte.fromValue(map['asociat_platitor']?.toString()),
      documentJustificativUrl: docUrl.isEmpty ? null : docUrl,
      necesitaAprobare:
          parseBool(map['necesita_aprobare'] ?? map['necesitaAprobare']),
      aprobatProTerm:
          parseBool(map['aprobat_pro_term'] ?? map['aprobatProTerm']),
      aprobatPartener:
          parseBool(map['aprobat_partener'] ?? map['aprobatPartener']),
      dataAprobare:
          DateTime.tryParse((map['data_aprobare'] ?? '').toString()),
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ?? now,
      updatedAt:
          DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? now,
    );
  }
}

const Object _unset = Object();
