import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:instal_app/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:instal_app/features/auth/domain/entities/auth_state.dart';
import 'package:instal_app/features/auth/domain/entities/user.dart';

class ApiClient {
  static const String _baseUrl = 'https://d5degr4sfnv9p7i065ga.kf69zffa.apigw.yandexcloud.net';
  static const String _apiKey = 'AQVN1gWo_joBv9AiZVrbtOHPm46XIcO_z_YH4RQh';
  
  static const Duration _defaultTimeout = Duration(seconds: 10);
  
  static final http.Client _httpClient = http.Client();
  static final AuthLocalDataSource _authLocalDataSource = AuthLocalDataSourceImpl();
  
  // Flag to prevent infinite refresh loops
  static bool _isRefreshing = false;
  
  static String get baseUrl => _baseUrl;
  static String get apiKey => _apiKey;
  static http.Client get httpClient => _httpClient;
  static Duration get defaultTimeout => _defaultTimeout;
  
  static Future<Map<String, String>> _getHeaders([String? endpoint]) async {
    final authState = await _authLocalDataSource.getAuthState();
    
    // Check if this is an auth endpoint
    final isApiKeyEndpoint = endpoint == '/auth/login' ||
        endpoint == '/auth/register' ||
        endpoint == '/auth/refresh' ||
        endpoint == '/auth/verify';
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Connection': 'keep-alive',
    };
    
    if (isApiKeyEndpoint) {
      // Auth endpoints use API key authentication
      headers['X-API-Key'] = _apiKey;
    } else {
      // Business endpoints require JWT authentication
      if (!authState.isAuthenticated || authState.accessToken == null) {
        throw UnauthorizedException('User not authenticated');
      }
      
      // Check if token needs refresh or is expired
      if (authState.isTokenExpired) {
        if (authState.refreshToken != null) {
          try {
            // Attempt to refresh the token
            final refreshedState = await _refreshToken(authState.refreshToken!);
            headers['Authorization'] = 'Bearer ${refreshedState.accessToken}';
          } catch (e) {
            // If refresh fails, clear auth state and throw specific exception
            await _authLocalDataSource.clearAuthState();
            throw TokenExpiredException('Session expired. Please log in again.');
          }
        } else {
          // No refresh token available, clear auth state
          await _authLocalDataSource.clearAuthState();
          throw TokenExpiredException('Session expired. Please log in again.');
        }
      } else if (authState.needsRefresh) {
        // Token is still valid but should be refreshed proactively
        if (authState.refreshToken != null) {
          try {
            // Attempt to refresh the token in background
            final refreshedState = await _refreshToken(authState.refreshToken!);
            headers['Authorization'] = 'Bearer ${refreshedState.accessToken}';
          } catch (e) {
            // If refresh fails, use current token (it's still valid)
            headers['Authorization'] = 'Bearer ${authState.accessToken}';
          }
        } else {
          headers['Authorization'] = 'Bearer ${authState.accessToken}';
        }
      } else {
        headers['Authorization'] = 'Bearer ${authState.accessToken}';
      }
    }
    
