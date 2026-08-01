/// Funcții pure pentru calculul costurilor și profitului unei lucrări.
/// Extrase din LucrareDetaliiPage pentru testabilitate (fișierul monolit
/// rămâne doar wiring — regula fișiere < 800 linii nu se aplică
/// retroactiv monolitului existent, dar logica nouă nu se mai adaugă acolo).
library;

class LucrareCostCalc {
  const LucrareCostCalc._();

  /// Citește un număr dintr-un `Map` posibil eterogen (string/num/null).
  static double asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  /// Costul unei linii de material: preferă prețul real de achiziție
  /// (`realPrice`) dacă a fost completat, altfel prețul ofertat/inițial
  /// (`total` explicit dacă există, altfel `qty * price`).
  static double materialLineTotal(Map<String, dynamic> row) {
    final qty = asDouble(row['qty']);
    final realPrice = asDouble(row['realPrice']);
    if (realPrice > 0) {
      return qty * realPrice;
    }
    final explicitTotal = asDouble(row['total']);
    if (explicitTotal > 0) {
      return explicitTotal;
    }
    return qty * asDouble(row['price']);
  }

  /// Totalul "ofertat"/inițial al unei linii de material (ignoră prețul
  /// real), pentru afișarea comparativă economie/depășire.
  static double materialLineOfferedTotal(Map<String, dynamic> row) {
    final qty = asDouble(row['qty']);
    final explicitTotal = asDouble(row['total']);
    if (explicitTotal > 0) {
      return explicitTotal;
    }
    return qty * asDouble(row['price']);
  }

  /// Diferența economie(-)/depășire(+) pe o linie de material, doar dacă
  /// prețul real a fost completat; altfel 0.
  static double materialLineRealVsOfferedDiff(Map<String, dynamic> row) {
    final realPrice = asDouble(row['realPrice']);
    if (realPrice <= 0) return 0;
    return materialLineTotal(row) - materialLineOfferedTotal(row);
  }

  /// Costul total unificat al unei lucrări: materiale + manoperă proprie +
  /// resurse partenere (personal + autovehicule partener).
  static double costTotalUnificat({
    required double materialsTotal,
    required double laborTotal,
    required double partnersTotal,
  }) =>
      materialsTotal + laborTotal + partnersTotal;

  /// Profit brut = valoare estimată − cost total (toate costurile scăzute).
  static double grossProfit({
    required double estimatedValue,
    required double costTotal,
  }) =>
      estimatedValue - costTotal;
}
