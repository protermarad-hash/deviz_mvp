import 'serviciu_prestat_models.dart';

/// Interfață abstractă pentru catalogul de servicii prestate.
///
/// Implementări:
///  - [LocalServiciuPrestatRepository] — cache local (SharedPreferences), offline-first
///  - [FirebaseServiciuPrestatRepository] — Firestore, cu fallback pe local
abstract class ServiciuPrestatRepository {
  /// Listă servicii (sortate descrescător după data actualizării).
  Future<List<ServiciuPrestat>> listServicii();

  /// Creează sau actualizează un serviciu. Returnează serviciul salvat.
  Future<ServiciuPrestat> saveServiciu(ServiciuPrestat s);

  /// Șterge un serviciu după ID (folosit rar — preferăm dezactivarea).
  Future<void> deleteServiciu(String id);
}
