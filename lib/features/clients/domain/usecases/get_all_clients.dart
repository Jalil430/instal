import '../entities/client.dart';
import '../repositories/client_repository.dart';

class GetAllClients {
  final ClientRepository _repository;

  GetAllClients(this._repository);

  Future<List<Client>> call(String userId) async {
    return await _repository.getAllClients(userId);
  }
} 
 