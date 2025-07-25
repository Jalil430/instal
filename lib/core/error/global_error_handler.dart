import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api/api_client.dart';

class GlobalErrorHandler {
  static void handleError(BuildContext context, dynamic error) {
    if (error is TokenExpiredException) {
      _handleTokenExpired(context);
    } else if (error is UnauthorizedException) {
      _handleUnauthorized(context);
    } else if (error is ServerException) {
      _handleServerError(context, error.message);
    } else if (error is ApiException) {
      _handleApiError(context, error.message);
    } else {
      _handleGenericError(context, error.toString());
    }
  }

  static void _handleTokenExpired(BuildContext context) {
    // Clear any existing snackbars
    ScaffoldMessenger.of(context).clearSnackBars();
    
    // Show session expired message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your session has expired. Please log in again.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );

    // Redirect to login after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (context.mounted) {
        context.go('/auth/login');
      }
    });
  }

  static void _handleUnauthorized(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Access denied. Please log in.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (context.mounted) {
        context.go('/auth/login');
      }
    });
  }

  static void _handleServerError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Server error: $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static void _handleApiError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('An error occurred: $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void _handleGenericError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unexpected error: $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Wrapper function to handle async operations with automatic error handling
  static Future<T?> handleAsyncOperation<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? loadingMessage,
    String? successMessage,
  }) async {
    try {
      final result = await operation();
      
      if (successMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      return result;
    } catch (error) {
      if (context.mounted) {
        handleError(context, error);
      }
      return null;
    }
  }
}