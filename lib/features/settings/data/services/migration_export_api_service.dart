import 'dart:convert';

import '../../../../core/api/api_client.dart';
import 'migration_export_downloader.dart';

class MigrationExportApiService {
  static const String _endpoint = '/migration/export';
  static const Duration _exportTimeout = Duration(seconds: 120);
  static const List<String> _pagedSections = <String>[
    'investors',
    'accounts',
    'clients',
    'installments',
    'payments',
    'warnings',
  ];

  static Future<String> exportAndDownload() async {
    final decoded = await _loadExportPayload();

    final exportDate = DateTime.now().toIso8601String().split('T').first;
    final filename = 'finpay-legacy-export-$exportDate.json';
    final content = const JsonEncoder().convert(decoded);

    downloadMigrationExport(filename, content);
    return filename;
  }

  static Future<Map<String, dynamic>> _loadExportPayload() async {
    final response = await ApiClient.get(
      _buildEndpoint(const <String, String>{'mode': 'manifest'}),
      timeout: _exportTimeout,
    );
    ApiClient.handleResponse(response);

    final decoded = _decodeJsonMap(response.body);
    if (_isPagedManifest(decoded)) {
      return _downloadPagedExport(decoded);
    }

    if (_isLegacyPayload(decoded)) {
      return decoded;
    }

    throw Exception('Invalid export payload');
  }

  static Future<Map<String, dynamic>> _downloadPagedExport(
    Map<String, dynamic> manifest,
  ) async {
    final sections = manifest['sections'];
    final pageSize = manifest['page_size'];

    if (sections is! Map || pageSize is! int || pageSize <= 0) {
      throw Exception('Invalid export manifest');
    }

    final normalizedSections = Map<String, dynamic>.from(sections);
    final exportPayload = <String, dynamic>{};

    for (final section in _pagedSections) {
      final rawSectionMeta = normalizedSections[section];
      if (rawSectionMeta is! Map) {
        throw Exception('Invalid export manifest section: $section');
      }

      final sectionMeta = Map<String, dynamic>.from(rawSectionMeta);
      final total = sectionMeta['total'];
      if (total is! int || total < 0) {
        throw Exception('Invalid total for export section: $section');
      }

      exportPayload[section] = await _downloadSection(section, total, pageSize);
    }

    final warnings = exportPayload['warnings'];
    if (warnings is List && warnings.isEmpty) {
      exportPayload.remove('warnings');
    }

    return exportPayload;
  }

  static Future<List<dynamic>> _downloadSection(
    String section,
    int total,
    int pageSize,
  ) async {
    if (total == 0) {
      return <dynamic>[];
    }

    final items = <dynamic>[];
    var offset = 0;

    while (items.length < total) {
      final response = await ApiClient.get(
        _buildEndpoint(<String, String>{
          'mode': 'page',
          'section': section,
          'offset': '$offset',
          'limit': '$pageSize',
        }),
        timeout: _exportTimeout,
      );
      ApiClient.handleResponse(response);

      final decoded = _decodeJsonMap(response.body);
      if (decoded['section'] != section) {
        throw Exception('Received wrong export section: ${decoded['section']}');
      }

      final pageItems = decoded['items'];
      final hasMore = decoded['has_more'];
      if (pageItems is! List || hasMore is! bool) {
        throw Exception('Invalid export page for section: $section');
      }

      items.addAll(pageItems);

      if (pageItems.isEmpty) {
        break;
      }

      offset += pageItems.length;
      if (!hasMore) {
        break;
      }
    }

    if (items.length != total) {
      throw Exception(
        'Export section count mismatch for $section. Expected $total, got ${items.length}.',
      );
    }

    return items;
  }

  static String _buildEndpoint(Map<String, String> queryParameters) {
    if (queryParameters.isEmpty) {
      return _endpoint;
    }

    final query = Uri(queryParameters: queryParameters).query;
    return '$_endpoint?$query';
  }

  static Map<String, dynamic> _decodeJsonMap(String body) {
    final decoded = json.decode(body);
    if (decoded is! Map) {
      throw Exception('Invalid export payload');
    }

    return Map<String, dynamic>.from(decoded);
  }

  static bool _isPagedManifest(Map<String, dynamic> decoded) {
    final sections = decoded['sections'];
    final pageSize = decoded['page_size'];
    return sections is Map && pageSize is int && pageSize > 0;
  }

  static bool _isLegacyPayload(Map<String, dynamic> decoded) {
    final clients = decoded['clients'];
    final installments = decoded['installments'];
    final payments = decoded['payments'];
    final investors = decoded['investors'];
    final accounts = decoded['accounts'];
    final warnings = decoded['warnings'];

    final hasRequiredLists =
        clients is List && installments is List && payments is List;
    final hasOptionalLists =
        (investors == null || investors is List) &&
        (accounts == null || accounts is List) &&
        (warnings == null || warnings is List);

    return hasRequiredLists && hasOptionalLists;
  }
}
