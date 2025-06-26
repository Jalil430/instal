import 'package:flutter/foundation.dart';
import '../../domain/entities/client.dart';
import '../../domain/usecases/get_all_clients.dart';
import '../../domain/usecases/create_client.dart';
import '../../domain/usecases/search_clients.dart';
import '../../domain/repositories/client_repository.dart';

class ClientProvider extends ChangeNotifier {
  final ClientRepository _repository;
  late final GetAllClients _getAllClients;
  late final CreateClient _createClient;
  late final SearchClients _searchClients;

  ClientProvider(this._repository) {
    _getAllClients = GetAllClients(_repository);
    _createClient = CreateClient(_repository);
    _searchClients = SearchClients(_repository);
  }

  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<Client> get clients => _filteredClients.isEmpty && _searchQuery.isEmpty 
      ? _clients 
      : _filteredClients;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  bool get hasClients => _clients.isNotEmpty;

  Future<void> loadClients(String userId) async {
    _setLoading(true);
    _setError(null);

    try {
      _clients = await _getAllClients(userId);
      if (_searchQuery.isNotEmpty) {
        await _performSearch(userId, _searchQuery);
      } else {
        _filteredClients = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createClient(Client client) async {
    _setLoading(true);
    _setError(null);

    try {
      await _createClient(
        userId: client.userId,
        fullName: client.fullName,
        contactNumber: client.contactNumber,
        passportNumber: client.passportNumber,
        address: client.address,
      );
      await loadClients(client.userId);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> updateClient(Client client) async {
    _setLoading(true);
    _setError(null);

    try {
      final updatedClient = client.copyWith(updatedAt: DateTime.now());
      await _repository.updateClient(updatedClient);
      await loadClients(client.userId);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> deleteClient(String clientId, String userId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _repository.deleteClient(clientId);
      await loadClients(userId);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> searchClients(String userId, String query) async {
    _searchQuery = query;
    
    if (query.trim().isEmpty) {
      _filteredClients = [];
      notifyListeners();
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      await _performSearch(userId, query);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _performSearch(String userId, String query) async {
    _filteredClients = await _searchClients(userId, query);
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredClients = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Client? getClientById(String id) {
    try {
      return _clients.firstWhere((client) => client.id == id);
    } catch (e) {
      return null;
    }
  }

  void sortClients(ClientSortOption sortOption) {
    switch (sortOption) {
      case ClientSortOption.nameAZ:
        _clients.sort((a, b) => a.fullName.compareTo(b.fullName));
        _filteredClients.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case ClientSortOption.nameZA:
        _clients.sort((a, b) => b.fullName.compareTo(a.fullName));
        _filteredClients.sort((a, b) => b.fullName.compareTo(a.fullName));
        break;
      case ClientSortOption.createdDateNewest:
        _clients.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _filteredClients.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case ClientSortOption.createdDateOldest:
        _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _filteredClients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }
    notifyListeners();
  }
}

enum ClientSortOption {
  nameAZ,
  nameZA,
  createdDateNewest,
  createdDateOldest,
} 