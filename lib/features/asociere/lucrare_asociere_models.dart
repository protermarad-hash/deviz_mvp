enum LucrareAsociereStatus {
  draft,
  planificare,
  activa,
  suspendata,
  finalizata,
  anulata;

  String get value => name;

  String get label => switch (this) {
        draft => 'Draft',
        planificare => 'Planificare',
        activa => 'Activă',
        suspendata => 'Suspendată',
        finalizata => 'Finalizată',
        anulata => 'Anulată',
      };

  static LucrareAsociereStatus fromValue(Object? raw) {
    final value = '$raw'.trim().toLowerCase();
    return values.firstWhere(
      (item) => item.value == value,
      orElse: () => LucrareAsociereStatus.draft,
    );
  }
}

const monedeAsociereAcceptate = <String>['RON', 'EUR', 'USD', 'GBP', 'HUF'];

class LucrareAsociereRecord {
  const LucrareAsociereRecord({
    required this.id,
    required this.numar,
    required this.denumire,
    this.descriere = '',
    this.clientId = '',
    this.clientNameSnapshot = '',
    this.beneficiar = '',
    this.adresa = '',
    this.localitate = '',
    this.judet = '',
    this.tara = 'România',
    required this.partnerId,
    required this.partnerNameSnapshot,
    this.responsabilId = '',
    this.responsabilNameSnapshot = '',
    this.managerId = '',
    this.managerNameSnapshot = '',
    required this.dataInceput,
    this.termenEstimat,
    this.dataFinalizare,
    this.status = LucrareAsociereStatus.draft,
    this.moneda = 'RON',
    this.valoareContractuala = 0,
    this.cotaProTerm = 50,
    this.cotaPartener = 50,
    this.cineFactureazaBeneficiarul = 'pro_term',
    this.procentDistribuireIntermediara = 70,
    this.procentRezervaGarantie = 30,
    this.durataGarantieLuni = 24,
    this.pragAprobareCost = 1000,
    this.observatii = '',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.updatedBy = '',
    this.revision = 1,
    this.active = true,
    this.arhivat = false,
  });

  final String id;
  final String numar;
  final String denumire;
  final String descriere;
  final String clientId;
  final String clientNameSnapshot;
  final String beneficiar;
  final String adresa;
  final String localitate;
  final String judet;
  final String tara;
  final String partnerId;
  final String partnerNameSnapshot;
  final String responsabilId;
  final String responsabilNameSnapshot;
  final String managerId;
  final String managerNameSnapshot;
  final DateTime dataInceput;
  final DateTime? termenEstimat;
  final DateTime? dataFinalizare;
  final LucrareAsociereStatus status;
  final String moneda;
  final double valoareContractuala;
  final double cotaProTerm;
  final double cotaPartener;
  final String cineFactureazaBeneficiarul;
  final double procentDistribuireIntermediara;
  final double procentRezervaGarantie;
  final int durataGarantieLuni;
  final double pragAprobareCost;
  final String observatii;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final int revision;
  final bool active;
  final bool arhivat;

  bool get esteIntarziata =>
      termenEstimat != null &&
      termenEstimat!.isBefore(DateTime.now()) &&
      status != LucrareAsociereStatus.finalizata &&
      status != LucrareAsociereStatus.anulata;

  double get progres {
    if (status == LucrareAsociereStatus.finalizata) return 1;
    if (status == LucrareAsociereStatus.activa) return .5;
    if (status == LucrareAsociereStatus.planificare) return .2;
    return 0;
  }

  List<String> validate() {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('ID-ul este obligatoriu.');
    if (numar.trim().isEmpty) errors.add('Numărul este obligatoriu.');
    if (denumire.trim().isEmpty) errors.add('Denumirea este obligatorie.');
    if (partnerId.trim().isEmpty || partnerNameSnapshot.trim().isEmpty) {
      errors.add('Partenerul este obligatoriu.');
    }
    for (final value in <double>[
      cotaProTerm,
      cotaPartener,
      procentDistribuireIntermediara,
      procentRezervaGarantie,
    ]) {
      if (!value.isFinite || value < 0 || value > 100) {
        errors.add('Procentele trebuie să fie între 0 și 100.');
        break;
      }
    }
    if ((cotaProTerm + cotaPartener - 100).abs() > .001) {
      errors.add('Cotele PRO TERM și Partener trebuie să însumeze 100%.');
    }
    if (!valoareContractuala.isFinite || valoareContractuala < 0) {
      errors.add('Valoarea contractuală trebuie să fie nenegativă.');
    }
    if (!pragAprobareCost.isFinite || pragAprobareCost < 0) {
      errors.add('Pragul de aprobare trebuie să fie nenegativ.');
    }
    if (durataGarantieLuni < 0) errors.add('Durata garanției este invalidă.');
    if (!monedeAsociereAcceptate.contains(moneda.toUpperCase())) {
      errors.add('Moneda nu este acceptată.');
    }
    if (termenEstimat != null && termenEstimat!.isBefore(dataInceput)) {
      errors.add('Termenul estimat nu poate preceda data de început.');
    }
    if (dataFinalizare != null && dataFinalizare!.isBefore(dataInceput)) {
      errors.add('Data finalizării nu poate preceda data de început.');
    }
    if (!const {'pro_term', 'partener'}.contains(cineFactureazaBeneficiarul)) {
      errors.add('Emitentul facturii este invalid.');
    }
    return errors;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'numar': numar,
        'denumire': denumire,
        'descriere': descriere,
        'client_id': clientId,
        'client_name_snapshot': clientNameSnapshot,
        'beneficiar': beneficiar,
        'adresa': adresa,
        'localitate': localitate,
        'judet': judet,
        'tara': tara,
        'partner_id': partnerId,
        'partner_name_snapshot': partnerNameSnapshot,
        'responsabil_id': responsabilId,
        'responsabil_name_snapshot': responsabilNameSnapshot,
        'manager_id': managerId,
        'manager_name_snapshot': managerNameSnapshot,
        'data_inceput': dataInceput.toIso8601String(),
        'termen_estimat': termenEstimat?.toIso8601String(),
        'data_finalizare': dataFinalizare?.toIso8601String(),
        'status': status.value,
        'moneda': moneda.toUpperCase(),
        'valoare_contractuala': valoareContractuala,
        'cota_pro_term': cotaProTerm,
        'cota_partener': cotaPartener,
        'cine_factureaza_beneficiarul': cineFactureazaBeneficiarul,
        'procent_distribuire_intermediara': procentDistribuireIntermediara,
        'procent_rezerva_garantie': procentRezervaGarantie,
        'durata_garantie_luni': durataGarantieLuni,
        'prag_aprobare_cost': pragAprobareCost,
        'observatii': observatii,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
        'updated_by': updatedBy,
        'revision': revision,
        'active': active,
        'arhivat': arhivat,
      };

