import 'asociere_models.dart';
import 'cost_asociere_models.dart';
import 'decont_lunar_asociere_models.dart';

/// Rezultatul pur al calculului de settle-up pentru un decont lunar de
/// asociere — fără dependențe de I/O (SharedPreferences/Firestore), ca să
/// poată fi testat determinist. Repository-ul agregă datele lunii și apoi
/// apelează [calculeazaDecontSettleUp] cu totalurile.
class AsociereDecontSettleUp {
  const AsociereDecontSettleUp({
    required this.rezultat,
    required this.rambursareDatorataCatre,
    required this.sumaRambursare,
    required this.sumaRezervaRetinuta,
    required this.sumaDeAchitatAcum,
  });

  /// venituri − (costPT + costPartener). Poate fi negativ (pierdere).
  final double rezultat;
  final AsociereRambursareCatre rambursareDatorataCatre;

  /// Valoarea absolută a transferului dintre părți (mereu ≥ 0).
  final double sumaRambursare;

  /// Partea reținută ca rezervă de garanție (doar când rambursarea merge
  /// către partea care NU încasează).
  final double sumaRezervaRetinuta;

  /// Suma efectiv de plătit în luna curentă = sumaRambursare − rezervă.
  final double sumaDeAchitatAcum;
}

/// Calculează settle-up-ul unui decont lunar de asociere, plecând de la
/// totalurile deja agregate pentru lună.
///
/// DIRECȚIA rambursării depinde de cine facturează Beneficiarul și încasează
/// veniturile (contractantul principal, [incasator]): partea care încasează
/// deține numerarul și rambursează cealaltă parte (numită aici „primitor" =
/// partea care NU încasează). Fiecare parte trebuie să ajungă la cota ei din
/// rezultat:
///   rezultat = veniturIncasatTotal − (costPT + costPartener)
///   T = costPrimitor + (cotaPrimitor/100) × rezultat
///     T > 0  → încasatorul datorează primitorului (bani către primitor)
///     T < 0  → primitorul datorează încasatorului (bani către încasator)
///     T ≈ 0  → nimeni
/// Formula e simetrică: dacă PRO TERM încasează, primitorul e partenerul;
/// dacă partenerul încasează, primitorul e PRO TERM.
///
/// Rezerva de garanție se reține DOAR din rambursarea către partea care NU
/// încasează (primitorul), indiferent de direcție:
///   sumaRezervaRetinuta = sumaRambursare × procentRezervaGarantie/100
///   sumaDeAchitatAcum   = sumaRambursare − sumaRezervaRetinuta
/// Când banii merg către încasator (T < 0), nu se reține rezervă:
///   rezervă = 0, se achită integral.
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

  final t = costPrimitor + (cotaPrimitor / 100.0) * rezultat;

  AsociereRambursareCatre catre;
  double sumaRambursare;
  bool retineRezerva;
  if (t > 0.005) {
    // Banii merg către primitor (partea care nu încasează) → se reține rezervă.
    catre = primitor;
    sumaRambursare = t;
    retineRezerva = true;
  } else if (t < -0.005) {
    // Banii merg către încasator → fără rezervă.
    catre = catreIncasator;
    sumaRambursare = -t;
    retineRezerva = false;
  } else {
    catre = AsociereRambursareCatre.niciunul;
    sumaRambursare = 0;
    retineRezerva = false;
  }

  double sumaRezervaRetinuta = 0;
  double sumaDeAchitatAcum = sumaRambursare;
  if (retineRezerva) {
    sumaRezervaRetinuta = sumaRambursare * (procentRezervaGarantie / 100.0);
    sumaDeAchitatAcum = sumaRambursare - sumaRezervaRetinuta;
  }

  return AsociereDecontSettleUp(
    rezultat: round2(rezultat),
    rambursareDatorataCatre: catre,
    sumaRambursare: round2(sumaRambursare),
    sumaRezervaRetinuta: round2(sumaRezervaRetinuta),
    sumaDeAchitatAcum: round2(sumaDeAchitatAcum),
  );
}

/// Costurile care BLOCHEAZĂ generarea decontului pentru (luna, an): costuri
/// din perioada decontului (după `CostAsociereRecord.data`) care necesită
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
          c.data.year == an &&
          c.data.month == luna &&
          c.necesitaAprobare &&
          !c.esteAprobatIntegral)
      .toList();
}
