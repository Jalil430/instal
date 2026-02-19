import 'dart:convert';

import '../../../../core/api/api_client.dart';
import 'migration_export_downloader.dart';

class MigrationExportApiService {
  static const String _endpoint = '/migration/export';

  static Future<String> exportAndDownload() async {
    final response = await ApiClient.get(
      _endpoint,
      timeout: const Duration(seconds: 120),
    );
    ApiClient.handleResponse(response);

    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid export payload');
    }

    final clients = decoded['clients'];
    final installments = decoded['installments'];
    final payments = decoded['payments'];

    if (clients is! List || installments is! List || payments is! List) {
      throw Exception('Export payload is missing required arrays');
    }

    final exportDate = DateTime.now().toIso8601String().split('T').first;
    final filename = 'finpay-legacy-export-$exportDate.json';
    final content = const JsonEncoder.withIndent('  ').convert(decoded);

    downloadMigrationExport(filename, content);
    return filename;
  }
}
