import 'asociere_operational_common.dart';

enum AsociereAngajator { proTerm, partener }

extension AsociereAngajatorX on AsociereAngajator {
  String get value =>
      this == AsociereAngajator.proTerm ? 'pro_term' : 'partener';
  String get label =>
      this == AsociereAngajator.proTerm ? 'PRO TERM' : 'Partener';
  static AsociereAngajator fromValue(Object? raw) =>
      '$raw'.trim().toLowerCase() == 'partener'
          ? AsociereAngajator.partener
          : AsociereAngajator.proTerm;
}

class PontajAsociereRecord {
  const PontajAsociereRecord({
    required this.id,
    required this.projectId,
    this.contractId = '',
    required this.persoanaId,
    required this.persoanaNameSnapshot,
    required this.angajator,
    required this.calificare,
    required this.data,
    required this.ore,
    this.activitate = '',
    this.faza = '',
    this.zona = '',
    this.tarifSnapshot = 0,
    this.costCalculat = 0,
    this.status = AsociereOperationalStatus.draft,
    this.confirmareInterna = false,
    this.confirmareInternaActor = '',
    this.confirmareInternaLa,
    this.confirmareExternaInregistrata = false,
    this.confirmareExternaActor = '',
    this.confirmareExternaLa,
    this.confirmareDocumentRef = '',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
    this.revision = 1,
  });

  final String id;
  final String projectId;
  final String contractId;
  final String persoanaId;
  final String persoanaNameSnapshot;
  final AsociereAngajator angajator;
  final String calificare;
  final DateTime data;
  final double ore;
  final String activitate;
  final String faza;
  final String zona;
  final double tarifSnapshot;
  final double costCalculat;
  final AsociereOperationalStatus status;
  final bool confirmareInterna;
  final String confirmareInternaActor;
  final DateTime? confirmareInternaLa;
  final bool confirmareExternaInregistrata;
  final String confirmareExternaActor;
  final DateTime? confirmareExternaLa;
  final String confirmareDocumentRef;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final int revision;

  String get lucratorNume => persoanaNameSnapshot;
  String get activitateZona =>
      [activitate, zona].where((v) => v.isNotEmpty).join(' · ');
  bool get confirmatProTerm => confirmareInterna;
  bool get confirmatPartener => confirmareExternaInregistrata;
  DateTime? get dataConfirmare => confirmareExternaLa ?? confirmareInternaLa;
  bool get esteConfirmatIntegral =>
      confirmareInterna && confirmareExternaInregistrata;
  DateTime? get dataRecunoastereCost =>
      esteConfirmatIntegral ? dataConfirmare : null;
  String get idempotencyKey =>
      '${projectId.trim()}|${persoanaId.trim()}|${data.toIso8601String().substring(0, 10)}|${ore.toStringAsFixed(2)}|${activitate.trim().toLowerCase()}';

  List<String> validate() {
    final errors = <String>[];
    if (id.isEmpty || projectId.isEmpty || persoanaId.isEmpty) {
      errors.add('Proiectul și persoana sunt obligatorii.');
    }
    if (persoanaNameSnapshot.isEmpty || calificare.isEmpty) {
      errors.add('Numele și calificarea sunt obligatorii.');
    }
    if (!ore.isFinite || ore <= 0 || ore > 24) {
      errors.add('Orele trebuie să fie între 0 și 24.');
    }
    if (!tarifSnapshot.isFinite ||
        tarifSnapshot < 0 ||
        !costCalculat.isFinite ||
        costCalculat < 0) {
      errors.add('Tariful și costul trebuie să fie nenegative.');
    }
    if (confirmareInterna &&
        (confirmareInternaActor.isEmpty || confirmareInternaLa == null)) {
      errors.add('Confirmarea internă necesită actor și timestamp.');
    }
    if (confirmareExternaInregistrata &&
        (confirmareExternaActor.isEmpty ||
            confirmareExternaLa == null ||
            confirmareDocumentRef.isEmpty)) {
      errors.add('Confirmarea externă necesită admin, timestamp și document.');
    }
    return errors;
  }

