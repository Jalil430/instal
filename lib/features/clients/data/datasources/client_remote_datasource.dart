import 'dart:convert';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/cache_service.dart';
import '../models/client_model.dart';

abstract class ClientRemoteDataSource {
  Future<List<ClientModel>> getAllClients(String userId);
  Future<ClientModel?> getClientById(String id);
  Future<String> createClient(ClientModel client);
  Future<void> updateClient(ClientModel client);
  Future<void> deleteClient(String id);
  Future<List<ClientModel>> searchClients(String userId, String query);
}

class ClientRemoteDataSourceImpl implements ClientRemoteDataSource {
  final CacheService _cache = CacheService();

  @override
  Future<List<ClientModel>> getAllClients(String userId) async {
    // Check cache first
    final cacheKey = CacheService.clientsKey(userId);
    final cachedClients = _cache.get<List<ClientModel>>(cacheKey);
    if (cachedClients != null) {
      return cachedClients;
    }

    final response = await ApiClient.get('/clients?user_id=$userId');
    ApiClient.handleResponse(response);
    
    final List<dynamic> jsonList = json.decode(response.body);
    final clients = jsonList.map((json) => ClientModel.fromMap(json)).toList();
    
    // Cache the result
    _cache.set(cacheKey, clients);
    
    return clients;
  }

  @override
  Future<ClientModel?> getClientById(String id) async {
    // Check cache first
    final cacheKey = CacheService.clientKey(id);
    final cachedClient = _cache.get<ClientModel?>(cacheKey);
    if (cachedClient != null) {
      return cachedClient;
    }

    try {
      final response = await ApiClient.get('/clients/$id');
      ApiClient.handleResponse(response);
      
      final Map<String, dynamic> jsonMap = json.decode(response.body);
      final client = ClientModel.fromMap(jsonMap);
      
      // Cache the result
      _cache.set(cacheKey, client);
      
      return client;
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<String> createClient(ClientModel client) async {
    final clientData = client.toApiMap();
    
    final response = await ApiClient.post('/clients', clientData);
    ApiClient.handleResponse(response);
    
    final Map<String, dynamic> result = json.decode(response.body);
    final clientId = result['id'] as String;
    
    // Invalidate cache after creating
    _cache.remove(CacheService.clientsKey(client.userId));
    
    return clientId;
  }

  @override
  Future<void> updateClient(ClientModel client) async {
    final clientData = client.toApiMap();
    
    final response = await ApiClient.put('/clients/${client.id}', clientData);
    ApiClient.handleResponse(response);
    
    // Invalidate cache after updating
    _cache.remove(CacheService.clientKey(client.id));
    _cache.remove(CacheService.clientsKey(client.userId));
  }

  @override
  Future<void> deleteClient(String id) async {
    final response = await ApiClient.delete('/clients/$id');
    ApiClient.handleResponse(response);
    
    // Invalidate cache after deleting
    _cache.remove(CacheService.clientKey(id));
    // Note: We can't remove the clients list cache without knowing userId
    // This is acceptable as the cache will expire naturally
  }

  @override
  Future<List<ClientModel>> searchClients(String userId, String query) async {
    // Don't cache search results as they're query-specific and less likely to be repeated
    final encodedQuery = Uri.encodeComponent(query);
    final response = await ApiClient.get('/clients/search?user_id=$userId&query=$encodedQuery');
    ApiClient.handleResponse(response);
    
    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => ClientModel.fromMap(json)).toList();
  }
} 