import 'dart:convert';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/cache_service.dart';
import '../models/installment_model.dart';
import '../models/installment_payment_model.dart';

abstract class InstallmentRemoteDataSource {
  Future<List<InstallmentModel>> getAllInstallments(String userId);
  Future<InstallmentModel?> getInstallmentById(String id);
  Future<String> createInstallment(InstallmentModel installment);
  Future<void> updateInstallment(InstallmentModel installment);
  Future<void> deleteInstallment(String id);
  Future<List<InstallmentModel>> searchInstallments(String userId, String query);
  Future<List<InstallmentModel>> getInstallmentsByClientId(String clientId);
  Future<List<InstallmentModel>> getInstallmentsByInvestorId(String investorId);
  
  // Payment operations
  Future<List<InstallmentPaymentModel>> getPaymentsByInstallmentId(String installmentId);
  Future<InstallmentPaymentModel?> getPaymentById(String id);
  Future<String> createPayment(InstallmentPaymentModel payment);
  Future<void> updatePayment(InstallmentPaymentModel payment);
  Future<void> deletePayment(String id);
  Future<List<InstallmentPaymentModel>> getOverduePayments(String userId);
  Future<List<InstallmentPaymentModel>> getDuePayments(String userId);
  Future<List<InstallmentPaymentModel>> getAllPayments(String userId);
}

class InstallmentRemoteDataSourceImpl implements InstallmentRemoteDataSource {
  final CacheService _cache = CacheService();

  @override
  Future<List<InstallmentModel>> getAllInstallments(String userId) async {
    // Check cache first
    final cacheKey = CacheService.installmentsKey(userId);
    final cachedInstallments = _cache.get<List<InstallmentModel>>(cacheKey);
    if (cachedInstallments != null) {
      return cachedInstallments;
    }

    final response = await ApiClient.get('/installments?user_id=$userId');
    ApiClient.handleResponse(response);
    
    final List<dynamic> jsonList = json.decode(response.body);
    final installments = jsonList.map((json) => InstallmentModel.fromMap(json)).toList();
    
    // Cache the result
    _cache.set(cacheKey, installments);
    
    return installments;
  }

  @override
  Future<InstallmentModel?> getInstallmentById(String id) async {
    // Check cache first
    final cacheKey = CacheService.installmentKey(id);
    final cachedInstallment = _cache.get<InstallmentModel?>(cacheKey);
    if (cachedInstallment != null) {
      return cachedInstallment;
    }

    try {
      final response = await ApiClient.get('/installments/$id');
      ApiClient.handleResponse(response);
      
      final Map<String, dynamic> jsonMap = json.decode(response.body);
      final installment = InstallmentModel.fromMap(jsonMap);
      
      // Cache the result
      _cache.set(cacheKey, installment);
      
      return installment;
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<String> createInstallment(InstallmentModel installment) async {
    final installmentData = installment.toApiMap();
    
    final response = await ApiClient.post('/installments', installmentData);
    ApiClient.handleResponse(response);
    
    final Map<String, dynamic> result = json.decode(response.body);
    final installmentId = result['id'] as String;
    
    // Invalidate cache after creating
    _cache.remove(CacheService.installmentsKey(installment.userId));
    _cache.remove(CacheService.analyticsKey(installment.userId)); // Analytics will show new installment
    
    return installmentId;
  }

  @override
  Future<void> updateInstallment(InstallmentModel installment) async {
    final installmentData = installment.toApiMap();
    
    final response = await ApiClient.put('/installments/${installment.id}', installmentData);
    ApiClient.handleResponse(response);
    
    // Invalidate cache after updating
    _cache.remove(CacheService.installmentKey(installment.id));
    _cache.remove(CacheService.installmentsKey(installment.userId));
    _cache.remove(CacheService.paymentsKey(installment.id));
    _cache.remove(CacheService.analyticsKey(installment.userId)); // Analytics might be affected
  }

  @override
  Future<void> deleteInstallment(String id) async {
    // First, try to get the installment to extract userId for cache invalidation
    String? userId;
    try {
      final installment = await getInstallmentById(id);
      userId = installment?.userId;
    } catch (e) {
      // If we can't get the installment, continue with deletion anyway
      print('Warning: Could not get installment for cache invalidation: $e');
    }
    
    final response = await ApiClient.delete('/installments/$id');
    ApiClient.handleResponse(response);
    
    // Comprehensive cache invalidation after deleting
    _cache.remove(CacheService.installmentKey(id));
    _cache.remove(CacheService.paymentsKey(id));
    
    // If we have userId, invalidate the installments list cache
    if (userId != null) {
      _cache.remove(CacheService.installmentsKey(userId));
      _cache.remove(CacheService.analyticsKey(userId)); // Analytics will be affected too
    } else {
      // If we can't determine userId, clear all installments and analytics caches
      // This is less efficient but ensures consistency
      _cache.clear(); // Last resort - clear entire cache
    }
  }

  @override
  Future<List<InstallmentModel>> searchInstallments(String userId, String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final response = await ApiClient.get('/installments/search?user_id=$userId&query=$encodedQuery');
    ApiClient.handleResponse(response);
    
    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => InstallmentModel.fromMap(json)).toList();
  }

  @override
  Future<List<InstallmentModel>> getInstallmentsByClientId(String clientId) async {
    final response = await ApiClient.get('/installments?client_id=$clientId');
    ApiClient.handleResponse(response);
    
    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => InstallmentModel.fromMap(json)).toList();
  }

