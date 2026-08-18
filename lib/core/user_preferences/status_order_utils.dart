/// Cheie sintetică pentru grupul "Convertit(ă)".
///
/// `isConverted` NU este un status real din enum (`OfferStatus`/
/// `DevizTehnicStatus`) — e un getter calculat:
/// `convertedToJobId.trim().isNotEmpty` (`offer_models.dart:850`,
/// `deviz_tehnic_models.dart:452`). Ca userul să poată reordona grupul
/// "Convertit(ă)" la fel ca orice status real, îl tratăm ca a (N+1)-a cheie
/// reordonabilă, separată de valorile enum-ului.
const String kConvertedStatusKey = 'convertit';

/// Aplică ordinea salvată de user peste lista completă de chei posibile
/// pentru un modul (statusuri din enum + `kConvertedStatusKey`).
///
/// Reguli (fără crash, fără omitere de date):
/// - Cheile din `savedOrder` care încă există în `allKeys` sunt păstrate,
///   în ordinea lor, fără duplicate.
/// - Dacă `savedOrder` e null/gol, se pornește de la `defaultOrder`
///   (ordinea implicită rezonabilă, ex. fostul rank hardcodat).
/// - Orice cheie din `defaultOrder` care încă lipsește (ex. userul a salvat
///   o ordine parțială) e adăugată după, în ordinea din `defaultOrder`.
/// - Orice cheie complet nouă din `allKeys` (ex. status adăugat ulterior în
///   enum, absent și din `savedOrder`, și din `defaultOrder`) e adăugată la
///   final — NICIODATĂ omisă.
List<String> resolveStatusOrder({
  required List<String> allKeys,
  required List<String> defaultOrder,
  List<String>? savedOrder,
}) {
  final allSet = allKeys.toSet();
  final base =
      (savedOrder != null && savedOrder.isNotEmpty) ? savedOrder : const <String>[];

  final result = <String>[];
  final seen = <String>{};

  for (final key in base) {
    if (allSet.contains(key) && seen.add(key)) {
      result.add(key);
    }
  }
  for (final key in defaultOrder) {
    if (allSet.contains(key) && seen.add(key)) {
      result.add(key);
    }
  }
  for (final key in allKeys) {
    if (seen.add(key)) {
      result.add(key);
    }
  }
  return result;
}
