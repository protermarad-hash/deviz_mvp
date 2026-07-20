import 'asociere_operational_common.dart';

enum AsociereCostCategorie {
  materiale,
  consumabile,
  manopera,
  management,
  transport,
  cazare,
  diurna,
  utilaje,
  inchirieri,
  taxe,
  verificari,
  alteCosturi;

  String get value => switch (this) {
        AsociereCostCategorie.alteCosturi => 'alte_costuri',
        _ => name,
      };

  String get label => switch (this) {
        AsociereCostCategorie.materiale => 'Materiale',
        AsociereCostCategorie.consumabile => 'Consumabile',
        AsociereCostCategorie.manopera => 'Manoperă',
        AsociereCostCategorie.management => 'Management',
        AsociereCostCategorie.transport => 'Transport',
        AsociereCostCategorie.cazare => 'Cazare',
        AsociereCostCategorie.diurna => 'Diurnă',
        AsociereCostCategorie.utilaje => 'Utilaje',
        AsociereCostCategorie.inchirieri => 'Închirieri',
        AsociereCostCategorie.taxe => 'Taxe',
        AsociereCostCategorie.verificari => 'Verificări',
        AsociereCostCategorie.alteCosturi => 'Alte costuri',
      };

  static AsociereCostCategorie fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value == 'material') return AsociereCostCategorie.materiale;
    if (value == 'manopera_calculata') return AsociereCostCategorie.manopera;
    if (value == 'altele') return AsociereCostCategorie.alteCosturi;
    return AsociereCostCategorie.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AsociereCostCategorie.alteCosturi,
    );
  }
}

class CostAsociereRecord {
  const CostAsociereRecord({
    required this.id,
    required this.projectId,
    this.contractId,
    required this.sourceType,
    required this.sourceId,
    required this.categorie,
    required this.descriere,
    required this.data,
    this.furnizor = '',
    this.documentRef,
    required this.valoareFaraTva,
    this.tvaInformativ = 0,
    this.moneda = 'RON',
    this.curs = 1,
    required this.valoareProiect,
    required this.platitor,
    this.refacturabil = false,
    this.eligibil = true,
    this.status = AsociereOperationalStatus.draft,
    this.aprobatDe,
    this.aprobatLa,
    this.observatii = '',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
    this.revision = 1,
  });

  final String id;
  final String projectId;
  final String? contractId;
  final String sourceType;
  final String sourceId;
  final AsociereCostCategorie categorie;
  final String descriere;
  final DateTime data;
  final String furnizor;
  final String? documentRef;
  final double valoareFaraTva;
  final double tvaInformativ;
  final String moneda;
  final double curs;
  final double valoareProiect;
  final AsociereParte platitor;
  final bool refacturabil;
  final bool eligibil;
  final AsociereOperationalStatus status;
  final String? aprobatDe;
  final DateTime? aprobatLa;
  final String observatii;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final int revision;

  String get idempotencyKey => '$projectId:$sourceType:$sourceId';
  bool get esteAprobat => status == AsociereOperationalStatus.aprobat;
  DateTime? get dataRecunoastereCost =>
      esteAprobat && eligibil ? aprobatLa : null;
  DateTime get dataApartenentaLuna => dataRecunoastereCost ?? data;

  List<String> validate({double? pragAprobare}) {
    final errors = <String>[];
    if (projectId.trim().isEmpty) errors.add('Proiectul este obligatoriu.');
    if (sourceType.trim().isEmpty || sourceId.trim().isEmpty) {
      errors.add('Sursa costului este obligatorie.');
    }
    if (descriere.trim().isEmpty) errors.add('Descrierea este obligatorie.');
    if (!valoareFaraTva.isFinite || valoareFaraTva < 0) {
      errors.add('Valoarea trebuie să fie finită și nenegativă.');
    }
    if (!valoareProiect.isFinite || valoareProiect < 0 || curs <= 0) {
      errors.add('Conversia în moneda proiectului este invalidă.');
    }
    if (esteAprobat) {
      if ((documentRef ?? '').trim().isEmpty) {
        errors.add('Documentul este obligatoriu la aprobare.');
      }
      if (aprobatDe?.trim().isEmpty ?? true) {
        errors.add('Actorul aprobării este obligatoriu.');
      }
      if (aprobatLa == null) errors.add('Data aprobării este obligatorie.');
    }
    return errors;
  }