  factory LucrareAsociereRecord.fromMap(Map<String, dynamic> map) {
    String text(String snake, [String? camel]) =>
        (map[snake] ?? (camel == null ? null : map[camel]) ?? '').toString();
    double number(String snake, [String? camel, double fallback = 0]) {
      final raw = map[snake] ?? (camel == null ? null : map[camel]);
      if (raw is num) return raw.toDouble();
      return double.tryParse('$raw'.replaceAll(',', '.')) ?? fallback;
    }

    int integer(String snake, [String? camel, int fallback = 0]) {
      final raw = map[snake] ?? (camel == null ? null : map[camel]);
      if (raw is num) return raw.toInt();
      return int.tryParse('$raw') ?? fallback;
    }

    DateTime? date(String snake, [String? camel]) =>
        DateTime.tryParse(text(snake, camel));
    bool flag(String snake, String camel, bool fallback) {
      final raw = map[snake] ?? map[camel];
      if (raw is bool) return raw;
      if (raw == null) return fallback;
      return '$raw'.toLowerCase() == 'true' || '$raw' == '1';
    }

    final now = DateTime.now();
    return LucrareAsociereRecord(
      id: text('id'),
      numar: text('numar'),
      denumire: text('denumire'),
      descriere: text('descriere'),
      clientId: text('client_id', 'clientId'),
      clientNameSnapshot: text('client_name_snapshot', 'clientNameSnapshot'),
      beneficiar: text('beneficiar'),
      adresa: text('adresa'),
      localitate: text('localitate'),
      judet: text('judet'),
      tara: text('tara').trim().isEmpty ? 'România' : text('tara').trim(),
      partnerId: text('partner_id', 'partnerId'),
      partnerNameSnapshot: text('partner_name_snapshot', 'partnerNameSnapshot'),
      responsabilId: text('responsabil_id', 'responsabilId'),
      responsabilNameSnapshot:
          text('responsabil_name_snapshot', 'responsabilNameSnapshot'),
      managerId: text('manager_id', 'managerId'),
      managerNameSnapshot: text('manager_name_snapshot', 'managerNameSnapshot'),
      dataInceput: date('data_inceput', 'dataInceput') ?? now,
      termenEstimat: date('termen_estimat', 'termenEstimat'),
      dataFinalizare: date('data_finalizare', 'dataFinalizare'),
      status: LucrareAsociereStatus.fromValue(map['status']),
      moneda:
          text('moneda').trim().isEmpty ? 'RON' : text('moneda').toUpperCase(),
      valoareContractuala:
          number('valoare_contractuala', 'valoareContractuala'),
      cotaProTerm: number('cota_pro_term', 'cotaProTerm', 50),
      cotaPartener: number('cota_partener', 'cotaPartener', 50),
      cineFactureazaBeneficiarul: text(
                  'cine_factureaza_beneficiarul', 'cineFactureazaBeneficiarul')
              .trim()
              .isEmpty
          ? 'pro_term'
          : text('cine_factureaza_beneficiarul', 'cineFactureazaBeneficiarul'),
      procentDistribuireIntermediara: number('procent_distribuire_intermediara',
          'procentDistribuireIntermediara', 70),
      procentRezervaGarantie:
          number('procent_rezerva_garantie', 'procentRezervaGarantie', 30),
      durataGarantieLuni:
          integer('durata_garantie_luni', 'durataGarantieLuni', 24),
      pragAprobareCost: number('prag_aprobare_cost', 'pragAprobareCost', 1000),
      observatii: text('observatii'),
      createdAt: date('created_at', 'createdAt') ?? now,
      updatedAt: date('updated_at', 'updatedAt') ?? now,
      createdBy: text('created_by', 'createdBy'),
      updatedBy: text('updated_by', 'updatedBy'),
      revision: integer('revision', null, 1),
      active: flag('active', 'active', true),
      arhivat: flag('arhivat', 'arhivat', false),
    );
  }
}
