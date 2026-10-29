import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'friendly_errors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'ZENJIGO_API_URL',
    defaultValue: 'https://zenjigo-backend.onrender.com/api/v1',
  );

  /// Hard cap so a bad network can never leave a screen spinning forever.
  static const Duration requestTimeout = Duration(seconds: 25);

  /// Optional hook: called once when the session can no longer be refreshed (e.g. to route to login).
  static void Function()? onSessionExpired;

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
      final Future<http.Response> future;
      switch (method.toUpperCase()) {
        case 'GET':
          future = http.get(uri, headers: headers);
          break;
        case 'PATCH':
          future = http.patch(uri, headers: headers, body: jsonEncode(body ?? {}));
          break;
        case 'PUT':
          future = http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
          break;
        case 'DELETE':
          future = http.delete(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
          break;
        default:
          future = http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      }
      return future.timeout(requestTimeout);
    }

    Future<http.Response> guardedSend() async {
      try {
        return await send();
      } catch (e) {
        throw Exception(FriendlyErrors.message(e));
      }
    }

    var response = await guardedSend();
    if (response.statusCode == 401 && auth) {
      if (await _tryRefresh()) {
        final token = await _access();
        if (token != null) headers['Authorization'] = 'Bearer $token';
        response = await guardedSend();
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
      throw Exception(FriendlyErrors.message(message == null
          ? 'HTTP ${response.statusCode}'
          : message.toString()));
    }
    return decoded;
  }

  static Future<bool>? _refreshInFlight;

  /// Many screens poll at once; when the access token expires they all get a 401 together.
  /// Refresh tokens rotate, so only ONE refresh may run — the rest wait for its result.
  static Future<bool> _tryRefresh() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  static Future<bool> _doRefresh() async {
    try {
      final rt = await _refresh();
      if (rt == null || rt.isEmpty) return false;
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': rt}),
          )
          .timeout(requestTimeout);
      if (res.statusCode == 401 || res.statusCode == 403) {
        // Definitive: the refresh token is no longer valid.
        await clearTokens();
        onSessionExpired?.call();
        return false;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['success'] == false) return false;
      final payload = decoded['data'] ?? decoded;
      if (payload is! Map) return false;
      await saveTokens(Map<String, dynamic>.from(payload));
      return true;
    } catch (_) {
      // Network blip: keep the tokens, the next request will try again.
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
