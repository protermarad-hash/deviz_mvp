import 'asociere_models.dart';
import 'cost_asociere_models.dart';
import 'decont_lunar_asociere_models.dart';

/// Rezultatul pur al calculului de settle-up pentru un decont lunar de
/// asociere — fără dependențe de I/O (SharedPreferences/Firestore), ca să
/// poată fi testat determinist. Repository-ul agregă datele lunii și apoi
/// apelează [calculeazaDecontSettleUp] cu totalurile.
///
/// Componentele sunt separate ca fluxuri distincte (PROBLEMA 1): rambursarea
/// costurilor e integrală și promptă; DOAR distribuirea profitului e supusă
/// split-ului cu rezervă de garanție.
class AsociereDecontSettleUp {
  const AsociereDecontSettleUp({
    required this.rezultat,
    required this.rambursareDatorataCatre,
    required this.rambursareCosturi,
    required this.distribuireProfitImediata,
    required this.sumaRambursare,
    required this.sumaRezervaRetinuta,
    required this.sumaDeAchitatAcum,
  });

  /// venituri − (costPT + costPartener). Poate fi negativ (pierdere).
  final double rezultat;
  final AsociereRambursareCatre rambursareDatorataCatre;

  /// (a) Costul recunoscut suportat de primitor (partea care NU încasează),
  /// rambursat INTEGRAL, fără reținere de rezervă. Mereu ≥ 0.
  final double rambursareCosturi;

  /// (b) Cota primitorului din `rezultat`, distribuită ACUM. Dacă rezultatul e
  /// profit → partea de 70% (rezerva de 30% e în [sumaRezervaRetinuta]); dacă e
  /// pierdere → toată cota de pierdere (negativă, fără rezervă).
  final double distribuireProfitImediata;

  /// Valoarea absolută a obligației totale înainte de reținerea rezervei
  /// (= |rambursareCosturi + cota totală din rezultat|).
  final double sumaRambursare;

  /// Rezerva de garanție reținută — DOAR din profitul pozitiv (30%), niciodată
  /// din rambursarea costurilor sau din pierdere.
  final double sumaRezervaRetinuta;

  /// Suma efectiv de plătit acum = sumaRambursare − rezervă (valoare absolută).
  final double sumaDeAchitatAcum;
}

