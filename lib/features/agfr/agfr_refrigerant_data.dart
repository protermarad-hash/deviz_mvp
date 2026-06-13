/// Date statice agenți frigorifici — constante legale UE (Reg. 517/2014).
/// NU modifica valorile GWP — sunt constante legale europene.
class AgfrRefrigerantData {
  AgfrRefrigerantData._();

  static const Map<String, RefrigerantSpec> specs = {
    // ── HFC-uri comune HVAC ────────────────────────────────────────────────
    'R32':    RefrigerantSpec(gwp: 675,  tip: 'HFC',  culoare: 'Roșu',           note: 'A2L — ușor inflamabil'),
    'R410A':  RefrigerantSpec(gwp: 2088, tip: 'HFC',  culoare: 'Roz'),
    'R407C':  RefrigerantSpec(gwp: 1774, tip: 'HFC',  culoare: 'Maro deschis'),
    'R407F':  RefrigerantSpec(gwp: 1825, tip: 'HFC',  culoare: 'Violet'),
    'R404A':  RefrigerantSpec(gwp: 3922, tip: 'HFC',  culoare: 'Portocaliu'),
    'R507A':  RefrigerantSpec(gwp: 3985, tip: 'HFC',  culoare: 'Albastru deschis'),
    'R507':   RefrigerantSpec(gwp: 3985, tip: 'HFC',  culoare: 'Albastru deschis'),
    'R134a':  RefrigerantSpec(gwp: 1430, tip: 'HFC',  culoare: 'Albastru'),
    'R22':    RefrigerantSpec(gwp: 1810, tip: 'HCFC', culoare: 'Verde',           note: 'Interzis din 2015'),
    'R422D':  RefrigerantSpec(gwp: 2729, tip: 'HFC',  culoare: 'Verde-alb'),
    'R417A':  RefrigerantSpec(gwp: 2346, tip: 'HFC',  culoare: 'Verde'),
    'R427A':  RefrigerantSpec(gwp: 2138, tip: 'HFC',  culoare: 'Bej'),
    'R437A':  RefrigerantSpec(gwp: 1805, tip: 'HFC',  culoare: 'Mov deschis'),
    // ── HFO / amestecuri low-GWP ──────────────────────────────────────────
    'R448A':  RefrigerantSpec(gwp: 1387, tip: 'HFO',  culoare: 'Roz-roșu'),
    'R449A':  RefrigerantSpec(gwp: 1397, tip: 'HFO',  culoare: 'Portocaliu deschis'),
    'R452A':  RefrigerantSpec(gwp: 2140, tip: 'HFO',  culoare: 'Galben'),
    'R452B':  RefrigerantSpec(gwp: 676,  tip: 'HFO',  culoare: 'Verde lime',     note: 'A2L'),
    'R454B':  RefrigerantSpec(gwp: 466,  tip: 'HFO',  culoare: 'Roz',            note: 'A2L — înlocuitor R410A'),
    'R454C':  RefrigerantSpec(gwp: 148,  tip: 'HFO',  culoare: 'Portocaliu-roșu', note: 'A2L'),
    'R1234yf':RefrigerantSpec(gwp: 4,   tip: 'HFO',  culoare: 'Roz pal',        note: 'A2L'),
    'R1234ze':RefrigerantSpec(gwp: 7,   tip: 'HFO',  culoare: 'Verde mint',      note: 'A2L'),
    // ── Naturale ──────────────────────────────────────────────────────────
    'R290':   RefrigerantSpec(gwp: 3,   tip: 'HC',   culoare: 'Verde',           note: 'A3 — inflamabil'),
    'R600a':  RefrigerantSpec(gwp: 3,   tip: 'HC',   culoare: 'Gri',             note: 'A3 — inflamabil'),
    'R717':   RefrigerantSpec(gwp: 0,   tip: 'NH3',  culoare: 'Alb-verde',       note: 'B2L — toxic'),
    'R744':   RefrigerantSpec(gwp: 1,   tip: 'CO2',  culoare: 'Gri'),
  };

  static List<String> get allNames {
    final list = specs.keys.toList()..sort();
    return list;
  }

  static int gwpFor(String name) => specs[name]?.gwp ?? 0;

  static String tipFor(String name) => specs[name]?.tip ?? '';

  /// kg agent frigorific × GWP / 1000 = tone CO₂ echivalent
  static double calculeazaToneCO2(double kgAgent, String refrigerant) {
    final gwp = gwpFor(refrigerant);
    return (kgAgent * gwp) / 1000.0;
  }

  /// Interval verificare scurgeri conform Reg. UE 517/2014
  static String intervalVerificareScurgeri(double toneCO2) {
    if (toneCO2 < 5)   return 'Nu se aplică (sub 5t CO₂e)';
    if (toneCO2 < 50)  return 'Anual (≥5t CO₂e)';
    if (toneCO2 < 500) return 'La 6 luni (≥50t CO₂e)';
    return 'La 3 luni (≥500t CO₂e)';
  }

  /// Data scadentă verificare scurgeri
  static DateTime dataScadentaVerificare(DateTime ultimaVerificare, double toneCO2) {
    if (toneCO2 < 50)  return ultimaVerificare.add(const Duration(days: 365));
    if (toneCO2 < 500) return ultimaVerificare.add(const Duration(days: 183));
    return ultimaVerificare.add(const Duration(days: 91));
  }
}

class RefrigerantSpec {
  final int gwp;
  final String tip;
  final String culoare;
  final String? note;
  const RefrigerantSpec({
    required this.gwp,
    required this.tip,
    required this.culoare,
    this.note,
  });
}
