import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../config/env.dart';
import '../storage/secure_storage.dart';

/// Outcome of [AppLockService.authenticateBiometric]. [error] is a user-facing reason; it is null on
/// success and on a plain cancel (the user backed out, nothing to tell them).
class BiometricResult {
  const BiometricResult._(this.ok, this.error);
  const BiometricResult.failed(String message) : this._(false, message);

  static const success = BiometricResult._(true, null);
  static const cancelled = BiometricResult._(false, null);

  final bool ok;
  final String? error;
}

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

  /// Never throws. A cancel comes back silent; any other failure carries a message to show,
  /// since swallowing those made the fingerprint button look dead.
  Future<BiometricResult> authenticateBiometric() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock ${Env.appName}',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricResult.success : BiometricResult.cancelled;
    } on LocalAuthException catch (e) {
      debugPrint('AppLockService.authenticateBiometric: ${e.code} ${e.description}');
      final message = _biometricMessage(e.code);
      return message == null ? BiometricResult.cancelled : BiometricResult.failed(message);
    } catch (e) {
      debugPrint('AppLockService.authenticateBiometric failed: $e');
      return const BiometricResult.failed(_biometricUnavailable);
    }
  }

  static const _biometricUnavailable = 'Fingerprint / face unlock is unavailable right now. Use your PIN.';

  /// Null for the cancel family. Not exhaustive on purpose: the plugin may add codes in a minor release.
  static String? _biometricMessage(LocalAuthExceptionCode code) => switch (code) {
        LocalAuthExceptionCode.userCanceled || LocalAuthExceptionCode.systemCanceled || LocalAuthExceptionCode.timeout || LocalAuthExceptionCode.authInProgress => null,
        LocalAuthExceptionCode.temporaryLockout => 'Too many attempts. Wait a moment, or use your PIN.',
        LocalAuthExceptionCode.biometricLockout => 'Fingerprint is locked after too many attempts. Unlock your phone with its screen lock once, or use your PIN.',
        LocalAuthExceptionCode.noBiometricsEnrolled || LocalAuthExceptionCode.noBiometricHardware || LocalAuthExceptionCode.noCredentialsSet => 'No fingerprint or face is set up on this phone. Use your PIN.',
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable => 'The fingerprint sensor is busy. Try again, or use your PIN.',
        _ => _biometricUnavailable,
      };

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
