import '../master/master_local_store.dart';

abstract class EchipeCloudRepository {
  Future<List<MasterTeam>> listTeams();

  /// `true` dacă ultimul [listTeams] a venit din cache-ul local (offline).
  bool get lastListFromCache;
  Stream<List<MasterTeam>> watchTeams();
  Future<void> upsertTeam(MasterTeam team);
  Future<void> deleteTeam(String teamId);
}

