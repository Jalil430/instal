import '../../domain/entities/client.dart';
import '../../domain/repositories/client_repository.dart';
import '../datasources/client_local_datasource.dart';
import '../models/client_model.dart';

class ClientRepositoryImpl implements ClientRepository {
  final ClientLocalDataSource _localDataSource;

  ClientRepositoryImpl(this._localDataSource);

  @override
  Future<List<Client>> getAllClients(String userId) async {
    final clientModels = await _localDataSource.getAllClients(userId);
    return clientModels.cast<Client>();
  }

  @override
  Future<Client?> getClientById(String id) async {
    final clientModel = await _localDataSource.getClientById(id);
    return clientModel;
  }

  @override
  Future<String> createClient(Client client) async {
    final clientModel = ClientModel.fromEntity(client);
    return await _localDataSource.createClient(clientModel);
  }

  @override
  Future<void> updateClient(Client client) async {
    final clientModel = ClientModel.fromEntity(client);
    await _localDataSource.updateClient(clientModel);
  }

  @override
  Future<void> deleteClient(String id) async {
    await _localDataSource.deleteClient(id);
  }

  @override
  Future<List<Client>> searchClients(String userId, String query) async {
    final clientModels = await _localDataSource.searchClients(userId, query);
    return clientModels.cast<Client>();
  }
} 