  @override
  Future<List<InstallmentModel>> getInstallmentsByInvestorId(String investorId) async {
    final response = await ApiClient.get('/installments?investor_id=$investorId');
    ApiClient.handleResponse(response);
    
    final List<dynamic> jsonList = json.decode(response.body);
    return jsonList.map((json) => InstallmentModel.fromMap(json)).toList();
  }

  // Payment operations
  @override
  Future<List<InstallmentPaymentModel>> getPaymentsByInstallmentId(String installmentId) async {
    // Check cache first
    final cacheKey = CacheService.paymentsKey(installmentId);
    final cachedPayments = _cache.get<List<InstallmentPaymentModel>>(cacheKey);
    if (cachedPayments != null) {
      return cachedPayments;
    }

    try {
      // Get the installment which includes payments in the response
      final response = await ApiClient.get('/installments/$installmentId');
      ApiClient.handleResponse(response);
      
      final Map<String, dynamic> jsonMap = json.decode(response.body);
      final List<dynamic> paymentsJson = jsonMap['payments'] ?? [];
      final payments = paymentsJson.map((json) => InstallmentPaymentModel.fromMap(json)).toList();
      
      // Cache the result
      _cache.set(cacheKey, payments);
      
      return payments;
    } on NotFoundException {
      return [];
    }
  }

  @override
  Future<InstallmentPaymentModel?> getPaymentById(String id) async {
    // Note: There's no specific endpoint for individual payments in your cloud functions
    // This would need to be implemented if required, or we can fetch via installment
    throw UnimplementedError('Individual payment fetching not implemented - use getPaymentsByInstallmentId instead');
  }

  @override
  Future<String> createPayment(InstallmentPaymentModel payment) async {
    // Payments are created automatically when creating installments
    // This method might not be needed for the current cloud function structure
    throw UnimplementedError('Individual payment creation not implemented - payments are created with installments');
  }

  @override
  Future<void> updatePayment(InstallmentPaymentModel payment) async {
    final paymentData = {
      'is_paid': payment.isPaid,
      'paid_date': payment.paidDate?.toIso8601String().split('T')[0], // YYYY-MM-DD format
    };
    
    final response = await ApiClient.put('/installment-payments/${payment.id}', paymentData);
    ApiClient.handleResponse(response);
    
    // Invalidate cache after updating payment
    _cache.remove(CacheService.paymentsKey(payment.installmentId));
    _cache.remove(CacheService.installmentKey(payment.installmentId));
    
    // Payment status changes affect analytics, so we need to invalidate analytics cache
    // We'll use a broader cache invalidation for analytics since we don't have userId here
    // This ensures analytics is always up to date when payments change
    _cache.cleanup(); // Remove expired entries
    
    // Since payment changes affect analytics for all users potentially,
    // we'll use a simple approach: remove all analytics cache entries
    final analyticsKeys = _cache.getKeysWithPrefix('analytics_');
    for (final key in analyticsKeys) {
      _cache.remove(key);
    }
  }

  @override
  Future<void> deletePayment(String id) async {
    // Individual payment deletion might not be needed
    throw UnimplementedError('Individual payment deletion not implemented');
  }

  @override
  Future<List<InstallmentPaymentModel>> getOverduePayments(String userId) async {
    // This would require a specific endpoint or filtering on the client side
    throw UnimplementedError('Overdue payments endpoint not implemented - filter on client side');
  }

  @override
  Future<List<InstallmentPaymentModel>> getDuePayments(String userId) async {
    // This would require a specific endpoint or filtering on the client side
    throw UnimplementedError('Due payments endpoint not implemented - filter on client side');
  }

  @override
  Future<List<InstallmentPaymentModel>> getAllPayments(String userId) async {
    // This would require a specific endpoint or filtering on the client side
    throw UnimplementedError('All payments endpoint not implemented - filter on client side');
  }
} 