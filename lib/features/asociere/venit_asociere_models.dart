import 'asociere_operational_common.dart';

enum VenitAsociereEtapa { estimat, facturat, incasat }

class VenitAsociereRecord {
  const VenitAsociereRecord({
    required this.id,
    required this.projectId,
    this.contractId,
    required this.etapa,
    this.numarFactura = '',
    this.dataFactura,
    required this.valoareFaraTva,
    this.moneda = 'RON',
    this.curs = 1,
    this.emitent = AsociereParte.proTerm,
    this.beneficiar = '',
    this.scadenta,
    this.sumaIncasata = 0,
    this.dataIncasarii,
    this.documentRef,
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
  final String? contractId;
  final VenitAsociereEtapa etapa;
  final String numarFactura;
  final DateTime? dataFactura;
  final double valoareFaraTva;
  final String moneda;
  final double curs;
  final AsociereParte emitent;
  final String beneficiar;
  final DateTime? scadenta;
  final double sumaIncasata;
  final DateTime? dataIncasarii;
  final String? documentRef;
  final bool eligibil;
  final AsociereOperationalStatus status;
  final String observatii;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final int revision;

  bool get esteIncasat =>
      etapa == VenitAsociereEtapa.incasat && sumaIncasata > 0;
  String get idempotencyKey =>
      '$projectId:${numarFactura.trim().toLowerCase()}:${dataFactura?.toIso8601String() ?? id}';
  double get valoareProiect => sumaIncasata * curs;

  List<String> validate() {
    final errors = <String>[];
    if (projectId.trim().isEmpty) errors.add('Proiectul este obligatoriu.');
    if (!valoareFaraTva.isFinite || valoareFaraTva < 0) {
      errors.add('Valoarea este invalidă.');
    }
    if (!sumaIncasata.isFinite || sumaIncasata < 0 || curs <= 0) {
      errors.add('Încasarea sau cursul este invalid.');
    }
    if (etapa != VenitAsociereEtapa.estimat &&
        (numarFactura.trim().isEmpty || dataFactura == null)) {
      errors.add(
          'Factura și data sunt obligatorii pentru venit facturat/încasat.');
    }
    if (etapa == VenitAsociereEtapa.incasat && dataIncasarii == null) {
      errors.add('Data încasării este obligatorie.');
    }
    return errors;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'contract_id': contractId,
        'etapa': etapa.name,
        'numar_factura': numarFactura,
        'data_factura': dataFactura?.toIso8601String(),
        'valoare_fara_tva': valoareFaraTva,
        'moneda': moneda,
        'curs': curs,
        'emitent': emitent.value,
        'beneficiar': beneficiar,
        'scadenta': scadenta?.toIso8601String(),
        'suma_incasata': sumaIncasata,
        'data_incasarii': dataIncasarii?.toIso8601String(),
        'document_ref': documentRef,
        'eligibil': eligibil,
        'status': status.value,
        'observatii': observatii,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
        'updated_by': updatedBy,
        'revision': revision,
      };

  factory VenitAsociereRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    final etapaRaw = mapString(map, const ['etapa']);
    final etapa = VenitAsociereEtapa.values.firstWhere(
      (item) => item.name == etapaRaw,
      orElse: () => VenitAsociereEtapa.estimat,
    );
    return VenitAsociereRecord(
      id: mapString(map, const ['id']),
      projectId: mapString(map, const ['project_id', 'projectId']),
      contractId: nullableMapString(map, const ['contract_id', 'contractId']),
      etapa: etapa,
      numarFactura: mapString(map, const ['numar_factura', 'numarFactura']),
      dataFactura: valueDate(map['data_factura'] ?? map['dataFactura']),
      valoareFaraTva:
          valueDouble(map['valoare_fara_tva'] ?? map['valoareFaraTva']),
      moneda: mapString(map, const ['moneda'], fallback: 'RON'),
      curs: valueDouble(map['curs'], fallback: 1),
      emitent: AsociereParteX.fromValue(map['emitent']?.toString()),
      beneficiar: mapString(map, const ['beneficiar']),
      scadenta: valueDate(map['scadenta']),
      sumaIncasata: valueDouble(map['suma_incasata'] ?? map['sumaIncasata']),
      dataIncasarii: valueDate(map['data_incasarii'] ?? map['dataIncasarii']),
      documentRef:
          nullableMapString(map, const ['document_ref', 'documentRef']),
      eligibil: valueBool(map['eligibil'], fallback: true),
      status: AsociereOperationalStatus.fromValue(map['status']),
      observatii: mapString(map, const ['observatii']),
      createdAt: valueDate(map['created_at'] ?? map['createdAt']) ?? now,
      updatedAt: valueDate(map['updated_at'] ?? map['updatedAt']) ?? now,
      createdBy: mapString(map, const ['created_by', 'createdBy']),
      updatedBy: mapString(map, const ['updated_by', 'updatedBy']),
      revision: valueInt(map['revision'], fallback: 1),
    );
  }
}
