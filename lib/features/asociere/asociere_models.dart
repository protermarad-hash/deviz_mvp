import 'asociere_contract_types.dart';

// Re-export tipurile contractuale (enum AsociereStatus / AsociereIncasator)
// extrase în asociere_contract_types.dart, astfel încât consumatorii care
// importă doar asociere_models.dart să le vadă în continuare (compat retro).
export 'asociere_contract_types.dart';

class AsociereRecord {
  const AsociereRecord({
    required this.id,
    required this.lucrareAsociereId,
    required this.cineFactureazaBeneficiarul,
    this.partenerExternId = '',
    this.partenerExternNume = '',
    this.partenerExternCUI = '',
    this.partenerExternIBAN = '',
    this.partenerExternTelefon = '',
    this.valoareContractuala = 0,
    this.moneda = 'RON',
    required this.cotaProTerm,
    required this.cotaPartener,
    this.pragAprobareRON = 1000.0,
    this.procentDistribuireIntermediara = 70.0,
    this.procentRezervaGarantie = 30.0,
    this.durataGarantieLuni = 24,
    required this.dataInceput,
    this.dataReceptieFinala,
    this.status = AsociereStatus.activa,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
    this.revision = 1,
  });

  final String id;

  /// Referință exclusivă la proiectul independent `lucrari_asociere`.
  final String lucrareAsociereId;

  /// Cine facturează Beneficiarul și încasează (contractant principal) —
  /// determină direcția rambursării la decont. Vezi [AsociereIncasator].
  final AsociereIncasator cineFactureazaBeneficiarul;

  /// Opțional — FK către PartnerRecord.id (lib/features/partners/), dacă
  /// partenerul extern e deja în registrul de parteneri.
  final String partenerExternId;
  final String partenerExternNume;
  final String partenerExternCUI;
  final String partenerExternIBAN;
  final String partenerExternTelefon;
  final double valoareContractuala;
  final String moneda;

  /// Procente cotă profit/pierdere — trebuie să însumeze 100 (validare la
  /// nivel de UI/repository, NU impusă strict în model).
  final double cotaProTerm;
  final double cotaPartener;

  final double pragAprobareRON;
  final double procentDistribuireIntermediara;
  final double procentRezervaGarantie;
  final int durataGarantieLuni;

  final DateTime dataInceput;
  final DateTime? dataReceptieFinala;
  final AsociereStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final int revision;

  /// Data de la care rezerva de garanție devine eligibilă pentru eliberare
  /// (dataReceptieFinala + durataGarantieLuni), sau null dacă recepția
  /// finală nu a fost încă înregistrată.
  DateTime? get dataEligibilaEliberareGarantie {
    final receptie = dataReceptieFinala;
    if (receptie == null) return null;
    return DateTime(
      receptie.year,
      receptie.month + durataGarantieLuni,
      receptie.day,
    );
  }

  AsociereRecord copyWith({
    AsociereIncasator? cineFactureazaBeneficiarul,
    String? partenerExternId,
    String? partenerExternNume,
    String? partenerExternCUI,
    String? partenerExternIBAN,
    String? partenerExternTelefon,
    double? valoareContractuala,
    String? moneda,
    double? cotaProTerm,
    double? cotaPartener,
    double? pragAprobareRON,
    double? procentDistribuireIntermediara,
    double? procentRezervaGarantie,
    int? durataGarantieLuni,
    DateTime? dataInceput,
    Object? dataReceptieFinala = _unset,
    AsociereStatus? status,
    DateTime? updatedAt,
  }) {
    return AsociereRecord(
      id: id,
      lucrareAsociereId: lucrareAsociereId,
      cineFactureazaBeneficiarul:
          cineFactureazaBeneficiarul ?? this.cineFactureazaBeneficiarul,
      partenerExternId: partenerExternId ?? this.partenerExternId,
      partenerExternNume: partenerExternNume ?? this.partenerExternNume,
      partenerExternCUI: partenerExternCUI ?? this.partenerExternCUI,
      partenerExternIBAN: partenerExternIBAN ?? this.partenerExternIBAN,
      partenerExternTelefon:
          partenerExternTelefon ?? this.partenerExternTelefon,
      valoareContractuala: valoareContractuala ?? this.valoareContractuala,
      moneda: moneda ?? this.moneda,
      cotaProTerm: cotaProTerm ?? this.cotaProTerm,
      cotaPartener: cotaPartener ?? this.cotaPartener,
      pragAprobareRON: pragAprobareRON ?? this.pragAprobareRON,
      procentDistribuireIntermediara:
          procentDistribuireIntermediara ?? this.procentDistribuireIntermediara,
      procentRezervaGarantie:
          procentRezervaGarantie ?? this.procentRezervaGarantie,
      durataGarantieLuni: durataGarantieLuni ?? this.durataGarantieLuni,
      dataInceput: dataInceput ?? this.dataInceput,
      dataReceptieFinala: identical(dataReceptieFinala, _unset)
          ? this.dataReceptieFinala
          : dataReceptieFinala as DateTime?,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
      revision: revision,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'lucrare_asociere_id': lucrareAsociereId,
      'cine_factureaza_beneficiarul': cineFactureazaBeneficiarul.value,
      'partener_extern_id': partenerExternId,
      'partener_extern_nume': partenerExternNume,
      'partener_extern_cui': partenerExternCUI,
      'partener_extern_iban': partenerExternIBAN,
      'partener_extern_telefon': partenerExternTelefon,
      'valoare_contractuala': valoareContractuala,
      'moneda': moneda,
      'cota_pro_term': cotaProTerm,
      'cota_partener': cotaPartener,
      'prag_aprobare_ron': pragAprobareRON,
      'procent_distribuire_intermediara': procentDistribuireIntermediara,
      'procent_rezerva_garantie': procentRezervaGarantie,
      'durata_garantie_luni': durataGarantieLuni,
      'data_inceput': dataInceput.toIso8601String(),
      'data_receptie_finala': dataReceptieFinala?.toIso8601String(),
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'revision': revision,
    };
  }

