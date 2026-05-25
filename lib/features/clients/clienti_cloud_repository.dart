import 'client_models.dart';

abstract class ClientiCloudRepository {
  Future<List<ClientRecord>> listClients();
  Stream<List<ClientRecord>> watchClients();
  Future<void> upsertClient(ClientRecord client);
  Future<void> deleteClient(String clientId);
}

