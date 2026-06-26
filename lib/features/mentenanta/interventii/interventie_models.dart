import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'fgas_gwp_catalog.dart';

// ── Tip intervenție ───────────────────────────────────────────────────────────

enum TipInterventie {
  igienizare,
  revizie,
  igienizareRevizie,
  alta;

  String get label {
    switch (this) {
      case TipInterventie.igienizare:
        return 'Igienizare';
      case TipInterventie.revizie:
        return 'Revizie tehnică';
      case TipInterventie.igienizareRevizie:
        return 'Igienizare + Revizie';
      case TipInterventie.alta:
        return 'Altă intervenție';
    }
  }

  String get storageValue {
    switch (this) {
      case TipInterventie.igienizare:
        return 'igienizare';
      case TipInterventie.revizie:
        return 'revizie';
      case TipInterventie.igienizareRevizie:
        return 'igienizare_revizie';
      case TipInterventie.alta:
        return 'alta';
    }
  }

  static TipInterventie fromValue(String? raw) {
    switch (raw) {
      case 'igienizare':
        return TipInterventie.igienizare;
      case 'revizie':
        return TipInterventie.revizie;
      case 'igienizare_revizie':
        return TipInterventie.igienizareRevizie;
      default:
        return TipInterventie.alta;
    }
  }
}

// ── Status echipament în intervenție ──────────────────────────────────────────

enum StatusEchipamentInterventie {
  efectuat,
  partial,
  amanat,
  deRemediat;

  String get label {
    switch (this) {
      case StatusEchipamentInterventie.efectuat:
        return 'Efectuat';
      case StatusEchipamentInterventie.partial:
        return 'Parțial';
      case StatusEchipamentInterventie.amanat:
        return 'Amânat';
      case StatusEchipamentInterventie.deRemediat:
        return 'De remediat';
    }
  }

  /// Culoare pentru chip-uri în UI și pentru status-ul colorat din PDF.
  Color get color {
    switch (this) {
      case StatusEchipamentInterventie.efectuat:
        return Colors.green;
      case StatusEchipamentInterventie.partial:
        return Colors.orange;
      case StatusEchipamentInterventie.amanat:
        return Colors.grey;
      case StatusEchipamentInterventie.deRemediat:
        return Colors.red;
    }
  }

  String get storageValue {
    switch (this) {
      case StatusEchipamentInterventie.efectuat:
        return 'efectuat';
      case StatusEchipamentInterventie.partial:
        return 'partial';
      case StatusEchipamentInterventie.amanat:
        return 'amanat';
      case StatusEchipamentInterventie.deRemediat:
        return 'de_remediat';
    }
  }

  static StatusEchipamentInterventie fromValue(String? raw) {
    switch (raw) {
      case 'partial':
        return StatusEchipamentInterventie.partial;
      case 'amanat':
        return StatusEchipamentInterventie.amanat;
      case 'de_remediat':
        return StatusEchipamentInterventie.deRemediat;
      default:
        return StatusEchipamentInterventie.efectuat;
    }
  }
}

// ── Echipament lucrat într-o intervenție (snapshot) ───────────────────────────

class EchipamentInterventie {
  const EchipamentInterventie({
    required this.echipamentId,
    this.denumire = '',
    this.model = '',
    this.status = StatusEchipamentInterventie.efectuat,
    this.observatii = '',
    this.agentFrigorific = '',
    this.gwp = 0,
    this.cantitateAdaugata = 0,
    this.cantitateRecuperata = 0,
    this.necesitaLogFGas = false,
  });

  final String echipamentId;
  final String denumire;
  final String model;
  final StatusEchipamentInterventie status;
  final String observatii;
  final String agentFrigorific;

  /// GWP-ul agentului frigorific — auto-completat din [FGasGwpCatalog] la
  /// selectarea agentului (kg CO₂ echiv. per kg agent).
  final int gwp;
  final double cantitateAdaugata;
  final double cantitateRecuperata;

