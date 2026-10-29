import 'package:attendance_app/core/notifications/punch_reminder.dart';
import 'package:attendance_app/features/punch/data/punch_service.dart';
import 'package:flutter_test/flutter_test.dart';

PunchContext _ctx({
  String? hoursMode = 'FIRST_IN_LAST_OUT',
  String nextDirection = 'OUT',
  List<Map<String, dynamic>> punches = const [],
  int? punchesLeft = 3,
  String? blockedReason,
  Map<String, dynamic> today = const {},
}) =>
    PunchContext({
      'punchAllowed': blockedReason == null,
      'blockedReason': blockedReason,
      'hoursMode': hoursMode,
      'punchesLeft': punchesLeft,
      'nextDirection': nextDirection,
      'punches': punches,
      'today': today,
      'reminderAt': '2026-10-29T13:00:00.000Z',
    });

void main() {
  group('PunchContext.replacedPunchOut', () {
    final inOutIn = [
      {'at': '2026-10-29T03:30:00.000Z', 'direction': 'IN'},
      {'at': '2026-10-29T12:30:00.000Z', 'direction': 'OUT'},
      {'at': '2026-10-29T13:00:00.000Z', 'direction': 'IN'},
    ];

    test('is the latest punch-out when FIRST_IN_LAST_OUT would replace it', () {
      expect(_ctx(punches: inOutIn).replacedPunchOut, DateTime.utc(2026, 10, 29, 12, 30).toLocal());
    });

    test('is null in SUM_OF_PAIRS, before any punch-out, or when the next punch is IN', () {
      expect(_ctx(hoursMode: 'SUM_OF_PAIRS', punches: inOutIn).replacedPunchOut, isNull);
      expect(_ctx(punches: [inOutIn.first]).replacedPunchOut, isNull);
      expect(_ctx(nextDirection: 'IN', punches: inOutIn.take(2).toList()).replacedPunchOut, isNull);
    });
  });

  group('PunchContext limits and outside time', () {
    test('limit is reached by PUNCH_LIMIT or no punches left', () {
      expect(_ctx().limitReached, isFalse);
      expect(_ctx(blockedReason: 'PUNCH_LIMIT', punchesLeft: 0).limitReached, isTrue);
      expect(_ctx(punchesLeft: 0).limitReached, isTrue);
      expect(_ctx(punchesLeft: null).limitReached, isFalse);
    });

    test('reads outside time and reminder, with safe defaults for older servers', () {
      final c = _ctx(today: {'outsideMinutes': 80, 'regState': 'AVAILABLE'});
      expect(c.outsideMinutes, 80);
      expect(c.regState, 'AVAILABLE');
      expect(c.reminderAt, '2026-10-29T13:00:00.000Z');
      expect(_ctx().outsideMinutes, 0);
      expect(_ctx().regState, 'NOT_APPLICABLE');
    });
  });

  group('PunchReminder.scheduleTime', () {
    final now = DateTime.utc(2026, 10, 29, 12);

    test('schedules a future reminderAt at the same instant', () {
      final at = PunchReminder.scheduleTime('2026-10-29T13:00:00.000Z', now);
      expect(at, isNotNull);
      expect(at!.isAtSameMomentAs(DateTime.utc(2026, 10, 29, 13)), isTrue);
    });

    test('cancels when null, past or unreadable', () {
      expect(PunchReminder.scheduleTime(null, now), isNull);
      expect(PunchReminder.scheduleTime('2026-10-29T11:59:00.000Z', now), isNull);
      expect(PunchReminder.scheduleTime('2026-10-29T12:00:00.000Z', now), isNull);
      expect(PunchReminder.scheduleTime('not a time', now), isNull);
    });
  });
}
