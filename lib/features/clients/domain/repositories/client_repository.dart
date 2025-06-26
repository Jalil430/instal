import '../entities/client.dart';

abstract class ClientRepository {
  Future<List<Client>> getAllClients(String userId);
  Future<Client?> getClientById(String id);
  Future<String> createClient(Client client);
  Future<void> updateClient(Client client);
  Future<void> deleteClient(String id);
  Future<List<Client>> searchClients(String userId, String query);
} 