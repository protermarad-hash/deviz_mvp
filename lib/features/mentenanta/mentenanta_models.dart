import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

// ── Categorie echipament mentenanță ───────────────────────────────────────────
//
// Folosită pentru gruparea echipamentelor în tabelul PDF (header + subtotal
// per categorie). Fiecare valoare are un [label] pentru UI și un [storageValue]
// stabil pentru serializare (backward compatible).

enum CategorieMentenanta {
  vrfDaikin,
  splitDaikin,
  vrfMitsubishi,
  vrfAltele,
  splitAltele,
  ventilatie,
  altele;

  String get label {
    switch (this) {
      case CategorieMentenanta.vrfDaikin:
        return 'Sistem VRF Daikin';
      case CategorieMentenanta.splitDaikin:
        return 'Split Daikin';
      case CategorieMentenanta.vrfMitsubishi:
        return 'Sistem VRF Mitsubishi';
      case CategorieMentenanta.vrfAltele:
        return 'Sistem VRF (alte mărci)';
      case CategorieMentenanta.splitAltele:
        return 'Split (alte mărci)';
      case CategorieMentenanta.ventilatie:
        return 'Ventilație';
      case CategorieMentenanta.altele:
        return 'Altele';
    }
  }

  String get storageValue {
    switch (this) {
      case CategorieMentenanta.vrfDaikin:
        return 'vrf_daikin';
      case CategorieMentenanta.splitDaikin:
        return 'split_daikin';
      case CategorieMentenanta.vrfMitsubishi:
        return 'vrf_mitsubishi';
      case CategorieMentenanta.vrfAltele:
        return 'vrf_altele';
      case CategorieMentenanta.splitAltele:
        return 'split_altele';
      case CategorieMentenanta.ventilatie:
        return 'ventilatie';
      case CategorieMentenanta.altele:
        return 'altele';
    }
  }

  static CategorieMentenanta fromValue(String? raw) {
    switch (raw) {
      case 'vrf_daikin':
        return CategorieMentenanta.vrfDaikin;
      case 'split_daikin':
        return CategorieMentenanta.splitDaikin;
      case 'vrf_mitsubishi':
        return CategorieMentenanta.vrfMitsubishi;
      case 'vrf_altele':
        return CategorieMentenanta.vrfAltele;
      case 'split_altele':
        return CategorieMentenanta.splitAltele;
      case 'ventilatie':
        return CategorieMentenanta.ventilatie;
      default:
        return CategorieMentenanta.altele;
    }
  }
}

// ── Status contract mentenanță ────────────────────────────────────────────────

enum ContractMentenantaStatus {
  oferta,
  acceptata,
  activ,
  expirat,
  anulat;

  String get label {
    switch (this) {
      case ContractMentenantaStatus.oferta:
        return 'Ofertă';
      case ContractMentenantaStatus.acceptata:
        return 'Acceptată';
      case ContractMentenantaStatus.activ:
        return 'Activ';
      case ContractMentenantaStatus.expirat:
        return 'Expirat';
      case ContractMentenantaStatus.anulat:
        return 'Anulat';
    }
  }

  /// Culoarea de status pentru chip-uri și borduri în UI.
  Color get color {
    switch (this) {
      case ContractMentenantaStatus.oferta:
        return Colors.orange;
      case ContractMentenantaStatus.acceptata:
        return Colors.blue;
      case ContractMentenantaStatus.activ:
        return Colors.green;
      case ContractMentenantaStatus.expirat:
        return Colors.red;
      case ContractMentenantaStatus.anulat:
        return Colors.grey;
    }
  }

  String get storageValue {
    switch (this) {
      case ContractMentenantaStatus.oferta:
        return 'oferta';
      case ContractMentenantaStatus.acceptata:
        return 'acceptata';
      case ContractMentenantaStatus.activ:
        return 'activ';
      case ContractMentenantaStatus.expirat:
        return 'expirat';
      case ContractMentenantaStatus.anulat:
        return 'anulat';
    }
  }

