import 'asociere_operational_common.dart';

class TarifAsociereRecord {
  const TarifAsociereRecord({
    required this.id,
    required this.projectId,
    this.contractId = '',
    required this.calificare,
    required this.tarifOra,
    this.tarifKm = 0,
    this.moneda = 'RON',
    this.unitate = 'ora',
    this.asociat = AsociereParte.proTerm,
    required this.valabilDeLa,
    this.valabilPanaLa,
    this.activ = true,
    this.observatii = '',
    required this.createdAt,
    required this.updatedAt,
    this.revision = 1,
  });

  final String id;
  final String projectId;
  final String contractId;
  final String calificare;
  final double tarifOra;
  final double tarifKm;
  final String moneda;
  final String unitate;
  final AsociereParte asociat;
  final DateTime valabilDeLa;
  final DateTime? valabilPanaLa;
  final bool activ;
  final String observatii;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;

  double get tarifRonOra => tarifOra;
  double get tarifRonKm => tarifKm;

  bool esteValabilLa(DateTime data) {
    final start =
        DateTime(valabilDeLa.year, valabilDeLa.month, valabilDeLa.day);
    final target = DateTime(data.year, data.month, data.day);
    final end = valabilPanaLa == null
        ? null
        : DateTime(
            valabilPanaLa!.year, valabilPanaLa!.month, valabilPanaLa!.day);
    return activ &&
        !target.isBefore(start) &&
        (end == null || !target.isAfter(end));
  }

  List<String> validate() {
    final errors = <String>[];
    if (id.isEmpty || projectId.isEmpty) {
      errors.add('Proiectul este obligatoriu.');
    }
    if (calificare.isEmpty) errors.add('Calificarea este obligatorie.');
    if (!tarifOra.isFinite ||
        tarifOra < 0 ||
        !tarifKm.isFinite ||
        tarifKm < 0) {
      errors.add('Tarifele trebuie să fie finite și nenegative.');
    }
    if (valabilPanaLa != null && valabilPanaLa!.isBefore(valabilDeLa)) {
      errors.add('Perioada de valabilitate este invalidă.');
    }
    return errors;
  }

  TarifAsociereRecord copyWith({
    double? tarifOra,
    double? tarifKm,
    String? moneda,
    String? unitate,
    AsociereParte? asociat,
    DateTime? valabilDeLa,
    Object? valabilPanaLa = _unset,
    bool? activ,
    String? observatii,
    DateTime? updatedAt,
    int? revision,
  }) =>
      TarifAsociereRecord(
        id: id,
        projectId: projectId,
        contractId: contractId,
        calificare: calificare,
        tarifOra: tarifOra ?? this.tarifOra,
        tarifKm: tarifKm ?? this.tarifKm,
        moneda: moneda ?? this.moneda,
        unitate: unitate ?? this.unitate,
        asociat: asociat ?? this.asociat,
        valabilDeLa: valabilDeLa ?? this.valabilDeLa,
        valabilPanaLa: identical(valabilPanaLa, _unset)
            ? this.valabilPanaLa
            : valabilPanaLa as DateTime?,
        activ: activ ?? this.activ,
        observatii: observatii ?? this.observatii,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        revision: revision ?? this.revision,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'project_id': projectId,
        'contract_id': contractId,
        'calificare': calificare,
        'tarif_ora': tarifOra,
        'tarif_km': tarifKm,
        'moneda': moneda,
        'unitate': unitate,
        'asociat': asociat.value,
        'valabil_de_la': valabilDeLa.toIso8601String(),
        'valabil_pana_la': valabilPanaLa?.toIso8601String(),
        'activ': activ,
        'observatii': observatii,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'revision': revision,
      };

  factory TarifAsociereRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return TarifAsociereRecord(
      id: mapText(map, 'id'),
      projectId: mapText(map, 'project_id', 'projectId'),
      contractId: mapText(map, 'contract_id', 'contractId'),
      calificare: mapText(map, 'calificare'),
      tarifOra: mapDouble(map, 'tarif_ora', 'tarifOra'),
      tarifKm: mapDouble(map, 'tarif_km', 'tarifKm'),
      moneda: mapText(map, 'moneda').isEmpty ? 'RON' : mapText(map, 'moneda'),
      unitate:
          mapText(map, 'unitate').isEmpty ? 'ora' : mapText(map, 'unitate'),
      asociat: AsociereParteX.fromValue(map['asociat']),
      valabilDeLa: mapDate(map, 'valabil_de_la', 'valabilDeLa') ?? now,
      valabilPanaLa: mapDate(map, 'valabil_pana_la', 'valabilPanaLa'),
      activ: mapBool(map, 'activ', null, true),
      observatii: mapText(map, 'observatii'),
      createdAt: mapDate(map, 'created_at', 'createdAt') ?? now,
      updatedAt: mapDate(map, 'updated_at', 'updatedAt') ?? now,
      revision: mapInt(map, 'revision', null, 1),
    );
  }
}

const Object _unset = Object();

const asociereCalificariPredefinite = <String>[
  'manager_santier',
  'frigotehnist_fgaze',
  'instalator',
  'electrician',
  'necalificat',
];
