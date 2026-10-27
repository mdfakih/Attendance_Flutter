import 'package:attendance_app/core/security/device_key_service.dart';
import 'package:attendance_app/features/activation/presentation/activation_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhone', () {
    test('accepts Indian mobiles in common formats', () {
      expect(normalizePhone('9876543210'), '+919876543210');
      expect(normalizePhone('+91 98765 43210'), '+919876543210');
      expect(normalizePhone('09876543210'), '+919876543210');
    });

    test('rejects non-mobile numbers', () {
      expect(normalizePhone('12345'), isNull);
      expect(normalizePhone('5876543210'), isNull);
    });
  });

  group('proof-of-possession messages', () {
    test('match the backend contracts byte for byte', () {
      expect(DeviceKeyService.activateMessage('n1', '+919876543210'), 'v1|ACTIVATE|n1|+919876543210');
      expect(DeviceKeyService.refreshMessage('n2'), 'v1|REFRESH|n2');
      expect(DeviceKeyService.punchMessage('n3', 'intent', 'abc', 19.0761, 72.8778), 'v1|PUNCH|n3|intent|abc|19.076100|72.877800');
    });
  });
}
