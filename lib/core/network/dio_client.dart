import 'package:dio/dio.dart';

import '../config/env.dart';
import 'api_failure.dart';

/// Thin wrapper over Dio that unwraps the API envelope `{success, data, error}`.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  static Dio buildDio({List<Interceptor> interceptors = const []}) {
    final dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'content-type': 'application/json'},
    ));
    dio.interceptors.addAll(interceptors);
    return dio;
  }

  Dio get raw => _dio;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _call<T>(() => _dio.get<Map<String, dynamic>>(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? body}) =>
      _call<T>(() => _dio.post<Map<String, dynamic>>(path, data: body ?? const {}));

  Future<T> _call<T>(Future<Response<Map<String, dynamic>>> Function() request) async {
    try {
      final response = await request();
      final body = response.data;
      if (body == null || body['success'] != true) {
        final err = body?['error'] as Map?;
        throw ApiFailure(err?['code']?.toString() ?? 'UNKNOWN', err?['message']?.toString() ?? 'Unexpected response',
            status: response.statusCode ?? 0);
      }
      return body['data'] as T;
    } on ApiFailure {
      rethrow;
    } catch (error) {
      throw ApiFailure.from(error);
    }
  }
}
