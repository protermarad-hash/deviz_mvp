import 'asociere_operational_common.dart';

enum CazareCalcul { persoanaNoapte, cameraNoapte, totalReal }

class CazareAsociereRecord {
  const CazareAsociereRecord({
    required this.id,
    required this.projectId,
    this.deplasareId = '',
    required this.furnizor,
    required this.localitate,
    this.tara = 'România',
    required this.checkIn,
    required this.checkOut,
    required this.nopti,
    required this.persoane,
    required this.camere,
    this.metodaCalcul = CazareCalcul.persoanaNoapte,
    required this.tarif,
    this.moneda = 'RON',
    this.curs = 1,
    this.costEstimat = 0,
    this.costReal = 0,
    this.platitor = AsociereParte.proTerm,
    this.eligibil = true,
    this.refacturabil = false,
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
  final String deplasareId;
  final String furnizor;
  final String localitate;
  final String tara;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nopti;
  final int persoane;
  final int camere;
  final CazareCalcul metodaCalcul;
  final double tarif;
  final String moneda;
  final double curs;
  final double costEstimat;
  final double costReal;
  final AsociereParte platitor;
  final bool eligibil;
  final bool refacturabil;
  final String documentRef;
  final AsociereOperationalStatus status;
  final String observatii;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final int revision;

  double calculeazaCost() => switch (metodaCalcul) {
        CazareCalcul.persoanaNoapte => persoane * nopti * tarif * curs,
        CazareCalcul.cameraNoapte => camere * nopti * tarif * curs,
        CazareCalcul.totalReal => costReal * curs,
      };

  List<String> validate() {
    final errors = <String>[];
    if (id.isEmpty || projectId.isEmpty) {
      errors.add('Proiectul este obligatoriu.');
    }
    if (furnizor.isEmpty || localitate.isEmpty) {
      errors.add('Furnizorul și localitatea sunt obligatorii.');
    }
    if (checkOut.isBefore(checkIn)) {
      errors.add('Perioada cazării este invalidă.');
    }
    if (nopti < 0 || persoane < 0 || camere < 0) {
      errors.add('Cantitățile nu pot fi negative.');
    }
    if (<double>[tarif, curs, costEstimat, costReal]
        .any((v) => !v.isFinite || v < 0)) {
      errors.add('Valorile trebuie să fie finite și nenegative.');
    }
    return errors;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'project_id': projectId,
        'deplasare_id': deplasareId,
        'furnizor': furnizor,
        'localitate': localitate,
        'tara': tara,
        'check_in': checkIn.toIso8601String(),
        'check_out': checkOut.toIso8601String(),
        'nopti': nopti,
        'persoane': persoane,
        'camere': camere,
        'metoda_calcul': metodaCalcul.name,
        'tarif': tarif,
        'moneda': moneda,
        'curs': curs,
        'cost_estimat': costEstimat,
        'cost_real': costReal,
        'platitor': platitor.value,
        'eligibil': eligibil,
        'refacturabil': refacturabil,
        'document_ref': documentRef,
        'status': status.value,
        'observatii': observatii,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
        'updated_by': updatedBy,
        'revision': revision,
      };

  factory CazareAsociereRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return CazareAsociereRecord(
      id: mapText(map, 'id'),
      projectId: mapText(map, 'project_id', 'projectId'),
      deplasareId: mapText(map, 'deplasare_id', 'deplasareId'),
      furnizor: mapText(map, 'furnizor'),
      localitate: mapText(map, 'localitate'),
      tara: mapText(map, 'tara').isEmpty ? 'România' : mapText(map, 'tara'),
      checkIn: mapDate(map, 'check_in', 'checkIn') ?? now,
      checkOut: mapDate(map, 'check_out', 'checkOut') ?? now,
      nopti: mapInt(map, 'nopti'),
      persoane: mapInt(map, 'persoane'),
      camere: mapInt(map, 'camere'),
      metodaCalcul: CazareCalcul.values.firstWhere(
          (e) => e.name == mapText(map, 'metoda_calcul', 'metodaCalcul'),
          orElse: () => CazareCalcul.persoanaNoapte),
      tarif: mapDouble(map, 'tarif'),
      moneda: mapText(map, 'moneda').isEmpty
          ? 'RON'
          : mapText(map, 'moneda').toUpperCase(),
      curs: mapDouble(map, 'curs', null, 1),
      costEstimat: mapDouble(map, 'cost_estimat', 'costEstimat'),
      costReal: mapDouble(map, 'cost_real', 'costReal'),
      platitor: AsociereParteX.fromValue(map['platitor']),
      eligibil: mapBool(map, 'eligibil', null, true),
      refacturabil: mapBool(map, 'refacturabil'),
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
