import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:instal_app/features/auth/data/datasources/auth_local_datasource.dart';

class ApiClient {
  static const String _baseUrl = 'https://d5degr4sfnv9p7i065ga.kf69zffa.apigw.yandexcloud.net';
  static const String _apiKey = 'AQVN1gWo_joBv9AiZVrbtOHPm46XIcO_z_YH4RQh';
  
  static const Duration _defaultTimeout = Duration(seconds: 10);
  
  static final http.Client _httpClient = http.Client();
  static final AuthLocalDataSource _authLocalDataSource = AuthLocalDataSourceImpl();
  
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
      
      // Check if token is expired
      if (authState.isTokenExpired) {
        throw UnauthorizedException('Access token expired');
      }
      
      headers['Authorization'] = 'Bearer ${authState.accessToken}';
    }
    
    return headers;
  }

  static Future<http.Response> get(String endpoint, {Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    
    try {
      final headers = await _getHeaders(endpoint);
      final response = await _httpClient.get(
        uri,
        headers: headers,
      ).timeout(timeout ?? _defaultTimeout);
      
      return response;
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body, {Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final bodyJson = json.encode(body);
    
    try {
      final headers = await _getHeaders(endpoint);
      final response = await _httpClient.post(
        uri,
        headers: headers,
        body: bodyJson,
      ).timeout(timeout ?? _defaultTimeout);
      
      return response;
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  static Future<http.Response> put(String endpoint, Map<String, dynamic> body, {Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    
    try {
      final headers = await _getHeaders(endpoint);
      final response = await _httpClient.put(
        uri,
        headers: headers,
        body: json.encode(body),
      ).timeout(timeout ?? _defaultTimeout);
      
      return response;
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  static Future<http.Response> delete(String endpoint, {Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    
    try {
      final headers = await _getHeaders(endpoint);
      final response = await _httpClient.delete(
        uri,
        headers: headers,
      ).timeout(timeout ?? _defaultTimeout);
      
      return response;
    } catch (e) {
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