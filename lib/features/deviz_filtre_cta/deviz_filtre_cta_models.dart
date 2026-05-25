import 'package:cloud_firestore/cloud_firestore.dart';

// ── Zonă CTA (pentru subtotaluri) ────────────────────────────────────────────

enum ZonaCta {
  turnatorii,
  spumatorie,
  cusatorii,
  logistica,
  altele;

  String get value => name;

  String get label {
    switch (this) {
      case ZonaCta.turnatorii:
        return 'Turnătorii';
      case ZonaCta.spumatorie:
        return 'Spumătorie';
      case ZonaCta.cusatorii:
        return 'Cusătorii';
      case ZonaCta.logistica:
        return 'Logistică și laboratoare';
      case ZonaCta.altele:
        return 'Altele';
    }
  }

  static ZonaCta fromValue(String? raw) {
    switch (raw) {
      case 'turnatorii':
        return ZonaCta.turnatorii;
      case 'spumatorie':
        return ZonaCta.spumatorie;
      case 'cusatorii':
        return ZonaCta.cusatorii;
      case 'logistica':
        return ZonaCta.logistica;
      default:
        return ZonaCta.altele;
    }
  }
}

// ── Filtru per poziție (Introducere / Evacuare / Metalice) ───────────────────

class CtaFiltru {
  const CtaFiltru({
    required this.pozitie,
    required this.marimi,
    required this.pret,
  });

  /// 'introducere' | 'evacuare' | 'metalice' | text liber
  final String pozitie;
  final List<String> marimi;

  /// Preț manoperă în euro pentru această poziție — editabil 1-2x/an
  final double pret;

  CtaFiltru copyWith({
    String? pozitie,
    List<String>? marimi,
    double? pret,
  }) =>
      CtaFiltru(
        pozitie: pozitie ?? this.pozitie,
        marimi: marimi ?? this.marimi,
        pret: pret ?? this.pret,
      );

  Map<String, dynamic> toMap() => {
        'pozitie': pozitie,
        'marimi': marimi,
        'pret': pret,
      };

