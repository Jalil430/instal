import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

class WhatsAppConnectionStatusDesktop extends StatelessWidget {
  final Map<String, dynamic> testResult;

  const WhatsAppConnectionStatusDesktop({
    super.key,
    required this.testResult,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = testResult['success'] == true;
    final String message = testResult['message'] ?? '';
    final int? responseTime = testResult['response_time_ms'];
    final List<dynamic>? recommendations = testResult['recommendations'];

    return Container(
      padding: const EdgeInsets.all(16),
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
          // Status header
          Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? AppTheme.successColor : AppTheme.errorColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSuccess ? 'Connection Successful' : 'Connection Failed',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSuccess ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                ),
              ),
              if (responseTime != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${responseTime}ms',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          
          // Recommendations
          if (recommendations != null && recommendations.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              isSuccess ? 'Next Steps:' : 'Recommendations:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ...recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rec.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
          
          // Test details (if available)
          if (testResult['test_details'] != null) ...[
            const SizedBox(height: 12),
            _buildTestDetails(testResult['test_details']),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTestDetails(Map<String, dynamic> testDetails) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test Details:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ...testDetails.entries.map((entry) {
            final bool value = entry.value == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(
                    value ? Icons.check : Icons.close,
                    size: 14,
                    color: value ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTestDetailKey(entry.key),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
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