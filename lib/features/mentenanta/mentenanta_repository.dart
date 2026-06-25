import 'mentenanta_models.dart';

/// Interfață abstractă pentru contractele de mentenanță.
///
/// Implementări:
///  - [LocalMentenantaRepository] — cache local (SharedPreferences), offline-first
///  - [FirebaseMentenantaRepository] — Firestore, cu fallback pe local
abstract class MentenantaRepository {
  /// Listă contracte (sortate descrescător după data actualizării).
  Future<List<ContractMentenanta>> listContracte();

  /// Creează sau actualizează un contract. Returnează contractul salvat
  /// (cu eventualul ID generat).
  Future<ContractMentenanta> saveContract(ContractMentenanta contract);

  /// Șterge un contract după ID.
  Future<void> deleteContract(String id);

  /// Flux reactiv cu lista de contracte (pentru actualizare automată UI).
  Stream<List<ContractMentenanta>> watchContracte();
}
