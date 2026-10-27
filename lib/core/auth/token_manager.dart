import 'dart:async';

import 'package:dio/dio.dart';

import '../network/api_failure.dart';
import '../security/device_key_service.dart';
import '../storage/secure_storage.dart';

/// Holds the short-lived access token in memory and refreshes it with a device-signed request.
/// Refresh is single-flight so parallel 401s trigger one rotation.
class TokenManager {
  TokenManager({required this.store, required this.deviceKey, required Dio bareDio}) : _dio = bareDio;

  final SecureStore store;
  final DeviceKeyService deviceKey;
  final Dio _dio;

  String? _accessToken;
  DateTime? _expiresAt;
  Future<String?>? _inflight;

  String? get accessToken => _accessToken;
  bool get hasAccess => _accessToken != null && (_expiresAt?.isAfter(DateTime.now().add(const Duration(seconds: 20))) ?? false);

  Future<bool> hasSession() async => (await store.read(SecureKeys.refreshToken)) != null;

  Future<void> setTokens({required String accessToken, required String refreshToken, required String accessExpiresAt}) async {
    _accessToken = accessToken;
    _expiresAt = DateTime.tryParse(accessExpiresAt);
    await store.write(SecureKeys.refreshToken, refreshToken);
  }

  /// Returns a valid access token, refreshing when needed. Null means the session is gone.
  Future<String?> validAccessToken() async {
    if (hasAccess) return _accessToken;
    return refresh();
  }

  Future<String?> refresh() {
    return _inflight ??= _doRefresh().whenComplete(() => _inflight = null);
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await store.read(SecureKeys.refreshToken);
    if (refreshToken == null) return null;
    try {
      final nonceRes = await _dio.post<Map<String, dynamic>>('/v1/mobile/auth/nonce');
      final nonce = (nonceRes.data?['data'] as Map)['nonce'] as String;
      final signature = await deviceKey.sign(DeviceKeyService.refreshMessage(nonce));
      final res = await _dio.post<Map<String, dynamic>>('/v1/mobile/auth/refresh',
          data: {'refreshToken': refreshToken, 'nonce': nonce, 'signature': signature});
      final data = res.data?['data'] as Map<String, dynamic>;
      await setTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        accessExpiresAt: data['accessExpiresAt'] as String,
      );
      return _accessToken;
    } catch (error) {
      final failure = ApiFailure.from(error);
      if (failure.isNetwork) rethrow;
      // Any auth failure means the device is no longer registered: drop the session.
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _expiresAt = null;
    await store.delete(SecureKeys.refreshToken);
  }
}
