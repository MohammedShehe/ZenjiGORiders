import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'ZENJIGO_API_URL',
    defaultValue: 'https://zenjigo-backend.onrender.com/api/v1',
  );

  static Future<String?> _access() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('accessToken');
  }

  static Future<String?> _refresh() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('refreshToken');
  }

  static Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await _access();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    Future<http.Response> send() async {
      final uri = Uri.parse('$baseUrl$path');
      switch (method.toUpperCase()) {
        case 'GET':
          return http.get(uri, headers: headers);
        case 'PATCH':
          return http.patch(uri, headers: headers, body: jsonEncode(body ?? {}));
        case 'PUT':
          return http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
        case 'DELETE':
          return http.delete(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        default:
          return http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      }
    }

    var response = await send();
    if (response.statusCode == 401 && auth) {
      if (await _tryRefresh()) {
        final token = await _access();
        if (token != null) headers['Authorization'] = 'Bearer $token';
        response = await send();
      }
    }

    Map<String, dynamic> decoded;
    try {
      final parsed = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      decoded = parsed is Map<String, dynamic> ? parsed : <String, dynamic>{'data': parsed};
    } catch (_) {
      decoded = <String, dynamic>{'message': response.body};
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] == false) {
      final message = decoded['message'];
      throw Exception(message == null
          ? 'Request failed (${response.statusCode})'
          : message.toString());
    }
    return decoded;
  }

  static Future<bool> _tryRefresh() async {
    try {
      final rt = await _refresh();
      if (rt == null || rt.isEmpty) return false;
      final res = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': rt}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['success'] == false) return false;
      final payload = decoded['data'] ?? decoded;
      if (payload is! Map) return false;
      final data = Map<String, dynamic>.from(payload);
      await saveTokens(data);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveTokens(Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    final nested = data['tokens'] is Map
        ? Map<String, dynamic>.from(data['tokens'] as Map)
        : <String, dynamic>{};
    final access = data['accessToken'] ?? data['access'] ?? data['access_token'] ??
        nested['accessToken'] ?? nested['access'] ?? nested['access_token'];
    final refresh = data['refreshToken'] ?? data['refresh'] ?? data['refresh_token'] ??
        nested['refreshToken'] ?? nested['refresh'] ?? nested['refresh_token'];
    if (access != null) await p.setString('accessToken', access.toString());
    if (refresh != null) await p.setString('refreshToken', refresh.toString());
  }

  static Future<void> clearTokens() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('accessToken');
    await p.remove('refreshToken');
  }

  static Future<dynamic> data(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final res = await request(method, path, body: body, auth: auth);
    // API responses may wrap payloads inconsistently. Keep dynamic values
    // dynamic rather than forcing response fields into String types.
    return res.containsKey('data') ? res['data'] : res;
  }
}
