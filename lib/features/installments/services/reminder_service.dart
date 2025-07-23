import 'package:flutter/material.dart';
import '../../settings/data/services/whatsapp_api_service.dart';
import '../../../core/widgets/error_boundary.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/localization/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    
    if (installmentIds.isEmpty) {
      ErrorHandler.showErrorSnackBar(context, l10n?.noInstallmentsSelected ?? 'No installments selected');
      return;
    }

    // Check connectivity first
    final connectivityService = ConnectivityService();
    final isConnected = await connectivityService.checkConnectivity();
    
    if (!isConnected) {
      ErrorHandler.showErrorSnackBar(
        context, 
        l10n?.noInternetConnection ?? 'No internet connection. Please check your network and try again.',
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
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                isBulk
                    ? '${l10n?.sendingWhatsAppReminder ?? 'Sending WhatsApp reminder...'} (${installmentIds.length})'
                    : l10n?.sendingWhatsAppReminder ?? 'Sending WhatsApp reminder...',
              ),
            ],
          ),
        );
      },
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
          final l10n = AppLocalizations.of(context);
          ErrorHandler.showSuccessSnackBar(
            context,
            isBulk
                ? '${result['successful_sends']} ${l10n?.reminderSentMultiple ?? 'Reminders sent'}!'
                : '${l10n?.reminderSent ?? 'Reminder sent'}!',
          );
        }
      } else {
        // Complete failure
        final errors = (result['results'] as List?)
                ?.map((r) => r['error'] ?? 'Unknown error')
                .toSet()
                .toList() ??
            ['Unknown error'];

        final l10n = AppLocalizations.of(context);
        _showErrorDialog(
          context,
          isBulk
              ? l10n?.failedToSendReminders ?? 'Failed to send reminders'
              : l10n?.failedToSendReminder ?? 'Failed to send reminder',
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
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.partialSuccess ?? 'Partial Success'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n?.remindersSentPartial ?? '$successCount reminders sent successfully, $failedCount failed.'}',
            ),
            const SizedBox(height: 16),
            Text(l10n?.failedReminders ?? 'Failed reminders:'),
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
                                  '• ${r['client_name'] ?? l10n?.unknown ?? 'Unknown'}: ${r['error'] ?? l10n?.unknownError ?? 'Unknown error'}',
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
            child: Text(l10n?.ok ?? 'OK'),
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
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.ok ?? 'OK'),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text(l10n?.retry ?? 'Retry'),
            ),
        ],
      ),
    );
  }
}