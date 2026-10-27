import 'package:dio/dio.dart';

import '../auth/token_manager.dart';

/// Attaches the bearer token and retries once after a refresh on 401.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(this._tokens, this._retryDio, {required this.onSessionLost});

  final TokenManager _tokens;
  final Dio _retryDio;
  final void Function() onSessionLost;

  static const _retried = 'auth_retried';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.path.startsWith('/v1/mobile/auth/')) return handler.next(options);
    final token = await _tokens.validAccessToken();
    if (token == null) {
      onSessionLost();
      return handler.reject(DioException(requestOptions: options, type: DioExceptionType.cancel, message: 'No session'));
    }
    options.headers['authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final code = _errorCode(err.response?.data);
    final isAuthPath = err.requestOptions.path.startsWith('/v1/mobile/auth/');
    if (status == 401 && !isAuthPath && err.requestOptions.extra[_retried] != true && code != 'BINDING_INACTIVE') {
      final token = await _tokens.refresh();
      if (token != null) {
        final options = err.requestOptions..extra[_retried] = true;
        options.headers['authorization'] = 'Bearer $token';
        try {
          return handler.resolve(await _retryDio.fetch(options));
        } catch (e) {
          return handler.next(e is DioException ? e : err);
        }
      }
    }
    if (status == 401 || code == 'BINDING_INACTIVE') onSessionLost();
    handler.next(err);
  }

  static String? _errorCode(Object? data) {
    if (data is! Map) return null;
    final error = data['error'];
    return error is Map ? error['code']?.toString() : null;
  }
}
