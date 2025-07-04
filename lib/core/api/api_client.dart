import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String _baseUrl = 'https://d5degr4sfnv9p7i065ga.kf69zffa.apigw.yandexcloud.net';
  static const String _apiKey = '05edf99238bc0c342aa0cc48be2363ffcebbbf15b7d0eaca4f31dbd6a03d30be';
  
  static const Duration _defaultTimeout = Duration(seconds: 10); // Reduced from 30 to 10
  
  // Create a persistent HTTP client for connection pooling
  static final http.Client _httpClient = http.Client();
  
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-API-Key': _apiKey,
    'Connection': 'keep-alive', // Enable connection reuse
  };

  static Future<http.Response> get(String endpoint, {Duration? timeout}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    
    try {
      final response = await _httpClient.get(
        uri,
        headers: _headers,
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
      final response = await _httpClient.post(
        uri,
        headers: _headers,
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
      final response = await _httpClient.put(
        uri,
        headers: _headers,
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
      final response = await _httpClient.delete(
        uri,
        headers: _headers,
      ).timeout(timeout ?? _defaultTimeout);
      
      return response;
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  // Clean up the HTTP client when the app shuts down
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
      errorMessage = errorData['error'] ?? 'Unknown error occurred';
      
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