  CostAsociereRecord copyWith({
    AsociereOperationalStatus? status,
    String? aprobatDe,
    DateTime? aprobatLa,
    DateTime? updatedAt,
    String? updatedBy,
    int? revision,
  }) =>
      CostAsociereRecord(
        id: id,
        projectId: projectId,
        contractId: contractId,
        sourceType: sourceType,
        sourceId: sourceId,
        categorie: categorie,
        descriere: descriere,
        data: data,
        furnizor: furnizor,
        documentRef: documentRef,
        valoareFaraTva: valoareFaraTva,
        tvaInformativ: tvaInformativ,
        moneda: moneda,
        curs: curs,
        valoareProiect: valoareProiect,
        platitor: platitor,
        refacturabil: refacturabil,
        eligibil: eligibil,
        status: status ?? this.status,
        aprobatDe: aprobatDe ?? this.aprobatDe,
        aprobatLa: aprobatLa ?? this.aprobatLa,
        observatii: observatii,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy,
        updatedBy: updatedBy ?? this.updatedBy,
        revision: revision ?? this.revision,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'contract_id': contractId,
        'source_type': sourceType,
        'source_id': sourceId,
        'categorie': categorie.value,
        'descriere': descriere,
        'data': data.toIso8601String(),
        'furnizor': furnizor,
        'document_ref': documentRef,
        'valoare_fara_tva': valoareFaraTva,
        'tva_informativ': tvaInformativ,
        'moneda': moneda,
        'curs': curs,
        'valoare_proiect': valoareProiect,
        'platitor': platitor.value,
        'refacturabil': refacturabil,
        'eligibil': eligibil,
        'status': status.value,
        'aprobat_de': aprobatDe,
        'aprobat_la': aprobatLa?.toIso8601String(),
        'observatii': observatii,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
        'updated_by': updatedBy,
        'revision': revision,
      };

  factory CostAsociereRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return CostAsociereRecord(
      id: mapString(map, const ['id']),
      projectId: mapString(map, const ['project_id', 'projectId']),
      contractId: nullableMapString(map, const ['contract_id', 'contractId']),
      sourceType: mapString(map, const ['source_type', 'sourceType']),
      sourceId: mapString(map, const ['source_id', 'sourceId']),
      categorie: AsociereCostCategorie.fromValue(map['categorie']?.toString()),
      descriere: mapString(map, const ['descriere']),
      data: valueDate(map['data']) ?? now,
      furnizor: mapString(map, const ['furnizor']),
      documentRef:
          nullableMapString(map, const ['document_ref', 'documentRef']),
      valoareFaraTva:
          valueDouble(map['valoare_fara_tva'] ?? map['valoareFaraTva']),
      tvaInformativ: valueDouble(map['tva_informativ'] ?? map['tvaInformativ']),
      moneda: mapString(map, const ['moneda'], fallback: 'RON'),
      curs: valueDouble(map['curs'], fallback: 1),
      valoareProiect:
          valueDouble(map['valoare_proiect'] ?? map['valoareProiect']),
      platitor: AsociereParteX.fromValue(map['platitor']?.toString()),
      refacturabil: valueBool(map['refacturabil']),
      eligibil: valueBool(map['eligibil'], fallback: true),
      status: AsociereOperationalStatus.fromValue(map['status']),
      aprobatDe: nullableMapString(map, const ['aprobat_de', 'aprobatDe']),
      aprobatLa: valueDate(map['aprobat_la'] ?? map['aprobatLa']),
      observatii: mapString(map, const ['observatii']),
      createdAt: valueDate(map['created_at'] ?? map['createdAt']) ?? now,
      updatedAt: valueDate(map['updated_at'] ?? map['updatedAt']) ?? now,
      createdBy: mapString(map, const ['created_by', 'createdBy']),
      updatedBy: mapString(map, const ['updated_by', 'updatedBy']),
      revision: valueInt(map['revision'], fallback: 1),
    );
  }
}