  PontajAsociereRecord copyWith({
    String? id,
    DateTime? data,
    double? ore,
    String? activitate,
    AsociereOperationalStatus? status,
    bool? confirmareInterna,
    String? confirmareInternaActor,
    DateTime? confirmareInternaLa,
    bool? confirmareExternaInregistrata,
    String? confirmareExternaActor,
    DateTime? confirmareExternaLa,
    String? confirmareDocumentRef,
    DateTime? updatedAt,
    String? updatedBy,
    int? revision,
  }) =>
      PontajAsociereRecord(
        id: id ?? this.id,
        projectId: projectId,
        contractId: contractId,
        persoanaId: persoanaId,
        persoanaNameSnapshot: persoanaNameSnapshot,
        angajator: angajator,
        calificare: calificare,
        data: data ?? this.data,
        ore: ore ?? this.ore,
        activitate: activitate ?? this.activitate,
        faza: faza,
        zona: zona,
        tarifSnapshot: tarifSnapshot,
        costCalculat: (ore ?? this.ore) * tarifSnapshot,
        status: status ?? this.status,
        confirmareInterna: confirmareInterna ?? this.confirmareInterna,
        confirmareInternaActor:
            confirmareInternaActor ?? this.confirmareInternaActor,
        confirmareInternaLa: confirmareInternaLa ?? this.confirmareInternaLa,
        confirmareExternaInregistrata:
            confirmareExternaInregistrata ?? this.confirmareExternaInregistrata,
        confirmareExternaActor:
            confirmareExternaActor ?? this.confirmareExternaActor,
        confirmareExternaLa: confirmareExternaLa ?? this.confirmareExternaLa,
        confirmareDocumentRef:
            confirmareDocumentRef ?? this.confirmareDocumentRef,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy,
        updatedBy: updatedBy ?? this.updatedBy,
        revision: revision ?? this.revision,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'project_id': projectId,
        'contract_id': contractId,
        'persoana_id': persoanaId,
        'persoana_name_snapshot': persoanaNameSnapshot,
        'angajator': angajator.value,
        'calificare': calificare,
        'data': data.toIso8601String(),
        'ore': ore,
        'activitate': activitate,
        'faza': faza,
        'zona': zona,
        'tarif_snapshot': tarifSnapshot,
        'cost_calculat': costCalculat,
        'status': status.value,
        'confirmare_interna': confirmareInterna,
        'confirmare_interna_actor': confirmareInternaActor,
        'confirmare_interna_la': confirmareInternaLa?.toIso8601String(),
        'confirmare_externa_inregistrata': confirmareExternaInregistrata,
        'confirmare_externa_actor': confirmareExternaActor,
        'confirmare_externa_la': confirmareExternaLa?.toIso8601String(),
        'confirmare_document_ref': confirmareDocumentRef,
        'idempotency_key': idempotencyKey,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
        'updated_by': updatedBy,
        'revision': revision,
      };

  factory PontajAsociereRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return PontajAsociereRecord(
      id: mapText(map, 'id'),
      projectId: mapText(map, 'project_id', 'projectId'),
      contractId: mapText(map, 'contract_id', 'contractId'),
      persoanaId: mapText(map, 'persoana_id', 'persoanaId'),
      persoanaNameSnapshot:
          mapText(map, 'persoana_name_snapshot', 'persoanaNameSnapshot'),
      angajator: AsociereAngajatorX.fromValue(map['angajator']),
      calificare: mapText(map, 'calificare'),
      data: mapDate(map, 'data') ?? now,
      ore: mapDouble(map, 'ore'),
      activitate: mapText(map, 'activitate'),
      faza: mapText(map, 'faza'),
      zona: mapText(map, 'zona'),
      tarifSnapshot: mapDouble(map, 'tarif_snapshot', 'tarifSnapshot'),
      costCalculat: mapDouble(map, 'cost_calculat', 'costCalculat'),
      status: AsociereOperationalStatus.fromValue(map['status']),
      confirmareInterna:
          mapBool(map, 'confirmare_interna', 'confirmareInterna'),
      confirmareInternaActor:
          mapText(map, 'confirmare_interna_actor', 'confirmareInternaActor'),
      confirmareInternaLa:
          mapDate(map, 'confirmare_interna_la', 'confirmareInternaLa'),
      confirmareExternaInregistrata: mapBool(map,
          'confirmare_externa_inregistrata', 'confirmareExternaInregistrata'),
      confirmareExternaActor:
          mapText(map, 'confirmare_externa_actor', 'confirmareExternaActor'),
      confirmareExternaLa:
          mapDate(map, 'confirmare_externa_la', 'confirmareExternaLa'),
      confirmareDocumentRef:
          mapText(map, 'confirmare_document_ref', 'confirmareDocumentRef'),
      createdAt: mapDate(map, 'created_at', 'createdAt') ?? now,
      updatedAt: mapDate(map, 'updated_at', 'updatedAt') ?? now,
      createdBy: mapText(map, 'created_by', 'createdBy'),
      updatedBy: mapText(map, 'updated_by', 'updatedBy'),
      revision: mapInt(map, 'revision', null, 1),
    );
  }
}
