import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../error/global_error_handler.dart';
import 'api_client.dart';

class AuthInterceptor {
  /// Wrapper for API calls that automatically handles token expiration
  static Future<T> handleApiCall<T>(
    BuildContext context,
    Future<T> Function() apiCall, {
    bool showErrorSnackbar = true,
  }) async {
    try {
      return await apiCall();
    } catch (error) {
      if (error is TokenExpiredException) {
        // Handle token expiration specifically
        if (context.mounted) {
          _handleTokenExpiration(context);
        }
        rethrow;
      } else if (error is UnauthorizedException) {
        // Handle unauthorized access
        if (context.mounted) {
          _handleUnauthorized(context);
        }
        rethrow;
      } else {
        // Handle other errors
        if (showErrorSnackbar && context.mounted) {
          GlobalErrorHandler.handleError(context, error);
        }
        rethrow;
      }
    }
  }

  static void _handleTokenExpiration(BuildContext context) {
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
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (context.mounted) {
        context.go('/auth/login');
      }
    });
  }

  static void _handleUnauthorized(BuildContext context) {
    // Clear any existing snackbars
    ScaffoldMessenger.of(context).clearSnackBars();
    
    // Show unauthorized message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Access denied. Please log in again.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );

    // Redirect to login after a short delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (context.mounted) {
        context.go('/auth/login');
      }
    });
  }
}