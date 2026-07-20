enum AsociereRambursareCatre {
  proTerm,
  partener,
  niciunul;

  String get value {
    switch (this) {
      case AsociereRambursareCatre.proTerm:
        return 'pro_term';
      case AsociereRambursareCatre.partener:
        return 'partener';
      case AsociereRambursareCatre.niciunul:
        return 'niciunul';
    }
  }

  static AsociereRambursareCatre fromValue(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'pro_term':
        return AsociereRambursareCatre.proTerm;
      case 'partener':
        return AsociereRambursareCatre.partener;
      case 'niciunul':
      default:
        return AsociereRambursareCatre.niciunul;
    }
  }
}

enum DecontLunarStatus {
  draft,
  confirmat;

  String get value => this == DecontLunarStatus.confirmat ? 'confirmat' : 'draft';

  String get label => this == DecontLunarStatus.confirmat ? 'Confirmat' : 'Draft';

  static DecontLunarStatus fromValue(String? raw) {
    return (raw ?? '').trim().toLowerCase() == 'confirmat'
        ? DecontLunarStatus.confirmat
        : DecontLunarStatus.draft;
  }
}

/// Decont lunar generat pentru o Asociere — calculat, NU introdus manual
/// (vezi DecontLunarAsociereRepository.genereazaDecontPentruLuna).
///
/// Câmpuri ADĂUGATE față de spec, pentru a implementa decizia confirmată
/// privind rezerva de garanție (reținută din rambursarea CĂTRE partener,
/// nu din cea către PRO TERM):
///   - sumaRezervaRetinuta: partea din sumaRambursare reținută ca garanție
///     (procentRezervaGarantie% din AsociereRecord, DOAR când
///     rambursareDatorataCatre == partener; altfel 0).
///   - sumaDeAchitatAcum: sumaRambursare - sumaRezervaRetinuta — suma
///     efectiv de plătit în luna curentă (restul de
///     procentDistribuireIntermediara%, tipic 70%).
/// Eliberarea rezervei cumulate (după dataReceptieFinala + durataGarantieLuni)
/// NU e implementată încă — spec-ul nu are un loc de evidență a rezervei
/// cumulate pe toată durata asocierii; rămâne de adăugat separat dacă e nevoie
/// (vezi raport).
class DecontLunarAsociereRecord {
  const DecontLunarAsociereRecord({
    required this.id,
    required this.asociereId,
    required this.luna,
    required this.an,
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
    this.status = DecontLunarStatus.draft,
    required this.dataGenerare,
  });

  final String id;
  final String asociereId;

  /// 1-12.
  final int luna;
  final int an;

  final double veniturIncasatTotal;
  final double costRecunoscutProTerm;
  final double costRecunoscutPartener;

  /// = veniturIncasatTotal - (costRecunoscutProTerm + costRecunoscutPartener).
  /// Poate fi negativ.
  final double rezultat;

  final AsociereRambursareCatre rambursareDatorataCatre;

  /// Componentele separate ale settle-up-ului (auditabile), din perspectiva
  /// părții care NU încasează (primitorul):
  /// - [rambursareCosturi]: costul recunoscut suportat de primitor, rambursat
  ///   INTEGRAL și prompt, FĂRĂ reținere de rezervă (≥ 0).
  /// - [distribuireProfitImediata]: cota primitorului din `rezultat` ce se
  ///   distribuie ACUM. Dacă profitul e pozitiv → doar partea de plătit imediat
  ///   (rezerva e scoasă în [sumaRezervaRetinuta]); dacă `rezultat` e negativ
  ///   (pierdere) → toată cota de pierdere se scade acum (valoare negativă,
  ///   fără rezervă — nu există profit din care să reții garanție).
  final double rambursareCosturi;
  final double distribuireProfitImediata;

  final double sumaRambursare;
  final double sumaRezervaRetinuta;
  final double sumaDeAchitatAcum;
  final DecontLunarStatus status;
  final DateTime dataGenerare;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'asociere_id': asociereId,
      'luna': luna,
      'an': an,
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
      'status': status.value,
      'data_generare': dataGenerare.toIso8601String(),
    };
  }

  factory DecontLunarAsociereRecord.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();

    double parseDouble(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('${raw ?? '0'}'.replaceAll(',', '.')) ?? 0;
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

    return DecontLunarAsociereRecord(
      id: pick(const <String>['id']),
      asociereId: pick(const <String>['asociere_id', 'asociereId']),
      luna: parseInt(map['luna'], now.month),
      an: parseInt(map['an'], now.year),
      veniturIncasatTotal: parseDouble(
        map['venituri_incasat_total'] ?? map['veniturIncasatTotal'],
      ),
      costRecunoscutProTerm: parseDouble(
        map['cost_recunoscut_pro_term'] ?? map['costRecunoscutProTerm'],
      ),
      costRecunoscutPartener: parseDouble(
        map['cost_recunoscut_partener'] ?? map['costRecunoscutPartener'],
      ),
      rezultat: parseDouble(map['rezultat']),
      rambursareDatorataCatre: AsociereRambursareCatre.fromValue(
        map['rambursare_datorata_catre']?.toString(),
      ),
      rambursareCosturi: parseDouble(
        map['rambursare_costuri'] ?? map['rambursareCosturi'],
      ),
      distribuireProfitImediata: parseDouble(
        map['distribuire_profit_imediata'] ?? map['distribuireProfitImediata'],
      ),
      sumaRambursare:
          parseDouble(map['suma_rambursare'] ?? map['sumaRambursare']),
      sumaRezervaRetinuta: parseDouble(
        map['suma_rezerva_retinuta'] ?? map['sumaRezervaRetinuta'],
      ),
      sumaDeAchitatAcum: parseDouble(
        map['suma_de_achitat_acum'] ?? map['sumaDeAchitatAcum'],
      ),
      status: DecontLunarStatus.fromValue(map['status']?.toString()),
      dataGenerare:
          DateTime.tryParse((map['data_generare'] ?? '').toString()) ?? now,
    );
  }
}
