import '../entities/client.dart';
import '../repositories/client_repository.dart';

class SearchClients {
  final ClientRepository _repository;

  SearchClients(this._repository);

  Future<List<Client>> call(String userId, String query) async {
    if (query.trim().isEmpty) {
      return [];
    }
    return await _repository.searchClients(userId, query.trim());
  }
} 