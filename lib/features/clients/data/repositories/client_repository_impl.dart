import '../../domain/entities/client.dart';
import '../../domain/repositories/client_repository.dart';
import '../datasources/client_remote_datasource.dart';
import '../models/client_model.dart';

class ClientRepositoryImpl implements ClientRepository {
  final ClientRemoteDataSource _remoteDataSource;

  ClientRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Client>> getAllClients(String userId) async {
    final clientModels = await _remoteDataSource.getAllClients(userId);
    return clientModels.cast<Client>();
  }

  @override
  Future<Client?> getClientById(String id) async {
    final clientModel = await _remoteDataSource.getClientById(id);
    return clientModel;
  }

  @override
  Future<String> createClient(Client client) async {
    final clientModel = ClientModel.fromEntity(client);
    return await _remoteDataSource.createClient(clientModel);
  }

  @override
  Future<void> updateClient(Client client) async {
    final clientModel = ClientModel.fromEntity(client);
    await _remoteDataSource.updateClient(clientModel);
  }

  @override
  Future<void> deleteClient(String id) async {
    await _remoteDataSource.deleteClient(id);
  }

  @override
  Future<List<Client>> searchClients(String userId, String query) async {
    final clientModels = await _remoteDataSource.searchClients(userId, query);
    return clientModels.cast<Client>();
  }
} 