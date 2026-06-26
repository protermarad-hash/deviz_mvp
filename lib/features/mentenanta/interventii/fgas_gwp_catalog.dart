// ─────────────────────────────────────────────────────────────────────────────
// Catalog GWP (Global Warming Potential) — valori standardizate conform
// Regulamentului (UE) Nr. 517/2014. Folosit în editorul de intervenție și în
// generarea Log F-Gas pentru calculul tonelor de CO₂ echivalent.
// ─────────────────────────────────────────────────────────────────────────────

class FGasGwpCatalog {
  const FGasGwpCatalog._();

  /// Agent frigorific → GWP (kg CO₂ echiv. per kg de agent).
  static const Map<String, int> gwpValues = {
    'R32': 675,
    'R410A': 2088,
    'R22': 1810,
    'R134a': 1430,
    'R407C': 1774,
    'R404A': 3922,
    'R507A': 3985,
    'R290': 3, // propan
    'R600a': 3, // izobutan
    'R1234yf': 4,
    'R1234ze': 7,
    'R448A': 1387,
    'R449A': 1397,
    'R452A': 2140,
    'R454B': 466,
  };

  /// Returnează GWP pentru un agent (null dacă necunoscut). Normalizează
  /// agentul (uppercase, fără spații/cratime) pentru potrivire tolerantă.
  static int? getGwp(String agent) {
    final normalized =
        agent.trim().toUpperCase().replaceAll(' ', '').replaceAll('-', '');
    if (normalized.isEmpty) return null;
    for (final entry in gwpValues.entries) {
      if (entry.key.toUpperCase().replaceAll('-', '') == normalized) {
        return entry.value;
      }
    }
    return null;
  }

  /// Calculează tone CO₂ echivalent.
  /// Formula: (cantAdaugata - cantRecuperata) × GWP / 1000.
  /// Conform Reg. UE 517/2014 — se raportează cantitatea NETĂ în sistem.
  static double calcToneCO2({
    required double cantitateAdaugata,
    required double cantitateRecuperata,
    required int gwp,
  }) {
    final cantitateNeta =
        (cantitateAdaugata - cantitateRecuperata).clamp(0.0, double.infinity);
    return cantitateNeta * gwp / 1000.0;
  }

  /// Prag de raportare: 5 tone CO₂ echiv. Sub 5 tone → scutit de verificări
  /// periodice obligatorii.
  static const double pragRaportareTone = 5.0;

  /// Lista agenților pentru dropdown (sortată alfabetic).
  static List<String> get agentiDisponibili =>
      gwpValues.keys.toList()..sort();
}
