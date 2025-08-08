/// Base class for all subscription-related exceptions
abstract class SubscriptionException implements Exception {
  final String message;
  final String? code;

  const SubscriptionException(this.message, [this.code]);

  @override
  String toString() => 'SubscriptionException: $message';
}

/// Thrown when a subscription code is invalid or doesn't exist
class InvalidCodeException extends SubscriptionException {
  const InvalidCodeException([String? message]) 
      : super(message ?? 'The subscription code is invalid or does not exist', 'INVALID_CODE');
}

/// Thrown when a subscription code has already been used by another user
class CodeAlreadyUsedException extends SubscriptionException {
  const CodeAlreadyUsedException([String? message]) 
      : super(message ?? 'This subscription code has already been used', 'CODE_ALREADY_USED');
}

/// Thrown when a subscription code has expired
class ExpiredCodeException extends SubscriptionException {
  const ExpiredCodeException([String? message]) 
      : super(message ?? 'This subscription code has expired', 'CODE_EXPIRED');
}

/// Thrown when there's a network error during subscription operations
class NetworkException extends SubscriptionException {
  const NetworkException([String? message]) 
      : super(message ?? 'Network error occurred. Please check your connection and try again', 'NETWORK_ERROR');
}

/// Thrown when the server returns an unexpected error
class ServerException extends SubscriptionException {
  const ServerException([String? message]) 
      : super(message ?? 'Server error occurred. Please try again later', 'SERVER_ERROR');
}