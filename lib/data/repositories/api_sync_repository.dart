import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';

class ApiSyncRepository {
  static const _baseUrlKey = 'https://daniel.shuttermultimediasv.com/';
  static const _endpointPathKey = 'api_endpoint_path';
  static const _defaultEndpointPath = '/api/finanzas-personales/movimiento/flutter/crear';

  Future<void> saveConfig({
    required String baseUrl,
    required String endpointPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, baseUrl.trim());
    await prefs.setString(_endpointPathKey, _normalizeEndpointPath(endpointPath));
  }

  Future<Map<String, String>> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'baseUrl': prefs.getString(_baseUrlKey) ?? '',
      'endpointPath': prefs.getString(_endpointPathKey) ?? _defaultEndpointPath,
    };
  }

  Future<bool> hasConfig() async {
    final config = await loadConfig();
    return config['baseUrl']!.isNotEmpty;
  }

  Future<bool> sendTransaction(Transaction t) async {
    final config = await loadConfig();
    final baseUrl = _normalizeBaseUrl(config['baseUrl']!);
    final endpointPath = _normalizeEndpointPath(config['endpointPath']!);

    if (baseUrl.isEmpty) {
      return false;
    }

    final uri = Uri.parse('$baseUrl$endpointPath');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(_toApiPayload(t)),
    );

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _normalizeEndpointPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return _defaultEndpointPath;
    if (trimmed.startsWith('/')) return trimmed;
    return '/$trimmed';
  }

  Map<String, dynamic> _toApiPayload(Transaction t) {
    return {
      'id': t.id,
      'amount': t.amount,
      'merchant': t.merchant,
      'card_last_four': t.cardLastFour,
      'date': t.date.toIso8601String(),
      'bank': t.bank.name,
      'type': t.type.name,
      'category': t.category.name,
      'raw_sms': t.rawSms,
      'notes': t.notes,
      'source': 'sms',
    };
  }
}