    return headers;
  }

  static Future<AuthState> _refreshToken(String refreshToken) async {
    if (_isRefreshing) {
      throw TokenExpiredException('Token refresh already in progress');
    }
    
    _isRefreshing = true;
    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _apiKey,
        },
        body: json.encode({'refresh_token': refreshToken}),
      ).timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        throw TokenExpiredException('Token refresh failed with status: ${response.statusCode}');
      }

      final Map<String, dynamic> responseData = json.decode(response.body);
      
      // Get current auth state to preserve user data that might not be in refresh response
      final currentAuthState = await _authLocalDataSource.getAuthState();
      
      // Parse the response and create new auth state
      final newAuthState = AuthState.authenticated(
        user: User(
          id: responseData['user_id'],
          email: responseData['email'],
          fullName: responseData['full_name'],
          phone: currentAuthState.user?.phone, // Preserve existing phone if not in response
          createdAt: currentAuthState.user?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        accessToken: responseData['access_token'],
        refreshToken: responseData['refresh_token'],
        expiresAt: DateTime.now().add(Duration(seconds: responseData['expires_in'] ?? 3600)),
      );

      // Save the new auth state
      await _authLocalDataSource.saveAuthState(newAuthState);
      
      return newAuthState;
    } catch (e) {
      // If refresh fails, clear the auth state to force re-login
      await _authLocalDataSource.clearAuthState();
      throw TokenExpiredException('Token refresh failed: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  static Future<http.Response> get(String endpoint, {Duration? timeout}) async {
    return _makeRequest(() async {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders(endpoint);
      return await _httpClient.get(
        uri,
        headers: headers,
      ).timeout(timeout ?? _defaultTimeout);
    });
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body, {Duration? timeout}) async {
    return _makeRequest(() async {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final bodyJson = json.encode(body);
      final headers = await _getHeaders(endpoint);
      return await _httpClient.post(
        uri,
        headers: headers,
        body: bodyJson,
      ).timeout(timeout ?? _defaultTimeout);
    });
  }

  static Future<http.Response> put(String endpoint, Map<String, dynamic> body, {Duration? timeout}) async {
    return _makeRequest(() async {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders(endpoint);
      return await _httpClient.put(
        uri,
        headers: headers,
        body: json.encode(body),
      ).timeout(timeout ?? _defaultTimeout);
    });
  }

  static Future<http.Response> delete(String endpoint, {Duration? timeout}) async {
    return _makeRequest(() async {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders(endpoint);
      return await _httpClient.delete(
        uri,
        headers: headers,
      ).timeout(timeout ?? _defaultTimeout);
    });
  }

  static Future<http.Response> _makeRequest(Future<http.Response> Function() requestFunction) async {
    try {
      final response = await requestFunction();
      
      // If we get a 401 Unauthorized, it might be due to token expiration
      // Try to refresh the token and retry once
      if (response.statusCode == 401 && !_isRefreshing) {
        _isRefreshing = true;
        try {
          final authState = await _authLocalDataSource.getAuthState();
          if (authState.isAuthenticated && authState.refreshToken != null) {
            // Attempt to refresh the token
            await _refreshToken(authState.refreshToken!);
            // Retry the request with the new token
            final retryResponse = await requestFunction();
            
            // If retry also fails with 401, clear auth state and throw specific exception
            if (retryResponse.statusCode == 401) {
              await _authLocalDataSource.clearAuthState();
              throw TokenExpiredException('Session expired. Please log in again.');
            }
            
            return retryResponse;
          } else {
            // No refresh token available, clear auth state and throw specific exception
            await _authLocalDataSource.clearAuthState();
            throw TokenExpiredException('Session expired. Please log in again.');
          }
        } catch (e) {
          // If refresh fails, clear auth state and throw specific exception
          await _authLocalDataSource.clearAuthState();
          if (e is TokenExpiredException) {
            rethrow;
          }
          throw TokenExpiredException('Session expired. Please log in again.');
        } finally {
          _isRefreshing = false;
        }
      }
      
      return response;
    } catch (e) {
      if (e is UnauthorizedException || e is TokenExpiredException) {
        // Clear auth state on unauthorized exceptions
        await _authLocalDataSource.clearAuthState();
      }
      if (e is TokenExpiredException) {
        rethrow;
      }
      throw ApiException('Network error: $e');
    }
  }

  static void dispose() {
    _httpClient.close();
  }

  static void handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return; // Success
    }
    
    String errorMessage;
    try {
      final errorData = json.decode(response.body);
      
      // Handle cloud function gateway error format
      if (errorData['message'] != null) {
        errorMessage = errorData['message'];
      } else {
        errorMessage = errorData['error'] ?? 'Unknown error occurred';
      }
      
      // If there are validation details, include them
      if (errorData['details'] != null && errorData['details'] is List) {
        final details = (errorData['details'] as List).join(', ');
        errorMessage = '$errorMessage: $details';
      }
    } catch (e) {
      errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
    }
    
    switch (response.statusCode) {
      case 400:
        throw BadRequestException(errorMessage);
      case 401:
        throw UnauthorizedException(errorMessage);
      case 403:
        throw ForbiddenException(errorMessage);
      case 404:
        throw NotFoundException(errorMessage);
      case 429:
        throw RateLimitException(errorMessage);
      case 500:
      case 502:
      case 503:
      case 504:
        throw ServerException(errorMessage);
      default:
        throw ApiException('HTTP ${response.statusCode}: $errorMessage');
    }
  }
}

// API Exceptions
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  
  @override
  String toString() => 'ApiException: $message';
}

class BadRequestException extends ApiException {
  const BadRequestException(super.message);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message);
}

class ForbiddenException extends ApiException {
  const ForbiddenException(super.message);
}

class NotFoundException extends ApiException {
  const NotFoundException(super.message);
}

class RateLimitException extends ApiException {
  const RateLimitException(super.message);
}

class ServerException extends ApiException {
  const ServerException(super.message);
}

class TokenExpiredException extends ApiException {
  const TokenExpiredException(super.message);
} 