import 'dart:convert';
import '../models/subscription_model.dart';
import '../../domain/exceptions/subscription_exceptions.dart';
import 'subscription_remote_datasource.dart';
import '../../../../core/api/api_client.dart' as api;

class SubscriptionRemoteDataSourceImpl implements SubscriptionRemoteDataSource {
  const SubscriptionRemoteDataSourceImpl();

  @override
  Future<SubscriptionModel> validateCode(String code, String userId) async {
    try {
      final requestBody = {
        'code': code,
        'user_id': userId,
      };

      final response = await api.ApiClient.post('/subscription/validate-code', requestBody);
      // Try to decode response regardless of status; backend may send structured error details
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        data = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Success path
        final body = data ?? <String, dynamic>{};
        if (body['success'] == true) {
          return SubscriptionModel.fromJson(body['subscription'] as Map<String, dynamic>);
        }
        // If server claims success but structure missing, treat as server error
        throw const api.ServerException('Unexpected server response');
      } else {
        // Error path: map structured error codes when present
        if (data != null) {
          Map<String, dynamic> error;
          if (data!['error'] is Map<String, dynamic>) {
            error = data!['error'] as Map<String, dynamic>;
          } else {
            error = {
              'code': (data!['code'] ?? data!['error'] ?? 'UNKNOWN_ERROR').toString(),
              'message': (data!['message'] ?? data!['error'] ?? 'Unknown error').toString(),
            };
          }
          _throwAppropriateException(error);
        }
        // Fallback to generic handling
        api.ApiClient.handleResponse(response);
      }
    } catch (e) {
      if (e is SubscriptionException) {
        rethrow;
      }
      // Convert ApiClient exceptions to subscription exceptions
      if (e is api.UnauthorizedException) {
        throw const ServerException('Authentication failed. Please log in again.');
      }
      throw const NetworkException('Failed to connect to server');
    }
    
    // This should never be reached, but added for completeness
    throw const ServerException('Unexpected error occurred');
  }

  @override
  Future<List<SubscriptionModel>> getUserSubscriptions(String userId) async {
    try {
      print('Subscription API: Checking status for user $userId');
      
      final requestBody = {
        'user_id': userId,
      };

      final response = await api.ApiClient.post('/subscription/status', requestBody);
      print('Subscription API: Response status: ${response.statusCode}');
      print('Subscription API: Response body: ${response.body}');
      
      api.ApiClient.handleResponse(response);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (data['success'] == true) {
        final subscriptionsJson = data['subscriptions'] as List<dynamic>;
        return subscriptionsJson
            .map((json) => SubscriptionModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        final error = data['error'] as Map<String, dynamic>? ?? {'code': 'UNKNOWN_ERROR', 'message': 'Unknown error occurred'};
        _throwAppropriateException(error);
      }
    } catch (e) {
      if (e is SubscriptionException) {
        rethrow;
      }
      // Convert ApiClient exceptions to subscription exceptions
      if (e is api.UnauthorizedException) {
        throw const ServerException('Authentication failed. Please log in again.');
      }
      throw const NetworkException('Failed to connect to server');
    }
    
    // This should never be reached, but added for completeness
    throw const ServerException('Unexpected error occurred');
  }

  void _throwAppropriateException(Map<String, dynamic> error) {
    final errorCode = error['code'] as String?;
    final errorMessage = error['message'] as String?;

    switch (errorCode) {
      case 'INVALID_CODE':
        throw InvalidCodeException(errorMessage);
      case 'CODE_ALREADY_USED':
        throw CodeAlreadyUsedException(errorMessage);
      case 'CODE_EXPIRED':
        throw ExpiredCodeException(errorMessage);
      default:
        throw ServerException(errorMessage ?? 'Unknown server error');
    }
  }
}