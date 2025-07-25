import 'dart:convert';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/cache_service.dart';
import '../models/investor_model.dart';

abstract class InvestorRemoteDataSource {
  Future<List<InvestorModel>> getAllInvestors(String userId);
  Future<InvestorModel?> getInvestorById(String id);
  Future<String> createInvestor(InvestorModel investor);
  Future<void> updateInvestor(InvestorModel investor);
  Future<void> deleteInvestor(String id);
  Future<List<InvestorModel>> searchInvestors(String userId, String query);
}

class InvestorRemoteDataSourceImpl implements InvestorRemoteDataSource {
  final CacheService _cache = CacheService();

  @override
  Future<List<InvestorModel>> getAllInvestors(String userId) async {
    // Check cache first
    final cacheKey = CacheService.investorsKey(userId);
    final cachedInvestors = _cache.get<List<InvestorModel>>(cacheKey);
    if (cachedInvestors != null) {
      return cachedInvestors;
    }

    final response = await ApiClient.get('/investors?user_id=$userId&limit=50000&offset=0');
    ApiClient.handleResponse(response);
    
    final List<dynamic> jsonList = json.decode(response.body);
    final investors = jsonList.map((json) => InvestorModel.fromMap(json)).toList();
    
    // Cache the result
    _cache.set(cacheKey, investors);
    
    return investors;
  }

  @override
  Future<InvestorModel?> getInvestorById(String id) async {
    // Check cache first
    final cacheKey = CacheService.investorKey(id);
    final cachedInvestor = _cache.get<InvestorModel?>(cacheKey);
    if (cachedInvestor != null) {
      return cachedInvestor;
    }

    try {
      final response = await ApiClient.get('/investors/$id');
      ApiClient.handleResponse(response);
      
      final Map<String, dynamic> jsonMap = json.decode(response.body);
      final investor = InvestorModel.fromMap(jsonMap);
      
      // Cache the result
      _cache.set(cacheKey, investor);
      
      return investor;
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<String> createInvestor(InvestorModel investor) async {
    final investorData = investor.toApiMap();
    
    final response = await ApiClient.post('/investors', investorData);
    ApiClient.handleResponse(response);
    
    final Map<String, dynamic> result = json.decode(response.body);
    final investorId = result['id'] as String;
    
    // Invalidate cache after creating
    _cache.remove(CacheService.investorsKey(investor.userId));
    
    return investorId;
  }

  @override
  Future<void> updateInvestor(InvestorModel investor) async {
    final investorData = investor.toApiMap();
    
    final response = await ApiClient.put('/investors/${investor.id}', investorData);
    ApiClient.handleResponse(response);
    
    // Invalidate cache after updating
    _cache.remove(CacheService.investorKey(investor.id));
    _cache.remove(CacheService.investorsKey(investor.userId));
  }

  @override
  Future<void> deleteInvestor(String id) async {
    final response = await ApiClient.delete('/investors/$id');
    ApiClient.handleResponse(response);
    
    // Invalidate cache after deleting
    _cache.remove(CacheService.investorKey(id));
    // Note: We can't remove the investors list cache without knowing userId
  }

  @override
  Future<List<InvestorModel>> searchInvestors(String userId, String query) async {
    // Don't cache search results as they're query-specific and less likely to be repeated
    final encodedQuery = Uri.encodeComponent(query);
    final response = await ApiClient.get('/investors/search?user_id=$userId&query=$encodedQuery');
    ApiClient.handleResponse(response);
    
    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => InvestorModel.fromMap(json)).toList();
  }
} 