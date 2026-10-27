import 'package:flutter/services.dart';

/// Bridge to the Android Keystore key (see DeviceSecurityPlugin.kt).
/// All proof-of-possession messages must match `popMessages` in the shared contracts.
class DeviceKeyService {
  DeviceKeyService([MethodChannel? channel]) : _channel = channel ?? const MethodChannel('attendance/device_security');

  final MethodChannel _channel;

  Future<bool> hasKey() async => (await _channel.invokeMethod<bool>('hasKey')) ?? false;

  /// Generates a fresh P-256 key; returns the base64 SPKI public key.
  Future<String> generateKey() async {
    final key = await _channel.invokeMethod<String>('generateKey');
    if (key == null) throw StateError('Key generation failed');
    return key;
  }

  Future<String?> publicKey() => _channel.invokeMethod<String>('getPublicKey');

  /// Base64 DER ECDSA signature over the UTF-8 message.
  Future<String> sign(String message) async {
    final sig = await _channel.invokeMethod<String>('sign', {'message': message});
    if (sig == null) throw StateError('Signing failed');
    return sig;
  }

  Future<void> deleteKey() => _channel.invokeMethod<void>('deleteKey');
  Future<String?> androidId() => _channel.invokeMethod<String>('androidId');
  Future<String> securityLevel() async => (await _channel.invokeMethod<String>('securityLevel')) ?? 'UNKNOWN';

  // ---- Proof-of-possession messages (byte-identical to packages/contracts/src/pop.ts) ----
  static String activateMessage(String nonce, String phone) => 'v1|ACTIVATE|$nonce|$phone';
  static String refreshMessage(String nonce) => 'v1|REFRESH|$nonce';
  static String pinResetMessage(String nonce, String phone) => 'v1|PIN_RESET|$nonce|$phone';
  static String bindingStatusMessage(String nonce, String bindingId) => 'v1|STATUS|$nonce|$bindingId';
  static String punchMessage(String nonce, String intentId, String selfieSha256, double lat, double lng) =>
      'v1|PUNCH|$nonce|$intentId|$selfieSha256|${lat.toStringAsFixed(6)}|${lng.toStringAsFixed(6)}';
}
