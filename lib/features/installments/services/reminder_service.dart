import 'package:flutter/material.dart';
import '../../settings/data/services/whatsapp_api_service.dart';
import '../../../core/widgets/error_boundary.dart';
import '../../../core/services/connectivity_service.dart';

class ReminderService {
  /// Send a WhatsApp reminder for a single installment
  static Future<void> sendSingleReminder({
    required BuildContext context,
    required String installmentId,
    String templateType = 'manual',
  }) async {
    return _sendReminders(
      context: context,
      installmentIds: [installmentId],
      templateType: templateType,
      isBulk: false,
    );
  }

  /// Send WhatsApp reminders for multiple installments
  static Future<void> sendBulkReminders({
    required BuildContext context,
    required List<String> installmentIds,
    String templateType = 'manual',
  }) async {
    return _sendReminders(
      context: context,
      installmentIds: installmentIds,
      templateType: templateType,
      isBulk: true,
    );
  }

  /// Internal method to send reminders with proper UI feedback
  static Future<void> _sendReminders({
    required BuildContext context,
    required List<String> installmentIds,
    required String templateType,
    required bool isBulk,
  }) async {
    if (installmentIds.isEmpty) {
      ErrorHandler.showErrorSnackBar(context, 'No installments selected');
      return;
    }

    // Check connectivity first
    final connectivityService = ConnectivityService();
    final isConnected = await connectivityService.checkConnectivity();
    
    if (!isConnected) {
      ErrorHandler.showErrorSnackBar(
        context, 
        'No internet connection. Please check your network and try again.',
        onRetry: () => _sendReminders(
          context: context,
          installmentIds: installmentIds,
          templateType: templateType,
          isBulk: isBulk,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              isBulk
                  ? 'Sending ${installmentIds.length} WhatsApp reminders...'
                  : 'Sending WhatsApp reminder...',
            ),
          ],
        ),
      ),
    );

    try {
      // Call the API to send the reminder(s)
      final result = await WhatsAppApiService.sendManualReminder(
        installmentIds: installmentIds,
        templateType: templateType,
      );

      // Close loading dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show appropriate success or error message
      if (result['successful_sends'] != null && result['successful_sends'] > 0) {
        if (result['failed_sends'] != null && result['failed_sends'] > 0) {
          // Partial success
          _showPartialSuccessDialog(
            context,
            result['successful_sends'],
            result['failed_sends'],
            result['results'],
          );
        } else {
          // Complete success
          ErrorHandler.showSuccessSnackBar(
            context,
            isBulk
                ? '${result['successful_sends']} reminders sent successfully!'
                : 'WhatsApp reminder sent successfully!',
          );
        }
      } else {
        // Complete failure
        final errors = (result['results'] as List?)
                ?.map((r) => r['error'] ?? 'Unknown error')
                .toSet()
                .toList() ??
            ['Unknown error'];

        _showErrorDialog(
          context,
          'Failed to send ${isBulk ? 'reminders' : 'reminder'}',
          errors.join('\n'),
          onRetry: ErrorHandler.isRetryable(errors.first) ? () => _sendReminders(
            context: context,
            installmentIds: installmentIds,
            templateType: templateType,
            isBulk: isBulk,
          ) : null,
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show user-friendly error message with retry option
      ErrorHandler.showErrorSnackBar(
        context,
        e,
        onRetry: ErrorHandler.isRetryable(e) ? () => _sendReminders(
          context: context,
          installmentIds: installmentIds,
          templateType: templateType,
          isBulk: isBulk,
        ) : null,
      );
    }
  }

  /// Show a success snackbar
  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show an error snackbar
  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show a dialog for partial success (some succeeded, some failed)
  static void _showPartialSuccessDialog(
    BuildContext context,
    int successCount,
    int failedCount,
    List<dynamic>? results,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Partial Success'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$successCount reminders sent successfully, $failedCount failed.',
            ),
            const SizedBox(height: 16),
            const Text('Failed reminders:'),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (results != null)
                      ...results
                          .where((r) => r['status'] == 'failed')
                          .map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '• ${r['client_name'] ?? 'Unknown'}: ${r['error'] ?? 'Unknown error'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ))
                          .toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show an error dialog
  static void _showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}