  factory AsociereRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();

    double parseDouble(dynamic raw, double fallback) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? ''}'.replaceAll(',', '.')) ?? fallback;
    }

    int parseInt(dynamic raw, int fallback) {
      if (raw is num) return raw.toInt();
      return int.tryParse('${raw ?? ''}') ?? fallback;
    }

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (map[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return AsociereRecord(
      id: pick(const <String>['id']),
      lucrareAsociereId: pick(
        const <String>['lucrare_asociere_id', 'lucrareAsociereId'],
      ),
      // Backward compat: docs create înainte de introducerea câmpului (modul
      // fără UI încă, fără date în producție) → proTerm, comportamentul
      // istoric implicit. La creare din UI câmpul e obligatoriu (constructor
      // `required`), fără default silențios.
      cineFactureazaBeneficiarul: AsociereIncasator.fromValue(
        (map['cine_factureaza_beneficiarul'] ??
                map['cineFactureazaBeneficiarul'])
            ?.toString(),
      ),
      partenerExternId:
          pick(const <String>['partener_extern_id', 'partenerExternId']),
      partenerExternNume:
          pick(const <String>['partener_extern_nume', 'partenerExternNume']),
      partenerExternCUI:
          pick(const <String>['partener_extern_cui', 'partenerExternCUI']),
      partenerExternIBAN:
          pick(const <String>['partener_extern_iban', 'partenerExternIBAN']),
      partenerExternTelefon: pick(
        const <String>['partener_extern_telefon', 'partenerExternTelefon'],
      ),
      valoareContractuala: parseDouble(
        map['valoare_contractuala'] ?? map['valoareContractuala'],
        0,
      ),
      moneda: pick(const <String>['moneda']).isEmpty
          ? 'RON'
          : pick(const <String>['moneda']).toUpperCase(),
      cotaProTerm: parseDouble(map['cota_pro_term'] ?? map['cotaProTerm'], 0),
      cotaPartener: parseDouble(map['cota_partener'] ?? map['cotaPartener'], 0),
      pragAprobareRON: parseDouble(
        map['prag_aprobare_ron'] ?? map['pragAprobareRON'],
        1000.0,
      ),
      procentDistribuireIntermediara: parseDouble(
        map['procent_distribuire_intermediara'] ??
            map['procentDistribuireIntermediara'],
        70.0,
      ),
      procentRezervaGarantie: parseDouble(
        map['procent_rezerva_garantie'] ?? map['procentRezervaGarantie'],
        30.0,
      ),
      durataGarantieLuni: parseInt(
        map['durata_garantie_luni'] ?? map['durataGarantieLuni'],
        24,
      ),
      dataInceput:
          DateTime.tryParse((map['data_inceput'] ?? '').toString()) ?? now,
      dataReceptieFinala:
          DateTime.tryParse((map['data_receptie_finala'] ?? '').toString()),
      status: AsociereStatus.fromValue(map['status']?.toString()),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? now,
      updatedAt: DateTime.tryParse((map['updated_at'] ?? '').toString()) ?? now,
      createdBy: pick(const <String>['created_by', 'createdBy']),
      updatedBy: pick(const <String>['updated_by', 'updatedBy']),
      revision: parseInt(map['revision'], 1),
    );
  }
}

const Object _unset = Object();
