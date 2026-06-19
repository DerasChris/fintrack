import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';
import 'auth_repository.dart';

class ApiSyncRepository {
  static const _baseUrlKey = 'api_base_url';
  static const _endpointPathKey = 'api_endpoint_path';
  static const _userIdKey = 'api_user_id';
  static const _defaultBaseUrl = 'https://daniel.shuttermultimediasv.com';
  static const _defaultEndpointPath = '/api/finanzas-personales/movimiento/flutter/crear';

  ApiSyncRepository() {
    _auth = AuthRepository(baseUrl: _defaultBaseUrl);
  }

  late final AuthRepository _auth;

  AuthRepository get auth => _auth;

  Future<void> saveConfig({
    required String baseUrl,
    required String endpointPath,
    required int userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, baseUrl.trim());
    await prefs.setString(_endpointPathKey, _normalizeEndpointPath(endpointPath));
    await prefs.setInt(_userIdKey, userId);
  }

  Future<Map<String, String>> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'baseUrl': prefs.getString(_baseUrlKey) ?? _defaultBaseUrl,
      'endpointPath': prefs.getString(_endpointPathKey) ?? _defaultEndpointPath,
      'userId': (prefs.getInt(_userIdKey) ?? 0).toString(),
    };
  }

  Future<int> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey) ?? 0;
  }

  Future<bool> hasConfig() async {
    final userId = await getUserId();
    return userId > 0;
  }

  Future<bool> sendTransaction(Transaction t) async {
    final config = await loadConfig();
    final baseUrl = _normalizeBaseUrl(config['baseUrl']!);
    final endpointPath = _normalizeEndpointPath(config['endpointPath']!);

    if (baseUrl.isEmpty) return false;

    final uri = Uri.parse('$baseUrl$endpointPath');
    final payload = await _toApiPayload(t);
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...await _auth.authHeaders(),
    };
    // ignore: avoid_print
    print('[API] POST $uri payload=$payload');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );
    // ignore: avoid_print
    print('[API] status=${response.statusCode} body=${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<bool> deleteTransaction(String id) async {
    final config = await loadConfig();
    final baseUrl = _normalizeBaseUrl(config['baseUrl']!);
    if (baseUrl.isEmpty) return false;

    // Deriva la ruta de eliminación reemplazando /crear → /eliminar/{id}
    final endpointPath = _normalizeEndpointPath(config['endpointPath']!);
    final deletePath = endpointPath.endsWith('/crear')
        ? '${endpointPath.substring(0, endpointPath.length - 6)}/$id'
        : '$endpointPath/$id';

    try {
      final uri = Uri.parse('$baseUrl$deletePath');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...await _auth.authHeaders(),
      };
      final response = await http.delete(uri, headers: headers);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<int> revertTransactions(List<String> ids) async {
    var count = 0;
    for (final id in ids) {
      if (await deleteTransaction(id)) count++;
    }
    return count;
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

  Future<Map<String, dynamic>> _toApiPayload(Transaction t) async {
    // Laravel solo acepta 'debit'/'credit' — 'transfer' lo rechaza con 422
    final typeStr = t.type == TransactionType.transfer ? 'debit' : t.type.name;

    return {
      'user_id': await getUserId(),
      'id': t.id,
      'amount': t.amount,
      'merchant': t.merchant,
      'card_last_four': t.cardLastFour,
      'date': t.date.toIso8601String(),
      'bank': t.bank.name,
      'type': typeStr,
      'category': t.category.name,
      'raw_sms': t.rawSms,
      'notes': t.notes,
      'source': 'sms',
    };
  }
}
