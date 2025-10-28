import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:instal_app/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:instal_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:instal_app/features/auth/domain/entities/auth_state.dart';

class ApiClient {
  static const String _baseUrl = 'https://d5degr4sfnv9p7i065ga.kf69zffa.apigw.yandexcloud.net';
  static const String _apiKey = '05edf99238bc0c342aa0cc48be2363ffcebbbf15b7d0eaca4f31dbd6a03d30be';
  
  // Default overall request timeout. Heavy endpoints override when needed.
  static const Duration _defaultTimeout = Duration(seconds: 20);
  
  static final http.Client _httpClient = http.Client();
  static final AuthLocalDataSource _authLocalDataSource = AuthLocalDataSourceImpl();
  static final AuthRemoteDataSource _authRemoteDataSource = AuthRemoteDataSourceImpl();
  

  
  static String get baseUrl => _baseUrl;
  static String get apiKey => _apiKey;
  static http.Client get httpClient => _httpClient;
  static Duration get defaultTimeout => _defaultTimeout;
  
  static Future<Map<String, String>> _getHeaders([String? endpoint]) async {
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
      // Auth endpoints use API key authentication - no need to check existing tokens
      headers['X-API-Key'] = _apiKey;
    } else {
      // Business endpoints require JWT authentication
      var authState = await _authLocalDataSource.getAuthState();
      
      if (!authState.isAuthenticated || authState.accessToken == null) {
        throw UnauthorizedException('User not authenticated');
      }
      
      // If token expired, attempt refresh once using refresh token
      if (authState.isTokenExpired) {
        final refreshed = await _tryRefreshToken(authState);
        if (!refreshed) {
          await _authLocalDataSource.clearAuthState();
          throw TokenExpiredException('Session expired. Please log in again.');
        }
        // Reload auth state after refresh
        authState = await _authLocalDataSource.getAuthState();
      }
      
      // Use the current token (valid for 7 days)
      headers['Authorization'] = 'Bearer ${authState.accessToken}';
    }
    
    return headers;
  }



  static Future<http.Response> get(String endpoint, {Duration? timeout}) async {
    return _makeRequest('GET', () async {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders(endpoint);
      return await _httpClient.get(
        uri,
        headers: headers,
      ).timeout(timeout ?? _defaultTimeout);
    });
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body, {Duration? timeout}) async {
    return _makeRequest('POST', () async {
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
    return _makeRequest('PUT', () async {
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
    return _makeRequest('DELETE', () async {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _getHeaders(endpoint);
      return await _httpClient.delete(
        uri,
        headers: headers,
      ).timeout(timeout ?? _defaultTimeout);
    });
  }

  static Future<http.Response> _makeRequest(String method, Future<http.Response> Function() requestFunction) async {
    try {
      final response = await _sendWithRetries(method, requestFunction);
      
      // If we get a 401 Unauthorized, the token is expired - clear auth state
      if (response.statusCode == 401) {
        // Try to refresh once and retry the original request
        final authState = await _authLocalDataSource.getAuthState();
        final refreshed = authState.isAuthenticated ? await _tryRefreshToken(authState) : false;
        if (refreshed) {
          // Retry once with new token (with transient retries again)
          final retryResponse = await _sendWithRetries(method, requestFunction);
          if (retryResponse.statusCode != 401) {
            return retryResponse;
          }
        }
        await _authLocalDataSource.clearAuthState();
        throw TokenExpiredException('Session expired. Please log in again.');
      }
      
      return response;
    } on RequestTimeoutException {
      // Surface timeouts distinctly so UI can react (retry/CTA)
      rethrow;
    } catch (e) {
      if (e is TokenExpiredException) {
        rethrow;
      }
      throw ApiException('Network error: $e');
    }
  }

  static bool _isRetryableStatus(int code) {
    return code == 429 || code == 502 || code == 503 || code == 504;
  }

  // Best-effort transient retry for GET/DELETE. POST/PUT are not retried by default to avoid side effects.
  static Future<http.Response> _sendWithRetries(String method, Future<http.Response> Function() send) async {
    final bool allowRetry = method == 'GET' || method == 'DELETE';
    const int maxAttempts = 3;
    Duration backoff = const Duration(milliseconds: 300);
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final resp = await send();
        if (allowRetry && _isRetryableStatus(resp.statusCode) && attempt < maxAttempts) {
          final retryAfter = resp.headers['retry-after'];
          if (retryAfter != null) {
            final parsed = int.tryParse(retryAfter);
            if (parsed != null && parsed > 0) {
              await Future.delayed(Duration(seconds: parsed));
            } else {
              await Future.delayed(backoff);
              backoff *= 2;
            }
          } else {
            await Future.delayed(backoff);
            backoff *= 2;
          }
          continue;
        }
        return resp;
      } on TimeoutException {
        if (allowRetry && attempt < maxAttempts) {
          await Future.delayed(backoff);
          backoff *= 2;
          continue;
        }
        throw const RequestTimeoutException('Request timed out');
      } on http.ClientException catch (_) {
        if (allowRetry && attempt < maxAttempts) {
          await Future.delayed(backoff);
          backoff *= 2;
          continue;
        }
        rethrow;
      }
    }
  }

  // Attempt to refresh tokens using stored refresh token
  static Future<bool> _tryRefreshToken(AuthState current) async {
    try {
      final refreshToken = current.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) return false;
      final newState = await _authRemoteDataSource.refreshToken(refreshToken);
      await _authLocalDataSource.saveAuthState(newState);
      return true;
    } catch (_) {
      return false;
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
      case 409:
        throw ConflictException(errorMessage);
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

class ConflictException extends ApiException {
  const ConflictException(super.message);
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

class RequestTimeoutException extends ApiException {
  const RequestTimeoutException(super.message);
}
