import '../mentenanta_models.dart';

/// Catalog intern de prețuri orientative per categorie de echipament.
///
/// Valorile sunt sugestii pre-completate la adăugarea unui echipament nou;
/// utilizatorul le poate suprascrie oricând. Prețuri în RON, fără TVA.
class PretCatalogService {
  const PretCatalogService._();

  /// Preț orientativ igienizare pentru o categorie.
  static double pretIgienizare(CategorieMentenanta categorie) {
    switch (categorie) {
      case CategorieMentenanta.vrfDaikin:
      case CategorieMentenanta.vrfMitsubishi:
      case CategorieMentenanta.vrfAltele:
        return 250;
      case CategorieMentenanta.splitDaikin:
      case CategorieMentenanta.splitAltele:
        return 150;
      case CategorieMentenanta.ventilatie:
        return 200;
      case CategorieMentenanta.altele:
        return 0;
    }
  }

  /// Preț orientativ revizie tehnică pentru o categorie.
  static double pretRevizie(CategorieMentenanta categorie) {
    switch (categorie) {
      case CategorieMentenanta.vrfDaikin:
      case CategorieMentenanta.vrfMitsubishi:
      case CategorieMentenanta.vrfAltele:
        return 200;
      case CategorieMentenanta.splitDaikin:
      case CategorieMentenanta.splitAltele:
        return 100;
      case CategorieMentenanta.ventilatie:
        return 150;
      case CategorieMentenanta.altele:
        return 0;
    }
  }

  /// Indică dacă o categorie necesită implicit log F-Gas (echipamente cu agent
  /// frigorific peste pragul de raportare).
  static bool necesitaLogFGasImplicit(CategorieMentenanta categorie) {
    switch (categorie) {
      case CategorieMentenanta.vrfDaikin:
      case CategorieMentenanta.vrfMitsubishi:
      case CategorieMentenanta.vrfAltele:
        return true;
      case CategorieMentenanta.splitDaikin:
      case CategorieMentenanta.splitAltele:
      case CategorieMentenanta.ventilatie:
      case CategorieMentenanta.altele:
        return false;
    }
  }
}
