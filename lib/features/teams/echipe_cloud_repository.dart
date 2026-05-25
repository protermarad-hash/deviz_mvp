import '../master/master_local_store.dart';

abstract class EchipeCloudRepository {
  Future<List<MasterTeam>> listTeams();
  Stream<List<MasterTeam>> watchTeams();
  Future<void> upsertTeam(MasterTeam team);
  Future<void> deleteTeam(String teamId);
}