  /// Copiat din [EchipamentMentenanta.necesitaLogFGas] la momentul intervenției
  /// — controlează afișarea câmpurilor F-Gas și includerea în Log F-Gas.
  final bool necesitaLogFGas;

  /// Tone CO₂ echivalent pentru cantitatea netă adăugată în sistem.
  double get toneCO2 => FGasGwpCatalog.calcToneCO2(
        cantitateAdaugata: cantitateAdaugata,
        cantitateRecuperata: cantitateRecuperata,
        gwp: gwp,
      );

  /// Cantitatea netă rămasă în sistem (adăugat − recuperat, ≥ 0).
  double get cantitateNeta =>
      (cantitateAdaugata - cantitateRecuperata).clamp(0.0, double.infinity);

  /// True dacă echipamentul singur depășește pragul de raportare (5 t CO₂ eq.).
  bool get depasesteFragRaportare =>
      toneCO2 >= FGasGwpCatalog.pragRaportareTone;

  EchipamentInterventie copyWith({
    String? echipamentId,
    String? denumire,
    String? model,
    StatusEchipamentInterventie? status,
    String? observatii,
    String? agentFrigorific,
    int? gwp,
    double? cantitateAdaugata,
    double? cantitateRecuperata,
    bool? necesitaLogFGas,
  }) {
    return EchipamentInterventie(
      echipamentId: echipamentId ?? this.echipamentId,
      denumire: denumire ?? this.denumire,
      model: model ?? this.model,
      status: status ?? this.status,
      observatii: observatii ?? this.observatii,
      agentFrigorific: agentFrigorific ?? this.agentFrigorific,
      gwp: gwp ?? this.gwp,
      cantitateAdaugata: cantitateAdaugata ?? this.cantitateAdaugata,
      cantitateRecuperata: cantitateRecuperata ?? this.cantitateRecuperata,
      necesitaLogFGas: necesitaLogFGas ?? this.necesitaLogFGas,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'echipament_id': echipamentId,
      'denumire': denumire,
      'model': model,
      'status': status.storageValue,
      'observatii': observatii,
      'agent_frigorific': agentFrigorific,
      'gwp': gwp,
      'cantitate_adaugata': cantitateAdaugata,
      'cantitate_recuperata': cantitateRecuperata,
      'necesita_log_fgas': necesitaLogFGas,
    };
  }

  factory EchipamentInterventie.fromMap(Map<String, dynamic> map) {
    return EchipamentInterventie(
      echipamentId: (map['echipament_id'] ?? '').toString(),
      denumire: (map['denumire'] ?? '').toString(),
      model: (map['model'] ?? '').toString(),
      status: StatusEchipamentInterventie.fromValue(map['status']?.toString()),
      observatii: (map['observatii'] ?? '').toString(),
      agentFrigorific: (map['agent_frigorific'] ?? '').toString(),
      gwp: _toInt(map['gwp']),
      cantitateAdaugata: _toDouble(map['cantitate_adaugata']),
      cantitateRecuperata: _toDouble(map['cantitate_recuperata']),
      necesitaLogFGas: map['necesita_log_fgas'] == true,
    );
  }
}

// ── Intervenție service ───────────────────────────────────────────────────────

