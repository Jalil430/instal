import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:http/http.dart' as http;

/// Green API client wrapper for WhatsApp messaging
class WhatsAppService {
  static const String _baseUrl = 'https://api.green-api.com';
  
  final String instanceId;
  final String token;
  final http.Client _httpClient;
  
  // Rate limiting properties
  static const int _maxRequestsPerMinute = 30; // Green API typical limit
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  static final Map<String, List<DateTime>> _requestHistory = {};
  static final Map<String, DateTime> _lastRateLimitReset = {};

  WhatsAppService({
    required this.instanceId,
    required this.token,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Get the base URL for Green API requests
  String get _apiUrl => '$_baseUrl/waInstance$instanceId';

  /// Get common headers for Green API requests
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Send a text message via Green API with retry logic
  Future<Map<String, dynamic>> sendTextMessage({
    required String phoneNumber,
    required String message,
    int maxRetries = 3,
  }) async {
    // Validate phone number
    if (!isValidPhoneNumber(phoneNumber)) {
      throw WhatsAppException(
        'Invalid phone number format: $phoneNumber',
        retryable: false,
      );
    }

    return await _executeWithRetry(
      () => _sendTextMessageInternal(phoneNumber, message),
      maxRetries: maxRetries,
      operation: 'sendTextMessage',
    );
  }

  /// Send a templated message with variable substitution
  Future<Map<String, dynamic>> sendTemplatedMessage({
    required String phoneNumber,
    required String template,
    required Map<String, String> variables,
    int maxRetries = 3,
  }) async {
    // Process template with variables
    final processedMessage = processMessageTemplate(template, variables);
    
    return await sendTextMessage(
      phoneNumber: phoneNumber,
      message: processedMessage,
      maxRetries: maxRetries,
    );
  }

  /// Internal method to send text message (without retry logic)
  Future<Map<String, dynamic>> _sendTextMessageInternal(
    String phoneNumber,
    String message,
  ) async {
    // Check rate limiting before making request
    await _checkRateLimit();
    
    _logRequest('sendTextMessage', {
      'phoneNumber': phoneNumber,
      'message': message.length > 50 ? '${message.substring(0, 50)}...' : message,
    });

    final url = '$_apiUrl/sendMessage/$token';
    final body = {
      'chatId': _formatPhoneNumber(phoneNumber),
      'message': message,
    };

    final response = await _httpClient.post(
      Uri.parse(url),
      headers: _headers,
      body: json.encode(body),
    );

    // Record this request for rate limiting
    _recordRequest();

    final result = await _handleResponse(response);
    
    _logResponse('sendTextMessage', result);
    return result;
  }

  /// Check if we're within rate limits, wait if necessary
  Future<void> _checkRateLimit() async {
    final instanceKey = instanceId;
    final now = DateTime.now();
    
    // Initialize request history for this instance if needed
    _requestHistory[instanceKey] ??= [];
    
    // Clean up old requests outside the rate limit window
    _requestHistory[instanceKey]!.removeWhere(
      (requestTime) => now.difference(requestTime) > _rateLimitWindow,
    );
    
    // Check if we're at the rate limit
    if (_requestHistory[instanceKey]!.length >= _maxRequestsPerMinute) {
      // Calculate how long to wait
      final oldestRequest = _requestHistory[instanceKey]!.first;
      final waitTime = _rateLimitWindow - now.difference(oldestRequest);
      
      if (waitTime.inMilliseconds > 0) {
        developer.log(
          'Rate limit reached. Waiting ${waitTime.inMilliseconds}ms...',
          name: 'WhatsAppService',
          level: 900, // Warning level
        );
        
        await Future.delayed(waitTime);
        
        // Clean up again after waiting
        final newNow = DateTime.now();
        _requestHistory[instanceKey]!.removeWhere(
          (requestTime) => newNow.difference(requestTime) > _rateLimitWindow,
        );
      }
    }
  }

  /// Record a request for rate limiting purposes
  void _recordRequest() {
    final instanceKey = instanceId;
    final now = DateTime.now();
    
    _requestHistory[instanceKey] ??= [];
    _requestHistory[instanceKey]!.add(now);
    _lastRateLimitReset[instanceKey] = now;
  }

  /// Get current rate limit status
  Map<String, dynamic> getRateLimitStatus() {
    final instanceKey = instanceId;
    final now = DateTime.now();
    
    _requestHistory[instanceKey] ??= [];
    
    // Clean up old requests
    _requestHistory[instanceKey]!.removeWhere(
      (requestTime) => now.difference(requestTime) > _rateLimitWindow,
    );
    
    final currentRequests = _requestHistory[instanceKey]!.length;
    final remainingRequests = _maxRequestsPerMinute - currentRequests;
    
    DateTime? resetTime;
    if (_requestHistory[instanceKey]!.isNotEmpty) {
      final oldestRequest = _requestHistory[instanceKey]!.first;
      resetTime = oldestRequest.add(_rateLimitWindow);
    }
    
    return {
      'current_requests': currentRequests,
      'max_requests': _maxRequestsPerMinute,
      'remaining_requests': remainingRequests,
      'window_duration_minutes': _rateLimitWindow.inMinutes,
      'reset_time': resetTime?.toIso8601String(),
      'is_rate_limited': remainingRequests <= 0,
    };
  }

  /// Process message template with variable substitution
  static String processMessageTemplate(
    String template,
    Map<String, String> variables,
  ) {
    String processedMessage = template;
    
    // Replace each variable in the template
    variables.forEach((key, value) {
      // Support both {variable} and {{variable}} formats
      processedMessage = processedMessage.replaceAll('{$key}', value);
      processedMessage = processedMessage.replaceAll('{{$key}}', value);
    });
    
    return processedMessage;
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters for validation
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's a valid length (7-15 digits as per E.164 standard)
    if (cleaned.length < 7 || cleaned.length > 15) {
      return false;
    }
    
    // Check if it contains only digits
    return RegExp(r'^\d+$').hasMatch(cleaned);
  }

  /// Execute operation with retry logic and exponential backoff
  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation, {
    required int maxRetries,
    required String operationName,
  }) async {
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        if (e is WhatsAppException && !e.retryable) {
          // Don't retry non-retryable errors
          rethrow;
        }
        
        if (attempt >= maxRetries) {
          // Max retries reached
          _logError('$operationName (final attempt)', e);
          rethrow;
        }
        
        // Calculate exponential backoff delay
        final delaySeconds = pow(2, attempt - 1).toInt();
        final jitter = Random().nextInt(1000); // Add jitter to prevent thundering herd
        final totalDelay = Duration(seconds: delaySeconds, milliseconds: jitter);
        
        _logError('$operationName (attempt $attempt/$maxRetries)', e);
        developer.log(
          'Retrying in ${totalDelay.inMilliseconds}ms...',
          name: 'WhatsAppService',
          level: 900, // Warning level
        );
        
        await Future.delayed(totalDelay);
      }
    }
    
