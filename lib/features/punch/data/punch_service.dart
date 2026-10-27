import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/security/device_key_service.dart';

class PunchContext {
  PunchContext(this.json);
  final Map<String, dynamic> json;

  bool get punchAllowed => json['punchAllowed'] == true;
  String? get blockedReason => json['blockedReason'] as String?;
  String get date => json['date'] as String;
  String get dayType => json['dayType'] as String;
  String? get holidayName => json['holidayName'] as String?;
  String get nextDirection => json['nextDirection'] as String? ?? 'IN';
  Map<String, dynamic> get today => json['today'] as Map<String, dynamic>;
  List<Map<String, dynamic>> get sites => (json['sites'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get punches => (json['punches'] as List).cast<Map<String, dynamic>>();
  Map<String, dynamic>? get shift => json['shift'] as Map<String, dynamic>?;
}

class PunchIntent {
  PunchIntent(this.json);
  final Map<String, dynamic> json;
  String get id => json['intentId'] as String;
  List<String> get challenge => (json['livenessChallenge'] as List).cast<String>();
  String get siteName => (json['site'] as Map)['name'] as String;
}

/// Server-driven punch: context → intent (geofence pre-check) → selfie upload → signed commit.
class PunchService {
  PunchService({required this.api, required this.deviceKey});

  final ApiClient api;
  final DeviceKeyService deviceKey;

  Future<PunchContext> context() async => PunchContext(await api.get<Map<String, dynamic>>('/v1/mobile/punch/context'));

  Future<PunchIntent> intent({required double lat, required double lng, required double accuracyM, required bool isMock}) async =>
      PunchIntent(await api.post<Map<String, dynamic>>('/v1/mobile/punch/intents', body: {'lat': lat, 'lng': lng, 'accuracyM': accuracyM, 'isMock': isMock}));

  /// Uploads the JPEG straight to object storage via a presigned URL. Returns its sha256 hex.
  Future<String> uploadSelfie(String intentId, File jpeg) async {
    final bytes = await jpeg.readAsBytes();
    final sha = sha256.convert(bytes).toString();
    final upload = await api.post<Map<String, dynamic>>('/v1/mobile/punch/selfie-upload', body: {'intentId': intentId, 'sizeBytes': bytes.length, 'sha256': sha});
    final headers = (upload['headers'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
    await Dio().put<void>(upload['url'] as String, data: Stream.fromIterable([bytes]), options: Options(headers: headers, contentType: 'image/jpeg'));
    return sha;
  }

  Future<Map<String, dynamic>> commit({
    required PunchIntent intent,
    required double lat,
    required double lng,
    required double accuracyM,
    required bool isMock,
    required String selfieSha256,
    required List<String> livenessSteps,
    required int durationMs,
  }) async {
    final nonce = (await api.post<Map<String, dynamic>>('/v1/mobile/auth/nonce'))['nonce'] as String;
    final signature = await deviceKey.sign(DeviceKeyService.punchMessage(nonce, intent.id, selfieSha256, lat, lng));
    return api.post<Map<String, dynamic>>('/v1/mobile/punches', body: {
      'intentId': intent.id,
      'lat': lat,
      'lng': lng,
      'accuracyM': accuracyM,
      'isMock': isMock,
      'deviceTime': DateTime.now().toUtc().toIso8601String(),
      'liveness': {'passed': true, 'steps': livenessSteps, 'durationMs': durationMs, 'faceCount': 1},
      'selfieSha256': selfieSha256,
      'nonce': nonce,
      'signature': signature,
    });
  }

  static String encodeJson(Object value) => jsonEncode(value);
}
