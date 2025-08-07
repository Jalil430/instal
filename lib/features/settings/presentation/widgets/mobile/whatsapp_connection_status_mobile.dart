import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

class WhatsAppConnectionStatusMobile extends StatelessWidget {
  final Map<String, dynamic> testResult;

  const WhatsAppConnectionStatusMobile({
    super.key,
    required this.testResult,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = testResult['success'] == true;
    final String message = testResult['message'] ?? '';
    final List<dynamic>? recommendations = testResult['recommendations'];

    return Container(
      padding: const EdgeInsets.all(12), // Less padding for mobile
      decoration: BoxDecoration(
        color: isSuccess 
            ? AppTheme.successColor.withOpacity(0.1)
            : AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuccess 
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.errorColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header - more compact for mobile
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? AppTheme.successColor : AppTheme.errorColor,
                size: 18, // Smaller for mobile
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSuccess ? 'Connection Successful' : 'Connection Failed',
                      style: TextStyle(
                        fontSize: 13, // Smaller for mobile
                        fontWeight: FontWeight.w600,
                        color: isSuccess ? AppTheme.successColor : AppTheme.errorColor,
                      ),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 4), // Less spacing for mobile
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 12, // Smaller for mobile
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          // Recommendations - more compact for mobile
          if (recommendations != null && recommendations.isNotEmpty) ...[
            const SizedBox(height: 10), // Less spacing for mobile
            Text(
              isSuccess ? 'Next Steps:' : 'Recommendations:',
              style: TextStyle(
                fontSize: 12, // Smaller for mobile
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4), // Less spacing for mobile
            ...recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 2), // Less padding for mobile
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5), // Adjusted for mobile
                    width: 3, // Smaller for mobile
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  const SizedBox(width: 6), // Less spacing for mobile
                  Expanded(
                    child: Text(
                      rec.toString(),
                      style: TextStyle(
                        fontSize: 11, // Smaller for mobile
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
          
          // Test details - simplified for mobile
          if (testResult['test_details'] != null) ...[
            const SizedBox(height: 10), // Less spacing for mobile
            // Collapsible test details
            ExpansionTile(
              tilePadding: EdgeInsets.zero, // Remove default padding
              childrenPadding: EdgeInsets.zero, // Remove default padding
              title: Text(
                'Test Details',
                style: TextStyle(
                  fontSize: 12, // Smaller for mobile
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16), // Indent children
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...testResult['test_details'].entries.map((entry) {
                        final bool value = entry.value == true;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              Icon(
                                value ? Icons.check : Icons.close,
                                size: 12, // Smaller for mobile
                                color: value ? AppTheme.successColor : AppTheme.errorColor,
                              ),
                              const SizedBox(width: 4), // Less spacing for mobile
                              Text(
                                _formatTestDetailKey(entry.key),
                                style: TextStyle(
                                  fontSize: 10, // Smaller for mobile
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  String _formatTestDetailKey(String key) {
    switch (key) {
      case 'endpoint_reachable':
        return 'Endpoint reachable';
      case 'credentials_valid':
        return 'Credentials valid';
      case 'api_responsive':
        return 'API responsive';
      default:
        return key.replaceAll('_', ' ').toLowerCase();
    }
  }
} 