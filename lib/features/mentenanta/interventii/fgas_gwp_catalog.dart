import '../../agfr/agfr_refrigerant_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Wrapper API stabil pentru modulul mentenanță. Datele GWP provin dintr-o
// SINGURĂ sursă: AgfrRefrigerantData (constante legale Reg. UE 517/2014).
// Nu mai duplicăm valorile — doar delegăm + adăugăm helperele specifice F-Gas.
// ─────────────────────────────────────────────────────────────────────────────

class FGasGwpCatalog {
  const FGasGwpCatalog._();

  /// Returnează GWP pentru un agent (null dacă necunoscut). Normalizează
  /// agentul (uppercase, fără spații/cratime) pentru potrivire tolerantă cu
  /// cheile din [AgfrRefrigerantData.specs].
  static int? getGwp(String agent) {
    final normalized =
        agent.trim().toUpperCase().replaceAll(' ', '').replaceAll('-', '');
    if (normalized.isEmpty) return null;
    for (final entry in AgfrRefrigerantData.specs.entries) {
      if (entry.key.toUpperCase().replaceAll('-', '') == normalized) {
        return entry.value.gwp;
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

  /// Lista agenților pentru dropdown — sursa unică [AgfrRefrigerantData].
  static List<String> get agentiDisponibili => AgfrRefrigerantData.allNames;
}
