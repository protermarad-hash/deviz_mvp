import 'asociere_operational_common.dart';

enum DeplasareCalcul { tarifKm, combustibil, documentat, sumaFixa }

class DeplasareAsociereRecord {
  const DeplasareAsociereRecord({
    required this.id,
    required this.projectId,
    required this.dataPlecare,
    required this.dataRevenire,
    required this.punctPlecare,
    required this.destinatie,
    this.tara = 'România',
    this.tipDeplasare = 'rutiera',
    this.asociat = AsociereParte.proTerm,
    this.persoane = const [],
    this.vehicleId = '',
    this.vehicleSnapshot = '',
    this.tipTransport = 'auto',
    this.metodaCalcul = DeplasareCalcul.tarifKm,
    this.kilometriEstimati = 0,
    this.kilometriReali = 0,
    this.tarifKmSnapshot = 0,
    this.consum = 0,
    this.pretCombustibil = 0,
    this.taxeDrum = 0,
    this.parcari = 0,
    this.bilete = 0,
    this.alteCosturi = 0,
    this.costEstimat = 0,
    this.costReal = 0,
    this.platitor = AsociereParte.proTerm,
    this.refacturabil = false,
    this.eligibil = true,
    this.documentRef = '',
    this.status = AsociereOperationalStatus.draft,
    this.observatii = '',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
    this.revision = 1,
  });

  final String id;
  final String projectId;
  final DateTime dataPlecare;
  final DateTime dataRevenire;
  final String punctPlecare;
  final String destinatie;
  final String tara;
  final String tipDeplasare;
  final AsociereParte asociat;
  final List<String> persoane;
  final String vehicleId;
  final String vehicleSnapshot;
  final String tipTransport;
  final DeplasareCalcul metodaCalcul;
  final double kilometriEstimati;
  final double kilometriReali;
  final double tarifKmSnapshot;
  final double consum;
  final double pretCombustibil;
  final double taxeDrum;
  final double parcari;
  final double bilete;
  final double alteCosturi;
  final double costEstimat;
  final double costReal;
  final AsociereParte platitor;
  final bool refacturabil;
  final bool eligibil;
  final String documentRef;
  final AsociereOperationalStatus status;
  final String observatii;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final int revision;

  double calculeazaTransport({bool real = true}) {
    final km = real && kilometriReali > 0 ? kilometriReali : kilometriEstimati;
    final transport = switch (metodaCalcul) {
      DeplasareCalcul.tarifKm => km * tarifKmSnapshot,
      DeplasareCalcul.combustibil => km / 100 * consum * pretCombustibil,
      DeplasareCalcul.documentat ||
      DeplasareCalcul.sumaFixa =>
        real ? costReal : costEstimat,
    };
    return transport + taxeDrum + parcari + bilete + alteCosturi;
  }

  List<String> validate() {
    final errors = <String>[];
    if (id.isEmpty || projectId.isEmpty) {
      errors.add('Proiectul este obligatoriu.');
    }
    if (punctPlecare.isEmpty || destinatie.isEmpty) {
      errors.add('Plecarea și destinația sunt obligatorii.');
    }
    if (dataRevenire.isBefore(dataPlecare)) {
      errors.add('Perioada este invalidă.');
    }
    final values = <double>[
      kilometriEstimati,
      kilometriReali,
      tarifKmSnapshot,
      consum,
      pretCombustibil,
      taxeDrum,
      parcari,
      bilete,
      alteCosturi,
      costEstimat,
      costReal,
    ];
    if (values.any((value) => !value.isFinite || value < 0)) {
      errors.add('Valorile deplasării trebuie să fie finite și nenegative.');
    }
    return errors;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'project_id': projectId,
        'data_plecare': dataPlecare.toIso8601String(),
        'data_revenire': dataRevenire.toIso8601String(),
        'punct_plecare': punctPlecare,
        'destinatie': destinatie,
        'tara': tara,
        'tip_deplasare': tipDeplasare,
        'asociat': asociat.value,
        'persoane': persoane,
        'vehicle_id': vehicleId,
        'vehicle_snapshot': vehicleSnapshot,
        'tip_transport': tipTransport,
        'metoda_calcul': metodaCalcul.name,
        'kilometri_estimati': kilometriEstimati,
        'kilometri_reali': kilometriReali,
        'tarif_km_snapshot': tarifKmSnapshot,
        'consum': consum,
        'pret_combustibil': pretCombustibil,
        'taxe_drum': taxeDrum,
        'parcari': parcari,
        'bilete': bilete,
        'alte_costuri': alteCosturi,
        'cost_estimat': costEstimat,
        'cost_real': costReal,
        'platitor': platitor.value,
        'refacturabil': refacturabil,
        'eligibil': eligibil,
        'document_ref': documentRef,
        'status': status.value,
        'observatii': observatii,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
        'updated_by': updatedBy,
        'revision': revision,
      };