  static ContractMentenantaStatus fromValue(String? raw) {
    switch (raw) {
      case 'acceptata':
        return ContractMentenantaStatus.acceptata;
      case 'activ':
        return ContractMentenantaStatus.activ;
      case 'expirat':
        return ContractMentenantaStatus.expirat;
      case 'anulat':
        return ContractMentenantaStatus.anulat;
      default:
        return ContractMentenantaStatus.oferta;
    }
  }
}

// ── Echipament mentenanță ─────────────────────────────────────────────────────

class EchipamentMentenanta {
  const EchipamentMentenanta({
    required this.id,
    this.nrCrt = 0,
    this.tipEchipament = '',
    this.model = '',
    this.um = 'buc',
    this.cantitate = 1,
    this.pretIgienizare = 0,
    this.pretRevizie = 0,
    this.observatii = '',
    this.categorie = CategorieMentenanta.altele,
    this.necesitaLogFGas = false,
  });

  final String id;
  final int nrCrt;
  final String tipEchipament;
  final String model;
  final String um;
  final double cantitate;
  final double pretIgienizare;
  final double pretRevizie;
  final String observatii;
  final CategorieMentenanta categorie;
  final bool necesitaLogFGas;

  /// Preț unitar total (igienizare + revizie tehnică).
  double get pretTotal => pretIgienizare + pretRevizie;

  /// Valoare totală pe linie (preț unitar total × cantitate).
  double get valoareTotala => pretTotal * cantitate;

  EchipamentMentenanta copyWith({
    String? id,
    int? nrCrt,
    String? tipEchipament,
    String? model,
    String? um,
    double? cantitate,
    double? pretIgienizare,
    double? pretRevizie,
    String? observatii,
    CategorieMentenanta? categorie,
    bool? necesitaLogFGas,
  }) {
    return EchipamentMentenanta(
      id: id ?? this.id,
      nrCrt: nrCrt ?? this.nrCrt,
      tipEchipament: tipEchipament ?? this.tipEchipament,
      model: model ?? this.model,
      um: um ?? this.um,
      cantitate: cantitate ?? this.cantitate,
      pretIgienizare: pretIgienizare ?? this.pretIgienizare,
      pretRevizie: pretRevizie ?? this.pretRevizie,
      observatii: observatii ?? this.observatii,
      categorie: categorie ?? this.categorie,
      necesitaLogFGas: necesitaLogFGas ?? this.necesitaLogFGas,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nr_crt': nrCrt,
      'tip_echipament': tipEchipament,
      'model': model,
      'um': um,
      'cantitate': cantitate,
      'pret_igienizare': pretIgienizare,
      'pret_revizie': pretRevizie,
      'observatii': observatii,
      'categorie': categorie.storageValue,
      'necesita_log_fgas': necesitaLogFGas,
    };
  }

  factory EchipamentMentenanta.fromMap(Map<String, dynamic> map) {
    return EchipamentMentenanta(
      id: (map['id'] ?? const Uuid().v4()).toString(),
      nrCrt: _toInt(map['nr_crt']),
      tipEchipament: (map['tip_echipament'] ?? '').toString(),
      model: (map['model'] ?? '').toString(),
      um: (map['um'] ?? 'buc').toString(),
      cantitate: _toDouble(map['cantitate'], fallback: 1),
      pretIgienizare: _toDouble(map['pret_igienizare']),
      pretRevizie: _toDouble(map['pret_revizie']),
      observatii: (map['observatii'] ?? '').toString(),
      categorie: CategorieMentenanta.fromValue(map['categorie']?.toString()),
      necesitaLogFGas: map['necesita_log_fgas'] == true,
    );
  }
}

// ── Contract mentenanță ───────────────────────────────────────────────────────

