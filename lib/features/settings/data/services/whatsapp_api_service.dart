import 'dart:convert';
import '../../../../core/api/api_client.dart';

class WhatsAppApiService {
  static const String _baseEndpoint = '/whatsapp';

  /// Get WhatsApp settings for the current user
  static Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await ApiClient.get('$_baseEndpoint/settings');
      ApiClient.handleResponse(response);
      
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load WhatsApp settings: $e');
    }
  }

  /// Update WhatsApp settings
  static Future<Map<String, dynamic>> updateSettings({
    String? greenApiInstanceId,
    String? greenApiToken,
    String? reminderTemplate7Days,
    String? reminderTemplateDueToday,
    String? reminderTemplateManual,
    bool? isEnabled,
    bool testConnection = false,
  }) async {
    try {
      final body = <String, dynamic>{};
      
      if (greenApiInstanceId != null) {
        body['green_api_instance_id'] = greenApiInstanceId;
      }
      if (greenApiToken != null) {
        body['green_api_token'] = greenApiToken;
      }
      if (reminderTemplate7Days != null) {
        body['reminder_template_7_days'] = reminderTemplate7Days;
      }
      if (reminderTemplateDueToday != null) {
        body['reminder_template_due_today'] = reminderTemplateDueToday;
      }
      if (reminderTemplateManual != null) {
        body['reminder_template_manual'] = reminderTemplateManual;
      }
      if (isEnabled != null) {
        body['is_enabled'] = isEnabled;
      }
      if (testConnection) {
        body['test_connection'] = true;
      }

      final response = await ApiClient.put('$_baseEndpoint/settings', body);
      ApiClient.handleResponse(response);
      
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to update WhatsApp settings: $e');
    }
  }

  /// Test WhatsApp connection with provided credentials
  static Future<Map<String, dynamic>> testConnection({
    required String greenApiInstanceId,
    required String greenApiToken,
  }) async {
    try {
      final body = {
        'green_api_instance_id': greenApiInstanceId,
        'green_api_token': greenApiToken,
      };

      final response = await ApiClient.post('$_baseEndpoint/test-connection', body);
      ApiClient.handleResponse(response);
      
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to test WhatsApp connection: $e');
    }
  }

  /// Send manual WhatsApp reminder
  static Future<Map<String, dynamic>> sendManualReminder({
    required List<String> installmentIds,
    String templateType = 'manual',
  }) async {
    try {
      final body = {
        'installment_ids': installmentIds,
        'template_type': templateType,
      };

      final response = await ApiClient.post('$_baseEndpoint/send-manual-reminder', body);
      ApiClient.handleResponse(response);
      
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to send manual reminder: $e');
    }
  }
}