class InterventieService {
  const InterventieService({
    required this.id,
    required this.contractId,
    this.numar = '',
    required this.dataInterventie,
    this.tehnician = '',
    this.echipa = '',
    this.tipInterventie = TipInterventie.igienizareRevizie,
    this.echipamenteLucrate = const <EchipamentInterventie>[],
    this.observatii = '',
    this.pvGenerat = false,
    this.pvPath = '',
    this.logFGasGenerat = false,
    this.logFGasPath = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String contractId;
  final String numar;
  final DateTime dataInterventie;
  final String tehnician;
  final String echipa;
  final TipInterventie tipInterventie;
  final List<EchipamentInterventie> echipamenteLucrate;
  final String observatii;
  final bool pvGenerat;
  final String pvPath;
  final bool logFGasGenerat;
  final String logFGasPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// True dacă intervenția necesită un Log F-Gas: cel puțin un echipament marcat
  /// F-Gas ȘI cu operație efectivă de agent (adăugat sau recuperat > 0).
  /// Controlează vizibilitatea butonului „F-Gas PDF".
  bool get necesitaLogFGas => echipamenteLucrate.any((e) =>
      e.necesitaLogFGas &&
      (e.cantitateAdaugata > 0 || e.cantitateRecuperata > 0));

  /// Echipamentele care intră efectiv în Log F-Gas.
  List<EchipamentInterventie> get echipamenteFGas => echipamenteLucrate
      .where((e) =>
          e.necesitaLogFGas &&
          (e.cantitateAdaugata > 0 || e.cantitateRecuperata > 0))
      .toList(growable: false);

  /// Total tone CO₂ echivalent pe toată intervenția.
  double get totalToneCO2 =>
      echipamenteLucrate.fold<double>(0, (sum, e) => sum + e.toneCO2);

  InterventieService copyWith({
    String? id,
    String? contractId,
    String? numar,
    DateTime? dataInterventie,
    String? tehnician,
    String? echipa,
    TipInterventie? tipInterventie,
    List<EchipamentInterventie>? echipamenteLucrate,
    String? observatii,
    bool? pvGenerat,
    String? pvPath,
    bool? logFGasGenerat,
    String? logFGasPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InterventieService(
      id: id ?? this.id,
      contractId: contractId ?? this.contractId,
      numar: numar ?? this.numar,
      dataInterventie: dataInterventie ?? this.dataInterventie,
      tehnician: tehnician ?? this.tehnician,
      echipa: echipa ?? this.echipa,
      tipInterventie: tipInterventie ?? this.tipInterventie,
      echipamenteLucrate: echipamenteLucrate ?? this.echipamenteLucrate,
      observatii: observatii ?? this.observatii,
      pvGenerat: pvGenerat ?? this.pvGenerat,
      pvPath: pvPath ?? this.pvPath,
      logFGasGenerat: logFGasGenerat ?? this.logFGasGenerat,
      logFGasPath: logFGasPath ?? this.logFGasPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'contract_id': contractId,
      'numar': numar,
      'data_interventie': dataInterventie.toIso8601String(),
      'tehnician': tehnician,
      'echipa': echipa,
      'tip_interventie': tipInterventie.storageValue,
      'echipamente_lucrate':
          echipamenteLucrate.map((e) => e.toMap()).toList(growable: false),
      'observatii': observatii,
      'pv_generat': pvGenerat,
      'pv_path': pvPath,
      'log_fgas_generat': logFGasGenerat,
      'log_fgas_path': logFGasPath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory InterventieService.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    final rawEchip = map['echipamente_lucrate'];
    final echipamente = <EchipamentInterventie>[];
    if (rawEchip is List) {
      for (final e in rawEchip) {
        if (e is Map) {
          echipamente.add(
              EchipamentInterventie.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }
    return InterventieService(
      id: (map['id'] ?? const Uuid().v4()).toString(),
      contractId: (map['contract_id'] ?? '').toString(),
      numar: (map['numar'] ?? '').toString(),
      dataInterventie: _toDate(map['data_interventie']) ?? now,
      tehnician: (map['tehnician'] ?? '').toString(),
      echipa: (map['echipa'] ?? '').toString(),
      tipInterventie:
          TipInterventie.fromValue(map['tip_interventie']?.toString()),
      echipamenteLucrate: echipamente,
      observatii: (map['observatii'] ?? '').toString(),
      pvGenerat: map['pv_generat'] == true,
      pvPath: (map['pv_path'] ?? '').toString(),
      logFGasGenerat: map['log_fgas_generat'] == true,
      logFGasPath: (map['log_fgas_path'] ?? '').toString(),
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
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
  }
  return fallback;
}

DateTime? _toDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