class ContractMentenanta {
  const ContractMentenanta({
    required this.id,
    this.numar = '',
    this.clientId = '',
    this.clientName = '',
    this.titlu = '',
    required this.dataStart,
    required this.dataEnd,
    this.status = ContractMentenantaStatus.oferta,
    this.echipamente = const <EchipamentMentenanta>[],
    this.interventiiPlanificate = 1,
    this.observatii = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String numar;
  final String clientId;
  final String clientName;
  final String titlu;
  final DateTime dataStart;
  final DateTime dataEnd;
  final ContractMentenantaStatus status;
  final List<EchipamentMentenanta> echipamente;
  final int interventiiPlanificate;
  final String observatii;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Cota TVA aplicată (21% — implicit firmă, conform CompanyProfile).
  static const double cotaTva = 0.21;

  /// Total fără TVA = suma valorilor totale ale echipamentelor.
  double get totalFaraTVA =>
      echipamente.fold<double>(0, (sum, e) => sum + e.valoareTotala);

  /// Valoarea TVA-ului (21%).
  double get tva => totalFaraTVA * cotaTva;

  /// Total cu TVA inclus.
  double get totalCuTVA => totalFaraTVA + tva;

  /// Echipamentele grupate pe categorie — pentru tabelul PDF (header + subtotal).
  /// Păstrează ordinea declarată în [CategorieMentenanta].
  Map<CategorieMentenanta, List<EchipamentMentenanta>> get echipamenteGrupate {
    final result = <CategorieMentenanta, List<EchipamentMentenanta>>{};
    for (final cat in CategorieMentenanta.values) {
      final items =
          echipamente.where((e) => e.categorie == cat).toList(growable: false);
      if (items.isNotEmpty) {
        result[cat] = items;
      }
    }
    return result;
  }

  ContractMentenanta copyWith({
    String? id,
    String? numar,
    String? clientId,
    String? clientName,
    String? titlu,
    DateTime? dataStart,
    DateTime? dataEnd,
    ContractMentenantaStatus? status,
    List<EchipamentMentenanta>? echipamente,
    int? interventiiPlanificate,
    String? observatii,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContractMentenanta(
      id: id ?? this.id,
      numar: numar ?? this.numar,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      titlu: titlu ?? this.titlu,
      dataStart: dataStart ?? this.dataStart,
      dataEnd: dataEnd ?? this.dataEnd,
      status: status ?? this.status,
      echipamente: echipamente ?? this.echipamente,
      interventiiPlanificate:
          interventiiPlanificate ?? this.interventiiPlanificate,
      observatii: observatii ?? this.observatii,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'numar': numar,
      'client_id': clientId,
      'client_name': clientName,
      'titlu': titlu,
      'data_start': dataStart.toIso8601String(),
      'data_end': dataEnd.toIso8601String(),
      'status': status.storageValue,
      'echipamente': echipamente.map((e) => e.toMap()).toList(growable: false),
      'interventii_planificate': interventiiPlanificate,
      'observatii': observatii,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ContractMentenanta.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    final rawEchip = map['echipamente'];
    final echipamente = <EchipamentMentenanta>[];
    if (rawEchip is List) {
      for (final e in rawEchip) {
        if (e is Map) {
          echipamente
              .add(EchipamentMentenanta.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }
    return ContractMentenanta(
      id: (map['id'] ?? const Uuid().v4()).toString(),
      numar: (map['numar'] ?? '').toString(),
      clientId: (map['client_id'] ?? '').toString(),
      clientName: (map['client_name'] ?? '').toString(),
      titlu: (map['titlu'] ?? '').toString(),
      dataStart: _toDate(map['data_start']) ?? now,
      dataEnd: _toDate(map['data_end']) ??
          DateTime(now.year + 1, now.month, now.day),
      status: ContractMentenantaStatus.fromValue(map['status']?.toString()),
      echipamente: echipamente,
      interventiiPlanificate: _toInt(map['interventii_planificate'],
          fallback: 1),
      observatii: (map['observatii'] ?? '').toString(),
      createdAt: _toDate(map['created_at']) ?? now,
      updatedAt: _toDate(map['updated_at']) ?? now,
    );
  }
}

// ── Helpers de parsare ────────────────────────────────────────────────────────

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

DateTime? _toDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
