import 'asociere_operational_common.dart';

enum AsociereRambursareCatre { proTerm, partener, niciunul }

extension AsociereRambursareCatreX on AsociereRambursareCatre {
  String get value => switch (this) {
        AsociereRambursareCatre.proTerm => 'pro_term',
        AsociereRambursareCatre.partener => 'partener',
        AsociereRambursareCatre.niciunul => 'niciunul',
      };

  static AsociereRambursareCatre fromValue(Object? raw) =>
      switch ('$raw'.trim().toLowerCase()) {
        'pro_term' => AsociereRambursareCatre.proTerm,
        'partener' => AsociereRambursareCatre.partener,
        _ => AsociereRambursareCatre.niciunul,
      };
}

enum DecontLunarStatus { draft, confirmat }

extension DecontLunarStatusX on DecontLunarStatus {
  String get value => name;
  String get label =>
      this == DecontLunarStatus.confirmat ? 'Confirmat' : 'Draft';
  static DecontLunarStatus fromValue(Object? raw) =>
      '$raw'.trim().toLowerCase() == 'confirmat'
          ? DecontLunarStatus.confirmat
          : DecontLunarStatus.draft;
}

class DecontLunarAsociereRecord {
  const DecontLunarAsociereRecord({
    required this.id,
    required this.projectId,
    required this.contractId,
    required this.luna,
    required this.an,
    required this.projectSnapshot,
    required this.contractSnapshot,
    required this.inputIds,
    required this.veniturIncasatTotal,
    required this.costRecunoscutProTerm,
    required this.costRecunoscutPartener,
    required this.rezultat,
    this.rambursareDatorataCatre = AsociereRambursareCatre.niciunul,
    this.rambursareCosturi = 0,
    this.distribuireProfitImediata = 0,
    this.sumaRambursare = 0,
    this.sumaRezervaRetinuta = 0,
    this.sumaDeAchitatAcum = 0,
    this.formulaRevision = 1,
    this.status = DecontLunarStatus.draft,
    required this.dataGenerare,
    required this.generatDe,
    this.confirmatDe,
    this.confirmatLa,
    this.revision = 1,
  });

  final String id;
  final String projectId;
  final String contractId;
  final int luna;
  final int an;
  final Map<String, dynamic> projectSnapshot;
  final Map<String, dynamic> contractSnapshot;
  final List<String> inputIds;
  final double veniturIncasatTotal;
  final double costRecunoscutProTerm;
  final double costRecunoscutPartener;
  final double rezultat;
  final AsociereRambursareCatre rambursareDatorataCatre;
  final double rambursareCosturi;
  final double distribuireProfitImediata;
  final double sumaRambursare;
  final double sumaRezervaRetinuta;
  final double sumaDeAchitatAcum;
  final int formulaRevision;
  final DecontLunarStatus status;
  final DateTime dataGenerare;
  final String generatDe;
  final String? confirmatDe;
  final DateTime? confirmatLa;
  final int revision;

  String get idempotencyKey =>
      '$projectId:$contractId:$an:${luna.toString().padLeft(2, '0')}';

  DecontLunarAsociereRecord confirma(String actor, DateTime now) =>
      DecontLunarAsociereRecord.fromMap(toMap()
        ..addAll({
          'status': DecontLunarStatus.confirmat.value,
          'confirmat_de': actor,
          'confirmat_la': now.toIso8601String(),
          'revision': revision + 1,
        }));

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'contract_id': contractId,
        'luna': luna,
        'an': an,
        'project_snapshot': projectSnapshot,
        'contract_snapshot': contractSnapshot,
        'input_ids': inputIds,
        'venituri_incasat_total': veniturIncasatTotal,
        'cost_recunoscut_pro_term': costRecunoscutProTerm,
        'cost_recunoscut_partener': costRecunoscutPartener,
        'rezultat': rezultat,
        'rambursare_datorata_catre': rambursareDatorataCatre.value,
        'rambursare_costuri': rambursareCosturi,
        'distribuire_profit_imediata': distribuireProfitImediata,
        'suma_rambursare': sumaRambursare,
        'suma_rezerva_retinuta': sumaRezervaRetinuta,
        'suma_de_achitat_acum': sumaDeAchitatAcum,
        'formula_revision': formulaRevision,
        'status': status.value,
        'data_generare': dataGenerare.toIso8601String(),
        'generat_de': generatDe,
        'confirmat_de': confirmatDe,
        'confirmat_la': confirmatLa?.toIso8601String(),
        'revision': revision,
        'idempotency_key': idempotencyKey,
      };

  factory DecontLunarAsociereRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return DecontLunarAsociereRecord(
      id: mapText(map, 'id'),
      projectId: mapText(map, 'project_id', 'projectId'),
      contractId: mapText(map, 'contract_id', 'contractId'),
      luna: mapInt(map, 'luna', null, now.month),
      an: mapInt(map, 'an', null, now.year),
      projectSnapshot: Map<String, dynamic>.from(map['project_snapshot'] is Map
          ? map['project_snapshot'] as Map
          : const {}),
      contractSnapshot: Map<String, dynamic>.from(
          map['contract_snapshot'] is Map
              ? map['contract_snapshot'] as Map
              : const {}),
      inputIds: (map['input_ids'] is List ? map['input_ids'] as List : const [])
          .map((item) => '$item')
          .toList(),
      veniturIncasatTotal:
          mapDouble(map, 'venituri_incasat_total', 'veniturIncasatTotal'),
      costRecunoscutProTerm:
          mapDouble(map, 'cost_recunoscut_pro_term', 'costRecunoscutProTerm'),
      costRecunoscutPartener:
          mapDouble(map, 'cost_recunoscut_partener', 'costRecunoscutPartener'),
      rezultat: mapDouble(map, 'rezultat'),
      rambursareDatorataCatre:
          AsociereRambursareCatreX.fromValue(map['rambursare_datorata_catre']),
      rambursareCosturi:
          mapDouble(map, 'rambursare_costuri', 'rambursareCosturi'),
      distribuireProfitImediata: mapDouble(
          map, 'distribuire_profit_imediata', 'distribuireProfitImediata'),
      sumaRambursare: mapDouble(map, 'suma_rambursare', 'sumaRambursare'),
      sumaRezervaRetinuta:
          mapDouble(map, 'suma_rezerva_retinuta', 'sumaRezervaRetinuta'),
      sumaDeAchitatAcum:
          mapDouble(map, 'suma_de_achitat_acum', 'sumaDeAchitatAcum'),
      formulaRevision: mapInt(map, 'formula_revision', 'formulaRevision', 1),
      status: DecontLunarStatusX.fromValue(map['status']),
      dataGenerare: mapDate(map, 'data_generare', 'dataGenerare') ?? now,
      generatDe: mapText(map, 'generat_de', 'generatDe'),
      confirmatDe:
          nullableMapString(map, const ['confirmat_de', 'confirmatDe']),
      confirmatLa: mapDate(map, 'confirmat_la', 'confirmatLa'),
      revision: mapInt(map, 'revision', null, 1),
    );
  }
}