  factory CtaFiltru.fromMap(Map<String, dynamic> m) => CtaFiltru(
        pozitie: (m['pozitie'] ?? 'introducere').toString(),
        marimi: (m['marimi'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        pret: _d(m['pret']),
      );

  static double _d(dynamic v) =>
      v == null ? 0 : double.tryParse(v.toString()) ?? 0;
}

// ── O unitate CTA cu filtrele sale ───────────────────────────────────────────

class CtaEntry {
  const CtaEntry({
    required this.id,
    required this.nrCrt,
    required this.denumireCta,
    this.serie = '',
    this.locatie = '',
    required this.zona,
    this.filtre = const [],
  });

  final String id;
  final int nrCrt;
  final String denumireCta;
  final String serie;
  final String locatie;
  final ZonaCta zona;

  /// Lista de poziții cu filtre și prețuri individuale
  final List<CtaFiltru> filtre;

  /// Totalul manoperei pentru acest CTA (suma tuturor pozițiilor)
  double get totalPret => filtre.fold(0, (s, f) => s + f.pret);

  CtaEntry copyWith({
    int? nrCrt,
    String? denumireCta,
    String? serie,
    String? locatie,
    ZonaCta? zona,
    List<CtaFiltru>? filtre,
  }) =>
      CtaEntry(
        id: id,
        nrCrt: nrCrt ?? this.nrCrt,
        denumireCta: denumireCta ?? this.denumireCta,
        serie: serie ?? this.serie,
        locatie: locatie ?? this.locatie,
        zona: zona ?? this.zona,
        filtre: filtre ?? this.filtre,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'nr_crt': nrCrt,
        'denumire_cta': denumireCta,
        'serie': serie,
        'locatie': locatie,
        'zona': zona.value,
        'filtre': filtre.map((f) => f.toMap()).toList(),
      };

  factory CtaEntry.fromMap(Map<String, dynamic> m) => CtaEntry(
        id: (m['id'] ?? '').toString(),
        nrCrt: int.tryParse((m['nr_crt'] ?? 0).toString()) ?? 0,
        denumireCta: (m['denumire_cta'] ?? '').toString(),
        serie: (m['serie'] ?? '').toString(),
        locatie: (m['locatie'] ?? '').toString(),
        zona: ZonaCta.fromValue(m['zona']?.toString()),
        filtre: (m['filtre'] as List?)
                ?.map((e) =>
                    CtaFiltru.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
      );
}

// ── Documentul principal deviz filtre CTA ────────────────────────────────────

class DevizFiltreCta {
  const DevizFiltreCta({
    required this.id,
    this.titluDeviz = '',
    this.anDeviz = '',
    this.clientId = '',
    this.clientName = '',
    this.numar = '',
    this.moneda = 'EUR',
    this.inclusivaOnorariu = false,
    this.note = '',
    this.intocmitDe = '',
    this.ctas = const [],
    required this.dataEmitere,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String titluDeviz;
  final String anDeviz;
  final String clientId;
  final String clientName;
  final String numar;
  final String moneda;
  final bool inclusivaOnorariu;
  final String note;
  final String intocmitDe;
  final List<CtaEntry> ctas;
  final DateTime dataEmitere;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Totaluri pe zone ─────────────────────────────────────────────
  double _totalZona(ZonaCta zona) => ctas
      .where((c) => c.zona == zona)
      .fold(0, (s, c) => s + c.totalPret);

  double get totalTurnatorii => _totalZona(ZonaCta.turnatorii);
  double get totalSpumatorie => _totalZona(ZonaCta.spumatorie);
  double get totalCusatorii => _totalZona(ZonaCta.cusatorii);
  double get totalLogistica => _totalZona(ZonaCta.logistica);
  double get totalAltele => _totalZona(ZonaCta.altele);
  double get totalGeneral =>
      ctas.fold(0, (s, c) => s + c.totalPret);

  DevizFiltreCta copyWith({
    String? titluDeviz,
    String? anDeviz,
    String? clientId,
    String? clientName,
    String? numar,
    String? moneda,
    bool? inclusivaOnorariu,
    String? note,
    String? intocmitDe,
    List<CtaEntry>? ctas,
    DateTime? dataEmitere,
    DateTime? updatedAt,
  }) =>
      DevizFiltreCta(
        id: id,
        titluDeviz: titluDeviz ?? this.titluDeviz,
        anDeviz: anDeviz ?? this.anDeviz,
        clientId: clientId ?? this.clientId,
        clientName: clientName ?? this.clientName,
        numar: numar ?? this.numar,
        moneda: moneda ?? this.moneda,
        inclusivaOnorariu: inclusivaOnorariu ?? this.inclusivaOnorariu,
        note: note ?? this.note,
        intocmitDe: intocmitDe ?? this.intocmitDe,
        ctas: ctas ?? this.ctas,
        dataEmitere: dataEmitere ?? this.dataEmitere,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'titlu_deviz': titluDeviz,
        'an_deviz': anDeviz,
        'client_id': clientId,
        'client_name': clientName,
        'numar': numar,
        'moneda': moneda,
        'inclusiva_onorariu': inclusivaOnorariu,
        'note': note,
        'intocmit_de': intocmitDe,
        'ctas': ctas.map((c) => c.toMap()).toList(),
        'data_emitere': dataEmitere.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory DevizFiltreCta.fromMap(Map<String, dynamic> m) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    return DevizFiltreCta(
      id: (m['id'] ?? '').toString(),
      titluDeviz: (m['titlu_deviz'] ?? '').toString(),
      anDeviz: (m['an_deviz'] ?? '').toString(),
      clientId: (m['client_id'] ?? '').toString(),
      clientName: (m['client_name'] ?? '').toString(),
      numar: (m['numar'] ?? '').toString(),
      moneda: (m['moneda'] ?? 'EUR').toString(),
      inclusivaOnorariu: m['inclusiva_onorariu'] == true,
      note: (m['note'] ?? '').toString(),
      intocmitDe: (m['intocmit_de'] ?? '').toString(),
      ctas: (m['ctas'] as List?)
              ?.map((e) =>
                  CtaEntry.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      dataEmitere: parseDate(m['data_emitere']),
      createdAt: parseDate(m['created_at']),
      updatedAt: parseDate(m['updated_at']),
    );
  }
}

// ── Template CTA-uri implicite din Excel ─────────────────────────────────────

/// Returnează lista completă de CTA-uri conform modelului Excel
/// 2026-Oferta_Pro_Term-Shimbat_filtre_CTA-uri.xlsx
List<CtaEntry> ctaTemplateImplicit() {
  int idCounter = 0;
  String uid() => 'cta-template-${++idCounter}';

  return [
    // ── TURNĂTORII ──────────────────────────────────────────────────────────
    CtaEntry(
      id: uid(),
      nrCrt: 1,
      denumireCta: 'CTA 84000 T1 Tip ATP 50.40 AVBV',
      serie: 'GEA / SN:0764.438304.0010 / An.F 10/2002',
      locatie: 'Turnătorie1 (T1)',
      zona: ZonaCta.turnatorii,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592 X 592 X 450/8', '592 X 287 X 450/4', '287 X 287 X 450/4'],
          pret: 426,
        ),
        CtaFiltru(
          pozitie: 'Evacuare',
          marimi: ['592 X 592 X 450/8', '592 X 287 X 450/4', '287 X 287 X 450/4'],
          pret: 426,
        ),
        CtaFiltru(
          pozitie: 'Filtre metalice evacuare',
          marimi: [],
          pret: 185,
        ),
      ],
    ),
    CtaEntry(
      id: uid(),
      nrCrt: 2,
      denumireCta: 'CTA 60000T2 TYP RZ24/27 ROBATERM',
      serie: 'MAGNEZIU / ORDER NO 81271.1 / An.F.40/2010',
      locatie: 'Turnătorie2 (TR2)',
      zona: ZonaCta.turnatorii,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592X592X450/8', '592X287X450/4'],
          pret: 426,
        ),
        CtaFiltru(
          pozitie: 'Evacuare',
          marimi: ['592X592X450/8', '592X287X450/4'],
          pret: 426,
        ),
        CtaFiltru(
          pozitie: 'Filtre metalice evacuare',
          marimi: [],
          pret: 220,
        ),
      ],
    ),
    CtaEntry(
      id: uid(),
      nrCrt: 3,
      denumireCta: 'CTA 80000mc/h TYP RL27/32 ROBATERM',
      serie: 'SN 85057.0 TP5T600AN-0',
      locatie: 'Turnătorie T1 / MAGNEZIU',
      zona: ZonaCta.turnatorii,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['591X592X450/8', '591X287X450/4'],
          pret: 489,
        ),
        CtaFiltru(
          pozitie: 'Evacuare (secțiunea 1)',
          marimi: ['591X592X450/8'],
          pret: 675.37,
        ),
        CtaFiltru(
          pozitie: 'Evacuare (secțiunea 2)',
          marimi: ['591X287X450/4'],
          pret: 489,
        ),
        CtaFiltru(
          pozitie: 'Evacuare (secțiunea 3)',
          marimi: ['591X592X450/8'],
          pret: 588.63,
        ),
        CtaFiltru(
          pozitie: 'Evacuare (secțiunea 4)',
          marimi: ['591X287X450/4'],
          pret: 545.26,
        ),
        CtaFiltru(
          pozitie: 'Filtre metalice',
          marimi: ['592x592', '592x287'],
          pret: 366,
        ),
      ],
    ),
    CtaEntry(
      id: uid(),
      nrCrt: 4,
      denumireCta: 'CTA 80000mc/h TYP RL27/33 ROBATERM',
      serie: 'SN 85057.1 TP5T600AN-1',
      locatie: 'Turnătorie AL / ALUMINIU',
      zona: ZonaCta.turnatorii,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592X592X450/8', '592X287X450/4'],
          pret: 426,
        ),
        CtaFiltru(
          pozitie: 'Evacuare',
          marimi: ['592X592X450/8', '592X287X450/4'],
          pret: 426,
        ),
        CtaFiltru(
          pozitie: 'Filtre metalice',
          marimi: ['592x592', '592x287'],
          pret: 220,
        ),
      ],
    ),

    // ── SPUMĂTORIE ──────────────────────────────────────────────────────────
    CtaEntry(
      id: uid(),
      nrCrt: 5,
      denumireCta: 'CTA.18000 M.S. SCHELETI FAST FM194',
      serie: 'LP8313865',
      locatie: 'Scheleți Volane',
      zona: ZonaCta.spumatorie,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592X592X450/8', '592X287X450/4'],
          pret: 69,
        ),
      ],
    ),
    CtaEntry(
      id: uid(),
      nrCrt: 6,
      denumireCta: 'CTA 40000 Sp.1 Tip ATP 35.30 AVBV',
      serie: 'GEA / SN: 0784.438304.0020',
      locatie: 'Spumătorie (T2)',
      zona: ZonaCta.spumatorie,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592X592X450/8', '592X287X450/4', '287x287X450/4'],
          pret: 209,
        ),
      ],
    ),
    CtaEntry(
      id: uid(),
      nrCrt: 7,
      denumireCta: 'CTA 40000 Sp.2 Tip ATP 35.30 AVBV',
      serie: 'GEA / SN: 0784.438304.0020',
      locatie: 'Spumătorie (T3)',
      zona: ZonaCta.spumatorie,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592X592X450/8', '592X287X450/4', '287x287X450/4'],
          pret: 209,
        ),
      ],
    ),
    CtaEntry(
      id: uid(),
      nrCrt: 8,
      denumireCta: 'CTA 60000 SPUMATORIE 3 TYPE RL 24/24 ROBATERM',
      serie: '',
      locatie: 'SPUMĂTORIE (S3)',
      zona: ZonaCta.spumatorie,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592X592X450/8'],
          pret: 262,
        ),
      ],
    ),

    // ── CUSĂTORII ───────────────────────────────────────────────────────────
    CtaEntry(
      id: uid(),
      nrCrt: 9,
      denumireCta: 'CTA 40000MC/H Hala producție',
      serie: '',
      locatie: 'Corp Legătură (AGAȘI)',
      zona: ZonaCta.cusatorii,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592x592x360', '287x592x360', '592x592x534', '287x592x534'],
          pret: 262,
        ),
        CtaFiltru(
          pozitie: 'Evacuare',
          marimi: ['592x592x534', '287x592x534'],
          pret: 227,
        ),
      ],
    ),
    CtaEntry(
      id: uid(),
      nrCrt: 10,
      denumireCta: 'CTA 60000 C1 Tip ATP 50.30 AVBV',
      serie: 'GEA / SN: 0761.448156.0120 / An.F 10/2003',
      locatie: 'Cusătorie1 (C1)',
      zona: ZonaCta.cusatorii,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592X592X450/8', '592X287X450/4', '287X287X450/4'],
          pret: 366,
        ),
        CtaFiltru(
          pozitie: 'Evacuare',
          marimi: ['592X592X450/8', '592X287X450/4', '287X287X450/4'],
          pret: 0,
        ),
      ],
    ),
    CtaEntry(
      id: uid(),
      nrCrt: 11,
      denumireCta: 'CTA 60000 C4 Tip ATP 50.30 AVBV',
      serie: 'GEA / SN: 0761.456102.0030 / An.F 9/2004',
      locatie: 'Cusătorie2 (C4)',
      zona: ZonaCta.cusatorii,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592X592X450/8', '592X287X450/4', '287X287X450/4'],
          pret: 366,
        ),
        CtaFiltru(
          pozitie: 'Evacuare',
          marimi: ['592X592X450/8', '592X287X450/4', '287X287X450/4'],
          pret: 0,
        ),
      ],
    ),
    CtaEntry(
      id: uid(),
      nrCrt: 12,
      denumireCta: 'CTA 11500 Tip UTK 33 = 4 BUC Cusătorii',
      serie: '',
      locatie: 'Cusătorii 1+2 / tubulatura textilă',
      zona: ZonaCta.cusatorii,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592X592X360/6', '490X592X360/6'],
          pret: 489,
        ),
      ],
    ),
    CtaEntry(
      id: uid(),
      nrCrt: 13,
      denumireCta: 'CTA Cus extindere',
      serie: '',
      locatie: 'C3, C5',
      zona: ZonaCta.cusatorii,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592x592x360', '287x592x360', '592x592x534', '287x592x534'],
          pret: 152,
        ),
        CtaFiltru(
          pozitie: 'Evacuare',
          marimi: ['592x592x534', '287x592x534'],
          pret: 110,
        ),
      ],
    ),

    // ── LOGISTICĂ ────────────────────────────────────────────────────────────
    CtaEntry(
      id: uid(),
      nrCrt: 14,
      denumireCta: 'CTA 6000 DEP CLEI ȘI DILUANT FAST FM69',
      serie: 'FM69 / LP8312751',
      locatie: 'Depozit Lacuri',
      zona: ZonaCta.logistica,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592X490X450/8', '592X287X450/4'],
          pret: 69,
        ),
      ],
    ),
    CtaEntry(
      id: uid(),
      nrCrt: 15,
      denumireCta: 'DEP.LOGISTICĂ CTA CAIR-PLUS 7000/6000MC/H GEA',
      serie: 'SN7020611019059 / 0100/3.2012 / 096096IVVV',
      locatie: 'LABORATOR',
      zona: ZonaCta.logistica,
      filtre: const [
        CtaFiltru(
          pozitie: 'Introducere',
          marimi: ['592x592x450/8', '592X287X450/4', '287X287X450/4'],
          pret: 105.5,
        ),
        CtaFiltru(
          pozitie: 'Evacuare',
          marimi: ['592x592x450/8', '592X287X450/4', '287X287X450/4'],
          pret: 105.5,
        ),
      ],
    ),
  ];
}
