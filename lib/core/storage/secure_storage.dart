import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys for everything kept in encrypted storage. Tokens never touch SharedPreferences.
abstract final class SecureKeys {
  static const refreshToken = 'refresh_token';
  static const installId = 'install_id';
  static const bindingId = 'binding_id';
  static const pinHash = 'pin_hash';
  static const pinSalt = 'pin_salt';
  static const biometricEnabled = 'biometric_enabled';
  static const phone = 'phone';
  static const pendingBindingId = 'pending_binding_id';
}

class SecureStore {
  SecureStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  Future<void> delete(String key) => _storage.delete(key: key);
  Future<void> clearSession() async {
    for (final key in [SecureKeys.refreshToken, SecureKeys.bindingId, SecureKeys.pinHash, SecureKeys.pinSalt, SecureKeys.biometricEnabled, SecureKeys.pendingBindingId]) {
      await _storage.delete(key: key);
    }
  }
}
