import 'package:dio/dio.dart';

/// Error surfaced to the UI. `code` mirrors the backend's stable error codes.
class ApiFailure implements Exception {
  const ApiFailure(this.code, this.message, {this.status = 0, this.details});

  final String code;
  final String message;
  final int status;
  final Object? details;

  bool get isAuth => status == 401 || code == 'BINDING_INACTIVE' || code == 'UNAUTHENTICATED';
  bool get isNetwork => code == 'NETWORK';

  static ApiFailure from(Object error) {
    if (error is ApiFailure) return error;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is Map) {
        final err = data['error'] as Map;
        return ApiFailure(
          err['code']?.toString() ?? 'UNKNOWN',
          err['message']?.toString() ?? 'Something went wrong.',
          status: error.response?.statusCode ?? 0,
          details: err['details'],
        );
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return const ApiFailure('NETWORK', 'No internet connection. Punching needs internet.');
      }
      return ApiFailure('HTTP_${error.response?.statusCode ?? 0}', 'Server error. Please try again.',
          status: error.response?.statusCode ?? 0);
    }
    return ApiFailure('UNKNOWN', error.toString());
  }

  @override
  String toString() => 'ApiFailure($code: $message)';
}
