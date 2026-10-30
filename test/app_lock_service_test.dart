import 'dart:io';

import 'package:attendance_app/core/auth/app_lock_service.dart';
import 'package:attendance_app/core/storage/secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

/// Plugin stand-in: `authenticate` returns [returns] unless [throws] is set.
class _FakeLocalAuth extends LocalAuthentication {
  _FakeLocalAuth({this.returns = true, this.throws});

  final bool returns;
  final Object? throws;

  @override
  Future<bool> authenticate({required localizedReason, authMessages = const [], biometricOnly = false, sensitiveTransaction = true, persistAcrossBackgrounding = false}) async {
    final error = throws;
    if (error != null) throw error;
    return returns;
  }
}

Future<BiometricResult> _run({bool returns = true, Object? throws}) => AppLockService(SecureStore(), _FakeLocalAuth(returns: returns, throws: throws)).authenticateBiometric();

void main() {
  test('success → ok, no message', () async {
    final r = await _run();
    expect(r.ok, isTrue);
    expect(r.error, isNull);
  });

  test('prompt resolving false → not ok, silent', () async {
    final r = await _run(returns: false);
    expect(r.ok, isFalse);
    expect(r.error, isNull);
  });

  // The user backed out, or a second tap raced the auto-prompt: nothing to say.
  for (final code in const [LocalAuthExceptionCode.userCanceled, LocalAuthExceptionCode.systemCanceled, LocalAuthExceptionCode.timeout, LocalAuthExceptionCode.authInProgress]) {
    test('$code is a silent cancel', () async {
      final r = await _run(throws: LocalAuthException(code: code));
      expect(r.ok, isFalse);
      expect(r.error, isNull);
    });
  }

  // Real failures must say why; they used to be swallowed, so the fingerprint button looked dead.
  for (final code in const [
    LocalAuthExceptionCode.uiUnavailable,
    LocalAuthExceptionCode.temporaryLockout,
    LocalAuthExceptionCode.biometricLockout,
    LocalAuthExceptionCode.noBiometricsEnrolled,
    LocalAuthExceptionCode.noBiometricHardware,
    LocalAuthExceptionCode.noCredentialsSet,
    LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable,
    LocalAuthExceptionCode.deviceError,
    LocalAuthExceptionCode.unknownError,
  ]) {
    test('$code surfaces a user-facing reason', () async {
      final r = await _run(throws: LocalAuthException(code: code));
      expect(r.ok, isFalse);
      expect(r.error, isNotEmpty);
    });
  }

  test('unexpected platform error surfaces a reason, never throws', () async {
    final r = await _run(throws: PlatformException(code: 'boom'));
    expect(r.ok, isFalse);
    expect(r.error, isNotEmpty);
  });

  // local_auth_android refuses to prompt unless the host is a FragmentActivity (it answers
  // uiUnavailable instead). A plain FlutterActivity is why fingerprint unlock never showed.
  test('MainActivity hosts local_auth on a FlutterFragmentActivity', () {
    final source = File('android/app/src/main/kotlin/in/attendance/attendance_app/MainActivity.kt').readAsStringSync();
    expect(source, contains(': FlutterFragmentActivity()'));
  });
}
