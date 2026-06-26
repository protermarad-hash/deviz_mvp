import 'interventie_models.dart';

/// Interfață abstractă pentru intervențiile de service legate de un contract
/// de mentenanță.
///
/// Implementări:
///  - [LocalInterventieRepository] — cache local (SharedPreferences), offline-first
///  - [FirebaseInterventieRepository] — Firestore, cu fallback pe local
abstract class InterventieRepository {
  /// Listă intervenții pentru un contract (sortate descrescător după dată).
  Future<List<InterventieService>> listInterventii(String contractId);

  /// Creează sau actualizează o intervenție. Returnează intervenția salvată
  /// (cu eventualul ID generat).
  Future<InterventieService> saveInterventie(InterventieService interventie);

  /// Șterge o intervenție după ID.
  Future<void> deleteInterventie(String id);
}
