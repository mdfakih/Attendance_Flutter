import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/security/device_key_service.dart';
import '../../../core/storage/secure_storage.dart';

class ActivationOutcome {
  const ActivationOutcome.active(this.tokens, this.bindingId) : pendingUploadUrl = null, pendingUploadHeaders = null;
  const ActivationOutcome.pending(this.bindingId, {this.pendingUploadUrl, this.pendingUploadHeaders}) : tokens = null;

  final Map<String, dynamic>? tokens;
  final String bindingId;
  final String? pendingUploadUrl;
  final Map<String, dynamic>? pendingUploadHeaders;

  bool get isPending => tokens == null;
}

/// First-login flow: phone + employer code, bound to a fresh Keystore key.
class ActivationService {
  ActivationService({required this.authApi, required this.deviceKey, required this.store});

  final ApiClient authApi;
  final DeviceKeyService deviceKey;
  final SecureStore store;

  Future<String> nonce() async => (await authApi.post<Map<String, dynamic>>('/v1/mobile/auth/nonce'))['nonce'] as String;

  Future<String> installId() async {
    final existing = await store.read(SecureKeys.installId);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await store.write(SecureKeys.installId, id);
    return id;
  }

  Future<Map<String, dynamic>> deviceInfo() async {
    final pkg = await PackageInfo.fromPlatform();
    final info = <String, dynamic>{'installId': await installId(), 'platform': Platform.isIOS ? 'IOS' : 'ANDROID', 'appVersion': pkg.version};
    if (Platform.isAndroid) {
      final android = await DeviceInfoPlugin().androidInfo;
      info.addAll({'manufacturer': android.manufacturer, 'model': android.model, 'osVersion': android.version.release, 'androidId': await deviceKey.androidId()});
    }
    return info;
  }

  Future<ActivationOutcome> activate({required String phone, required String code}) async {
    final n = await nonce();
    final publicKey = await deviceKey.generateKey();
    final signature = await deviceKey.sign(DeviceKeyService.activateMessage(n, phone));
    final data = await authApi.post<Map<String, dynamic>>('/v1/mobile/auth/activate', body: {
      'phone': phone,
      'code': code,
      'nonce': n,
      'publicKey': publicKey,
      'signature': signature,
      'device': await deviceInfo(),
      'fcmToken': await PushService.token(),
    });
    await store.write(SecureKeys.phone, phone);
    if (data['status'] == 'PENDING') {
      final upload = data['selfieUpload'] as Map<String, dynamic>?;
      return ActivationOutcome.pending(data['bindingId'] as String, pendingUploadUrl: upload?['url'] as String?, pendingUploadHeaders: upload?['headers'] as Map<String, dynamic>?);
    }
    return ActivationOutcome.active(data, data['bindingId'] as String);
  }

  /// Polls while the employer approves the phone. Returns tokens once ACTIVE.
  Future<Map<String, dynamic>?> bindingStatus(String bindingId) async {
    final n = await nonce();
    final signature = await deviceKey.sign(DeviceKeyService.bindingStatusMessage(n, bindingId));
    final data = await authApi.post<Map<String, dynamic>>('/v1/mobile/auth/binding-status', body: {'bindingId': bindingId, 'nonce': n, 'signature': signature});
    return data['status'] == 'ACTIVE' ? data : null;
  }

  Future<Map<String, dynamic>> pinReset({required String phone, required String code}) async {
    final n = await nonce();
    final signature = await deviceKey.sign(DeviceKeyService.pinResetMessage(n, phone));
    return authApi.post<Map<String, dynamic>>('/v1/mobile/auth/pin-reset', body: {'phone': phone, 'code': code, 'nonce': n, 'signature': signature, 'installId': await installId()});
  }
}
