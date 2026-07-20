import 'asociere_operational_common.dart';

class DiurnaAsociereRecord {
  const DiurnaAsociereRecord({
    required this.id,
    required this.projectId,
    this.deplasareId = '',
    required this.persoanaId,
    required this.persoanaSnapshot,
    this.asociat = AsociereParte.proTerm,
    this.tara = 'România',
    this.internExtern = 'intern',
    required this.dataInceput,
    required this.dataSfarsit,
    required this.zileEligibile,
    required this.tarifZi,
    this.moneda = 'RON',
    this.curs = 1,
    this.valoareEstimata = 0,
    this.valoareReala = 0,
    this.platit = false,
    this.eligibil = true,
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
  final String deplasareId;
  final String persoanaId;
  final String persoanaSnapshot;
  final AsociereParte asociat;
  final String tara;
  final String internExtern;
  final DateTime dataInceput;
  final DateTime dataSfarsit;
  final double zileEligibile;
  final double tarifZi;
  final String moneda;
  final double curs;
  final double valoareEstimata;
  final double valoareReala;
  final bool platit;
  final bool eligibil;
  final AsociereOperationalStatus status;
  final String observatii;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final int revision;

  double calculeazaValoare() => zileEligibile * tarifZi * curs;

  List<String> validate() {
    final errors = <String>[];
    if (id.isEmpty || projectId.isEmpty || persoanaId.isEmpty) {
      errors.add('Proiectul și persoana sunt obligatorii.');
    }
    if (dataSfarsit.isBefore(dataInceput)) {
      errors.add('Perioada diurnei este invalidă.');
    }
    if (<double>[zileEligibile, tarifZi, curs, valoareEstimata, valoareReala]
        .any((v) => !v.isFinite || v < 0)) {
      errors.add('Valorile trebuie să fie finite și nenegative.');
    }
    if (!const {'intern', 'extern'}.contains(internExtern)) {
      errors.add('Tipul diurnei este invalid.');
    }
    return errors;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'project_id': projectId,
        'deplasare_id': deplasareId,
        'persoana_id': persoanaId,
        'persoana_snapshot': persoanaSnapshot,
        'asociat': asociat.value,
        'tara': tara,
        'intern_extern': internExtern,
        'data_inceput': dataInceput.toIso8601String(),
        'data_sfarsit': dataSfarsit.toIso8601String(),
        'zile_eligibile': zileEligibile,
        'tarif_zi': tarifZi,
        'moneda': moneda,
        'curs': curs,
        'valoare_estimata': valoareEstimata,
        'valoare_reala': valoareReala,
        'platit': platit,
        'eligibil': eligibil,
        'status': status.value,
        'observatii': observatii,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
        'updated_by': updatedBy,
        'revision': revision,
      };

  factory DiurnaAsociereRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return DiurnaAsociereRecord(
      id: mapText(map, 'id'),
      projectId: mapText(map, 'project_id', 'projectId'),
      deplasareId: mapText(map, 'deplasare_id', 'deplasareId'),
      persoanaId: mapText(map, 'persoana_id', 'persoanaId'),
      persoanaSnapshot: mapText(map, 'persoana_snapshot', 'persoanaSnapshot'),
      asociat: AsociereParteX.fromValue(map['asociat']),
      tara: mapText(map, 'tara').isEmpty ? 'România' : mapText(map, 'tara'),
      internExtern: mapText(map, 'intern_extern', 'internExtern').isEmpty
          ? 'intern'
          : mapText(map, 'intern_extern', 'internExtern'),
      dataInceput: mapDate(map, 'data_inceput', 'dataInceput') ?? now,
      dataSfarsit: mapDate(map, 'data_sfarsit', 'dataSfarsit') ?? now,
      zileEligibile: mapDouble(map, 'zile_eligibile', 'zileEligibile'),
      tarifZi: mapDouble(map, 'tarif_zi', 'tarifZi'),
      moneda: mapText(map, 'moneda').isEmpty
          ? 'RON'
          : mapText(map, 'moneda').toUpperCase(),
      curs: mapDouble(map, 'curs', null, 1),
      valoareEstimata: mapDouble(map, 'valoare_estimata', 'valoareEstimata'),
      valoareReala: mapDouble(map, 'valoare_reala', 'valoareReala'),
      platit: mapBool(map, 'platit'),
      eligibil: mapBool(map, 'eligibil', null, true),
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
