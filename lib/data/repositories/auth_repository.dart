import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  static const _xsrfKey    = 'auth_xsrf_token';
  static const _sessionKey = 'auth_session_cookie';
  static const _sessionNameKey = 'auth_session_name';

  final String baseUrl;
  AuthRepository({required this.baseUrl});

  Future<bool> login(String email, String password) async {
    final client = HttpClient();
    try {
      // 1. CSRF cookie
      final csrfReq = await client.getUrl(Uri.parse('$baseUrl/sanctum/csrf-cookie'));
      csrfReq.headers.set('Accept', 'application/json');
      final csrfRes = await csrfReq.close();
      await csrfRes.drain<void>();

      String? xsrf;
      String? sessionName;
      String? sessionVal;

      for (final c in csrfRes.cookies) {
        if (c.name == 'XSRF-TOKEN') xsrf = c.value;
        if (c.name.endsWith('_session') || c.name == 'laravel_session') {
          sessionName = c.name;
          sessionVal  = c.value;
        }
      }

      if (xsrf == null) return false;

      // 2. Login
      final loginReq = await client.postUrl(Uri.parse('$baseUrl/login'));
      loginReq.headers.set('Content-Type', 'application/json');
      loginReq.headers.set('Accept', 'application/json');
      loginReq.headers.set('X-XSRF-TOKEN', Uri.decodeComponent(xsrf));
      final cookieHeader = [
        'XSRF-TOKEN=$xsrf',
        if (sessionName != null) '$sessionName=$sessionVal',
      ].join('; ');
      loginReq.headers.set('Cookie', cookieHeader);
      loginReq.add(utf8.encode(jsonEncode({'email': email, 'password': password})));

      final loginRes = await loginReq.close();
      await loginRes.drain<void>();

      if (loginRes.statusCode == 422 || loginRes.statusCode == 401) {
        return false;
      }

      // Actualiza cookies de la respuesta de login
      for (final c in loginRes.cookies) {
        if (c.name == 'XSRF-TOKEN') xsrf = c.value;
        if (c.name.endsWith('_session') || c.name == 'laravel_session') {
          sessionName = c.name;
          sessionVal  = c.value;
        }
      }

      // 200, 204 o redirect = éxito
      if (loginRes.statusCode < 400) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_xsrfKey, xsrf!);
        if (sessionName != null) {
          await prefs.setString(_sessionKey, sessionVal!);
          await prefs.setString(_sessionNameKey, sessionName);
        }
        return true;
      }

      return false;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  Future<Map<String, String>> authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final xsrf        = prefs.getString(_xsrfKey);
    final sessionVal  = prefs.getString(_sessionKey);
    final sessionName = prefs.getString(_sessionNameKey);

    if (xsrf == null || sessionVal == null || sessionName == null) return {};

    return {
      'X-XSRF-TOKEN': Uri.decodeComponent(xsrf),
      'Cookie': 'XSRF-TOKEN=$xsrf; $sessionName=$sessionVal',
    };
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_sessionKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_xsrfKey);
    await prefs.remove(_sessionKey);
    await prefs.remove(_sessionNameKey);
  }
}
