import 'package:attendance_app/app/router.dart';
import 'package:attendance_app/core/network/dio_client.dart';
import 'package:attendance_app/core/notifications/punch_reminder.dart';
import 'package:attendance_app/core/providers.dart';
import 'package:attendance_app/features/regularization/presentation/regularization_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements ApiClient {}

Map<String, dynamic> _day(String date, String regState, {Map<String, dynamic>? request, int approved = 0}) => {
      'date': date,
      'status': 'PRESENT',
      'dayType': 'WORKING',
      'expectedStartAt': '${date}T03:30:00.000Z',
      'expectedEndAt': '${date}T12:30:00.000Z',
      'firstPunchAt': '${date}T02:40:00.000Z',
      'lastPunchAt': '${date}T13:00:00.000Z',
      'workedMinutes': 540,
      'outsideEarlyMinutes': 50,
      'outsideLateMinutes': 30,
      'outsideMinutes': 80,
      'regState': regState,
      'regApprovedMinutes': approved,
      'request': request,
    };

Map<String, dynamic> _request(String id, String status, {String? note, int? approved}) => {
      'id': id,
      'status': status,
      'reason': 'Stock audit',
      'outsideMinutesAtRequest': 80,
      'approvedMinutes': approved,
      'decisionNote': note,
      'createdAt': '2026-10-02T10:00:00.000Z',
      'decidedAt': null,
    };

void main() {
  group('helpers', () {
    test('fmtDuration matches the server wording', () {
      expect(fmtDuration(0), '0m');
      expect(fmtDuration(45), '45m');
      expect(fmtDuration(60), '1h');
      expect(fmtDuration(80), '1h 20m');
    });

    test('reason must be 5–500 characters after trimming', () {
      expect(regularizationReasonError('  abc  '), isNotNull);
      expect(regularizationReasonError('Stock audit'), isNull);
      expect(regularizationReasonError('x' * 501), isNotNull);
    });

    test('notification taps route to the right screen', () {
      expect(notificationRoute({'type': 'OUTSIDE_HOURS', 'date': '2026-10-29'}), '/attendance/regularization?date=2026-10-29');
      expect(notificationRoute({'type': 'REGULARIZATION_DECISION', 'requestId': 'r1', 'date': '2026-10-29'}), '/attendance/regularization?date=2026-10-29');
      expect(notificationRoute({'type': 'REGULARIZATION_DECISION'}), Routes.regularization);
      expect(notificationRoute({'type': PunchReminder.type}), Routes.home);
      expect(notificationRoute({'type': 'GENERAL'}), isNull);
    });
  });

  group('RegularizationScreen', () {
    late _MockApi api;
    late int fetches;

    final rows = [
      _day('2026-10-04', 'AVAILABLE'),
      _day('2026-10-03', 'REQUESTED', request: _request('r3', 'PENDING')),
      _day('2026-10-02', 'APPROVED', request: _request('r2', 'APPROVED', note: 'Pre-approved', approved: 60), approved: 60),
      _day('2026-10-01', 'REJECTED', request: _request('r1', 'REJECTED', note: 'Not needed')),
    ];

    Future<void> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          regularizationMonthProvider.overrideWith((ref, month) async {
            fetches++;
            return rows;
          }),
        ],
        child: const MaterialApp(home: RegularizationScreen()),
      ));
      await tester.pumpAndSettle();
    }

    setUp(() {
      api = _MockApi();
      fetches = 0;
    });

    testWidgets('shows outside time and each state', (tester) async {
      await pump(tester);
      expect(find.text('1h 20m outside working hours'), findsNWidgets(4));
      expect(find.text('50m before start · 30m after end'), findsNWidgets(4));
      expect(find.text('Ask to count this time'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
      expect(find.text('1h of 1h 20m now counts as working time.'), findsOneWidget);
      expect(find.text('Note from your employer: Pre-approved'), findsOneWidget);
      expect(find.text('Your employer did not count this time.'), findsOneWidget);
      expect(find.text('Note from your employer: Not needed'), findsOneWidget);
    });

    testWidgets('asks with a reason and refreshes the list', (tester) async {
      when(() => api.post<Map<String, dynamic>>(any(), body: any(named: 'body'))).thenAnswer((_) async => _request('r4', 'PENDING'));
      await pump(tester);

      await tester.tap(find.text('Ask to count this time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send request'));
      await tester.pump();
      expect(find.text('Give a reason of at least 5 characters.'), findsOneWidget);
      verifyNever(() => api.post<Map<String, dynamic>>(any(), body: any(named: 'body')));

      await tester.enterText(find.byType(TextField), '  Stock audit  ');
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      verify(() => api.post<Map<String, dynamic>>('/v1/mobile/regularizations', body: {'date': '2026-10-04', 'reason': 'Stock audit'})).called(1);
      expect(find.text('Send request'), findsNothing);
      expect(fetches, 2);
    });

    testWidgets('withdraws a pending request', (tester) async {
      when(() => api.post<Map<String, dynamic>>(any())).thenAnswer((_) async => {'id': 'r3', 'status': 'CANCELLED'});
      await pump(tester);

      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();
      verify(() => api.post<Map<String, dynamic>>('/v1/mobile/regularizations/r3/cancel')).called(1);
      expect(fetches, 2);
    });
  });
}