    throw WhatsAppException('Max retries exceeded for $operationName');
  }

  /// Test the connection to Green API
  Future<Map<String, dynamic>> testConnection() async {
    try {
      _logRequest('testConnection', {'instanceId': instanceId});

      final url = '$_apiUrl/getSettings/$token';
      
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: _headers,
      );

      final result = await _handleResponse(response);
      
      _logResponse('testConnection', result);
      return result;
    } catch (e) {
      _logError('testConnection', e);
      rethrow;
    }
  }

  /// Get account information from Green API
  Future<Map<String, dynamic>> getAccountInfo() async {
    try {
      _logRequest('getAccountInfo', {'instanceId': instanceId});

      final url = '$_apiUrl/getWaSettings/$token';
      
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: _headers,
      );

      final result = await _handleResponse(response);
      
      _logResponse('getAccountInfo', result);
      return result;
    } catch (e) {
      _logError('getAccountInfo', e);
      rethrow;
    }
  }

  /// Format phone number for Green API (must include country code and @c.us suffix)
  String _formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Add country code if not present (assuming +7 for Russian numbers)
    if (!cleaned.startsWith('7') && cleaned.length == 10) {
      cleaned = '7$cleaned';
    }
    
    // Add @c.us suffix for Green API
    return '$cleaned@c.us';
  }

  /// Handle HTTP response and parse JSON
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final responseBody = response.body;
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return json.decode(responseBody) as Map<String, dynamic>;
      } catch (e) {
        throw WhatsAppException(
          'Failed to parse response JSON: $e',
          statusCode: response.statusCode,
          retryable: false,
        );
      }
    } else {
      // Try to parse error response
      Map<String, dynamic>? errorData;
      try {
        errorData = json.decode(responseBody) as Map<String, dynamic>;
      } catch (_) {
        // Ignore JSON parsing errors for error responses
      }

      final errorMessage = errorData?['error'] ?? 
                          errorData?['message'] ?? 
                          'HTTP ${response.statusCode}: ${response.reasonPhrase}';

      throw WhatsAppException(
        errorMessage,
        statusCode: response.statusCode,
        retryable: _isRetryableError(response.statusCode),
        errorData: errorData,
      );
    }
  }

  /// Determine if an error is retryable based on status code
  bool _isRetryableError(int statusCode) {
    return statusCode >= 500 || // Server errors
           statusCode == 429 || // Rate limiting
           statusCode == 408;   // Request timeout
  }

  /// Log API request for debugging
  void _logRequest(String method, Map<String, dynamic> params) {
    developer.log(
      'WhatsApp API Request: $method',
      name: 'WhatsAppService',
      level: 800, // Info level
      error: null,
      stackTrace: null,
      zone: null,
      time: DateTime.now(),
    );
    
    developer.log(
      'Request params: ${json.encode(params)}',
      name: 'WhatsAppService',
      level: 700, // Debug level
    );
  }

  /// Log API response for debugging
  void _logResponse(String method, Map<String, dynamic> response) {
    developer.log(
      'WhatsApp API Response: $method',
      name: 'WhatsAppService',
      level: 800, // Info level
    );
    
    developer.log(
      'Response data: ${json.encode(response)}',
      name: 'WhatsAppService',
      level: 700, // Debug level
    );
  }

  /// Log API error for debugging
  void _logError(String method, dynamic error) {
    developer.log(
      'WhatsApp API Error: $method',
      name: 'WhatsAppService',
      level: 1000, // Error level
      error: error,
      stackTrace: error is Error ? error.stackTrace : null,
    );
  }

  /// Dispose of resources
  void dispose() {
    _httpClient.close();
  }
}

/// Custom exception for WhatsApp API errors
class WhatsAppException implements Exception {
  final String message;
  final int? statusCode;
  final bool retryable;
  final Map<String, dynamic>? errorData;

  const WhatsAppException(
    this.message, {
    this.statusCode,
    this.retryable = false,
    this.errorData,
  });

  @override
  String toString() {
    return 'WhatsAppException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
  }
}