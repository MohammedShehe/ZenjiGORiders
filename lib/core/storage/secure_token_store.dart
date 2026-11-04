import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform-backed (Android Keystore / iOS Keychain) storage for auth tokens.
/// Tokens are never written to SharedPreferences or logs. Installs that still hold
/// tokens in SharedPreferences are migrated once, then the legacy copy is deleted.
class SecureTokenStore {
  SecureTokenStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kAccess = 'accessToken';
  static const _kRefresh = 'refreshToken';
  static bool _migrated = false;

  static Future<void> _migrateLegacy() async {
    if (_migrated) return;
    _migrated = true;
    try {
      final p = await SharedPreferences.getInstance();
      final a = p.getString(_kAccess);
      final r = p.getString(_kRefresh);
      if (a != null && await _storage.read(key: _kAccess) == null) {
        await _storage.write(key: _kAccess, value: a);
      }
      if (r != null && await _storage.read(key: _kRefresh) == null) {
        await _storage.write(key: _kRefresh, value: r);
      }
      await p.remove(_kAccess);
      await p.remove(_kRefresh);
    } catch (_) {/* migration is best-effort; secure store stays authoritative */}
  }

  static Future<String?> get accessToken async {
    await _migrateLegacy();
    return _storage.read(key: _kAccess);
  }

  static Future<String?> get refreshToken async {
    await _migrateLegacy();
    return _storage.read(key: _kRefresh);
  }

  static Future<void> save({String? access, String? refresh}) async {
    await _migrateLegacy();
    if (access != null) await _storage.write(key: _kAccess, value: access);
    if (refresh != null) await _storage.write(key: _kRefresh, value: refresh);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kAccess);
      await p.remove(_kRefresh);
    } catch (_) {}
  }
}
