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

  /// Partea reținută ca rezervă de garanție (doar la rambursare către partener).
  final double sumaRezervaRetinuta;

  /// Suma efectiv de plătit în luna curentă = sumaRambursare − rezervă.
  final double sumaDeAchitatAcum;
}

/// Calculează settle-up-ul unui decont lunar de asociere, plecând de la
/// totalurile deja agregate pentru lună.
///
/// Model: PRO TERM încasează veniturile (contractant principal) și deține
/// numerarul; fiecare parte a plătit din buzunar costurile proprii. Fiecare
/// parte trebuie să ajungă la cota ei din rezultat:
///   rezultat = veniturIncasatTotal − (costPT + costPartener)
///   T = costPartener + (cotaPartener/100) × rezultat
///     T > 0  → PRO TERM datorează partenerului
///     T < 0  → partenerul datorează PRO TERM
///     T ≈ 0  → nimeni
///
/// Rezerva de garanție se reține DOAR din rambursarea către partener:
///   sumaRezervaRetinuta = sumaRambursare × procentRezervaGarantie/100
///   sumaDeAchitatAcum   = sumaRambursare − sumaRezervaRetinuta
/// Pentru rambursare către PRO TERM: rezervă = 0, se achită integral.
///
/// Toate valorile de ieșire sunt rotunjite la 2 zecimale.
AsociereDecontSettleUp calculeazaDecontSettleUp({
  required double veniturIncasatTotal,
  required double costRecunoscutProTerm,
  required double costRecunoscutPartener,
  required double cotaPartener,
  required double procentRezervaGarantie,
}) {
  double round2(double v) => (v * 100).roundToDouble() / 100.0;

  final rezultat =
      veniturIncasatTotal - (costRecunoscutProTerm + costRecunoscutPartener);
  final t = costRecunoscutPartener + (cotaPartener / 100.0) * rezultat;

  AsociereRambursareCatre catre;
  double sumaRambursare;
  if (t > 0.005) {
    catre = AsociereRambursareCatre.partener;
    sumaRambursare = t;
  } else if (t < -0.005) {
    catre = AsociereRambursareCatre.proTerm;
    sumaRambursare = -t;
  } else {
    catre = AsociereRambursareCatre.niciunul;
    sumaRambursare = 0;
  }

  double sumaRezervaRetinuta = 0;
  double sumaDeAchitatAcum = sumaRambursare;
  if (catre == AsociereRambursareCatre.partener) {
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
