import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';

import '../storage/secure_storage.dart';

/// Local PIN (PBKDF2-HMAC-SHA256, 100k rounds) and biometric unlock. The server is never involved.
class AppLockService {
  AppLockService(this._store, [LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final SecureStore _store;
  final LocalAuthentication _auth;

  static const _iterations = 100000;
  static const maxAttempts = 5;

  Future<bool> hasPin() async => (await _store.read(SecureKeys.pinHash)) != null;
  Future<bool> biometricEnabled() async => (await _store.read(SecureKeys.biometricEnabled)) == 'true';

  Future<void> setPin(String pin) async {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    await _store.write(SecureKeys.pinSalt, base64Encode(salt));
    await _store.write(SecureKeys.pinHash, base64Encode(_derive(pin, salt)));
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _store.read(SecureKeys.pinSalt);
    final hash = await _store.read(SecureKeys.pinHash);
    if (salt == null || hash == null) return false;
    final candidate = base64Encode(_derive(pin, base64Decode(salt)));
    return _constantTimeEquals(candidate, hash);
  }

  Future<void> clearPin() async {
    await _store.delete(SecureKeys.pinHash);
    await _store.delete(SecureKeys.pinSalt);
  }

  Future<bool> canUseBiometrics() async {
    try {
      return await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) => _store.write(SecureKeys.biometricEnabled, enabled.toString());

  Future<bool> authenticateBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock the attendance app',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  static List<int> _derive(String pin, List<int> salt) {
    // PBKDF2 with a single block (32-byte output) is enough for a PIN gate.
    final hmac = Hmac(sha256, utf8.encode(pin));
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = List<int>.from(u);
    for (var i = 1; i < _iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
