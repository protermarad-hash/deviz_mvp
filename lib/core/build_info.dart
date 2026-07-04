/// Identificator de build vizibil în aplicație (sub versiune, în Drawer).
///
/// CERINȚĂ PERMANENTĂ: orice build de test TREBUIE să fie distinct
/// identificabil vizual pe ecran. Actualizează [kBuildTag] la fiecare build
/// (sau pasează `--dart-define=BUILD_TAG=...` la comanda de build).
///
/// Format recomandat: `diag-YYYYMMDD-HHMM` sau `rel-YYYYMMDD-HHMM`.
const String kBuildTag = String.fromEnvironment(
  'BUILD_TAG',
  defaultValue: 'rel-20260704-2244',
);