  factory DeplasareAsociereRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    final rawPeople = map['persoane'];
    return DeplasareAsociereRecord(
      id: mapText(map, 'id'),
      projectId: mapText(map, 'project_id', 'projectId'),
      dataPlecare: mapDate(map, 'data_plecare', 'dataPlecare') ?? now,
      dataRevenire: mapDate(map, 'data_revenire', 'dataRevenire') ?? now,
      punctPlecare: mapText(map, 'punct_plecare', 'punctPlecare'),
      destinatie: mapText(map, 'destinatie'),
      tara: mapText(map, 'tara').isEmpty ? 'România' : mapText(map, 'tara'),
      tipDeplasare: mapText(map, 'tip_deplasare', 'tipDeplasare'),
      asociat: AsociereParteX.fromValue(map['asociat']),
      persoane: rawPeople is List
          ? rawPeople.map((e) => '$e').toList(growable: false)
          : const [],
      vehicleId: mapText(map, 'vehicle_id', 'vehicleId'),
      vehicleSnapshot: mapText(map, 'vehicle_snapshot', 'vehicleSnapshot'),
      tipTransport: mapText(map, 'tip_transport', 'tipTransport'),
      metodaCalcul: DeplasareCalcul.values.firstWhere(
          (e) => e.name == mapText(map, 'metoda_calcul', 'metodaCalcul'),
          orElse: () => DeplasareCalcul.tarifKm),
      kilometriEstimati:
          mapDouble(map, 'kilometri_estimati', 'kilometriEstimati'),
      kilometriReali: mapDouble(map, 'kilometri_reali', 'kilometriReali'),
      tarifKmSnapshot: mapDouble(map, 'tarif_km_snapshot', 'tarifKmSnapshot'),
      consum: mapDouble(map, 'consum'),
      pretCombustibil: mapDouble(map, 'pret_combustibil', 'pretCombustibil'),
      taxeDrum: mapDouble(map, 'taxe_drum', 'taxeDrum'),
      parcari: mapDouble(map, 'parcari'),
      bilete: mapDouble(map, 'bilete'),
      alteCosturi: mapDouble(map, 'alte_costuri', 'alteCosturi'),
      costEstimat: mapDouble(map, 'cost_estimat', 'costEstimat'),
      costReal: mapDouble(map, 'cost_real', 'costReal'),
      platitor: AsociereParteX.fromValue(map['platitor']),
      refacturabil: mapBool(map, 'refacturabil'),
      eligibil: mapBool(map, 'eligibil', null, true),
      documentRef: mapText(map, 'document_ref', 'documentRef'),
      status: AsociereOperationalStatus.fromValue(map['status']),
      observatii: mapText(map, 'observatii'),
      createdAt: mapDate(map, 'created_at', 'createdAt') ?? now,
      updatedAt: mapDate(map, 'updated_at', 'updatedAt') ?? now,
      createdBy: mapText(map, 'created_by', 'createdBy'),
      updatedBy: mapText(map, 'updated_by', 'updatedBy'),
      revision: mapInt(map, 'revision', null, 1),
    );
  }
}