/// Calculează settle-up-ul unui decont lunar de asociere, plecând de la
/// totalurile deja agregate pentru lună.
///
/// DIRECȚIA rambursării depinde de cine facturează Beneficiarul și încasează
/// veniturile (contractantul principal, [incasator]): partea care încasează
/// deține numerarul; „primitorul" = partea care NU încasează.
///   rezultat = veniturIncasatTotal − (costPT + costPartener)
///
/// Cele două fluxuri sunt calculate SEPARAT (PROBLEMA 1):
///   (a) rambursareCosturi = costul recunoscut al primitorului — integral,
///       fără rezervă.
///   (b) cotaProfitPrimitor = (cotaPrimitor/100) × rezultat.
///       - dacă rezultat > 0 (profit): se reține rezerva de garanție
///         (procentRezervaGarantie%) DOAR din (b); restul e
///         distribuireProfitImediata.
///       - dacă rezultat ≤ 0 (pierdere): NU există profit din care să reții
///         garanție → rezervă = 0; toată cota de pierdere (negativă) se scade
///         acum (distribuireProfitImediata = cotaProfitPrimitor, negativă).
///
/// Obligația totală (semnată, către primitor) = rambursareCosturi +
/// cotaProfitPrimitor. Semnul ei dă direcția:
///   > 0 → încasatorul datorează primitorului (bani către primitor)
///   < 0 → primitorul datorează încasatorului (bani către încasator)
///   ≈ 0 → nimeni
/// Formula e simetrică pentru ambele valori ale [incasator].
///
/// Toate valorile de ieșire sunt rotunjite la 2 zecimale.
AsociereDecontSettleUp calculeazaDecontSettleUp({
  required double veniturIncasatTotal,
  required double costRecunoscutProTerm,
  required double costRecunoscutPartener,
  required double cotaProTerm,
  required double cotaPartener,
  required AsociereIncasator incasator,
  required double procentRezervaGarantie,
}) {
  double round2(double v) => (v * 100).roundToDouble() / 100.0;

  final rezultat =
      veniturIncasatTotal - (costRecunoscutProTerm + costRecunoscutPartener);

  // Primitorul = partea care NU încasează (cea care poate primi rambursare).
  final incasatorEProTerm = incasator == AsociereIncasator.proTerm;
  final costPrimitor =
      incasatorEProTerm ? costRecunoscutPartener : costRecunoscutProTerm;
  final cotaPrimitor = incasatorEProTerm ? cotaPartener : cotaProTerm;
  final primitor = incasatorEProTerm
      ? AsociereRambursareCatre.partener
      : AsociereRambursareCatre.proTerm;
  final catreIncasator = incasatorEProTerm
      ? AsociereRambursareCatre.proTerm
      : AsociereRambursareCatre.partener;

  // (a) Rambursare costuri — integral, fără rezervă.
  final rambursareCosturi = costPrimitor;

  // (b) Cota primitorului din rezultat + rezervă DOAR pe profit pozitiv.
  final cotaProfitPrimitor = (cotaPrimitor / 100.0) * rezultat;
  double rezervaRetinuta;
  double distribuireProfitImediata;
  if (cotaProfitPrimitor > 0) {
    // Profit: 30% rezervă, restul (70%) imediat.
    rezervaRetinuta = cotaProfitPrimitor * (procentRezervaGarantie / 100.0);
    distribuireProfitImediata = cotaProfitPrimitor - rezervaRetinuta;
  } else {
    // Pierdere (sau zero): nicio rezervă; toată cota se scade acum.
    rezervaRetinuta = 0;
    distribuireProfitImediata = cotaProfitPrimitor;
  }

  // Obligația totală (semnată, către primitor), înainte de reținerea rezervei.
  final totalInainteRezerva = rambursareCosturi + cotaProfitPrimitor;
  // Suma efectiv de mișcat acum (semnată, către primitor) — rezerva rămâne la
  // încasator.
  final deAchitatAcumSemnat = rambursareCosturi + distribuireProfitImediata;

  AsociereRambursareCatre catre;
  if (totalInainteRezerva > 0.005) {
    catre = primitor; // bani către primitor
  } else if (totalInainteRezerva < -0.005) {
    catre = catreIncasator; // bani către încasator
  } else {
    catre = AsociereRambursareCatre.niciunul;
  }

  return AsociereDecontSettleUp(
    rezultat: round2(rezultat),
    rambursareDatorataCatre: catre,
    rambursareCosturi: round2(rambursareCosturi),
    distribuireProfitImediata: round2(distribuireProfitImediata),
    sumaRambursare: round2(totalInainteRezerva.abs()),
    sumaRezervaRetinuta: round2(rezervaRetinuta),
    sumaDeAchitatAcum: round2(deAchitatAcumSemnat.abs()),
  );
}

/// Costurile care BLOCHEAZĂ generarea decontului pentru (luna, an): costuri
/// care APARȚIN lunii decontului (după [CostAsociereRecord.dataApartenentaLuna]
/// — aceeași regulă folosită și la recunoaștere, PROBLEMA 2) care necesită
/// aprobare și nu au aprobarea completă (proTerm ȘI partener). Un decont
/// generat cu astfel de costuri ar fi incomplet/incorect — de aceea se
/// blochează până la aprobare.
///
/// Funcție pură (fără I/O) → testabilă determinist. Repository-ul o apelează
/// și aruncă [DecontAprobareIncompletaException] dacă rezultatul e nevid.
List<CostAsociereRecord> costuriCareBlocheazaDecont(
  List<CostAsociereRecord> costuri,
  int luna,
  int an,
) {
  return costuri
      .where((c) =>
          c.dataApartenentaLuna.year == an &&
          c.dataApartenentaLuna.month == luna &&
          c.necesitaAprobare &&
          !c.esteAprobatIntegral)
      .toList();
}
