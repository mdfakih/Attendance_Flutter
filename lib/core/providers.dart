import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/app_lock_service.dart';
import 'auth/session_controller.dart';
import 'auth/token_manager.dart';
import 'network/auth_interceptor.dart';
import 'network/dio_client.dart';
import 'security/device_key_service.dart';
import 'storage/secure_storage.dart';

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());
final deviceKeyProvider = Provider<DeviceKeyService>((ref) => DeviceKeyService());
final appLockProvider = Provider<AppLockService>((ref) => AppLockService(ref.watch(secureStoreProvider)));

/// Dio without auth, used for the public auth endpoints and token refresh.
final bareDioProvider = Provider<Dio>((ref) => ApiClient.buildDio());
final authApiProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(bareDioProvider)));

final tokenManagerProvider = Provider<TokenManager>((ref) => TokenManager(
      store: ref.watch(secureStoreProvider),
      deviceKey: ref.watch(deviceKeyProvider),
      bareDio: ref.watch(bareDioProvider),
    ));

/// Authenticated client for `/v1/mobile/*`.
final Provider<ApiClient> apiProvider = Provider<ApiClient>((ref) {
  final tokens = ref.watch(tokenManagerProvider);
  final retryDio = ApiClient.buildDio();
  final dio = ApiClient.buildDio(interceptors: [
    AuthInterceptor(tokens, retryDio, onSessionLost: () => ref.read(sessionControllerProvider.notifier).sessionLost()),
  ]);
  return ApiClient(dio);
});

final StateNotifierProvider<SessionController, SessionState> sessionControllerProvider = StateNotifierProvider<SessionController, SessionState>(
  (ref) => SessionController(
    store: ref.watch(secureStoreProvider),
    tokens: ref.watch(tokenManagerProvider),
    lock: ref.watch(appLockProvider),
    api: () => ref.read(apiProvider),
  ),
);
