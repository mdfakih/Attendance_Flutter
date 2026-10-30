import 'package:attendance_app/app/router.dart';
import 'package:attendance_app/app/theme/app_palette.dart';
import 'package:attendance_app/app/theme/app_theme.dart';
import 'package:attendance_app/app/theme/branding.dart';
import 'package:attendance_app/app/theme/theme_providers.dart';
import 'package:attendance_app/core/config/env.dart';
import 'package:attendance_app/features/home/presentation/widgets/today_view.dart';
import 'package:attendance_app/features/punch/data/punch_service.dart';
import 'package:attendance_app/shared/widgets/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PunchContext _ctx({String regState = 'AVAILABLE', int outside = 45, bool allowed = true}) => PunchContext({
      'punchAllowed': allowed,
      'blockedReason': allowed ? null : 'NON_WORKING_DAY',
      'dayType': 'WEEKLY_OFF',
      'date': '2026-10-29',
      'nextDirection': 'IN',
      'punches': const <Map<String, dynamic>>[],
      'sites': const [
        {'id': 's1', 'name': 'Head office'},
      ],
      'today': {'status': 'NOT_STARTED', 'workedMinutes': 0, 'outsideMinutes': outside, 'regState': regState},
    });

void main() {
  group('Branding', () {
    test('reads server colours and an https logo', () {
      final b = Branding.fromJson({'primaryColor': '#0f766e', 'accentColor': '#8B5CF6', 'logoUrl': 'https://cdn.example.com/logo.png'});
      expect(b.primary, const Color(0xFF0F766E));
      expect(b.accent, const Color(0xFF8B5CF6));
      expect(b.logoUrl, 'https://cdn.example.com/logo.png');
    });

    test('falls back to defaults for anything invalid', () {
      expect(Branding.fromJson(null), Branding.defaults);
      expect(Branding.fromJson('nope'), Branding.defaults);
      final b = Branding.fromJson({'primaryColor': 'red', 'accentColor': '#12345', 'logoUrl': 'http://insecure.example.com/x.png'});
      expect(b, Branding.defaults);
    });

    test('survives a round trip through storage, and garbage decodes to defaults', () {
      const b = Branding(primary: Color(0xFFBE123C), accent: Color(0xFFF97316), logoUrl: 'https://x.example.com/l.svg');
      expect(Branding.decode(b.encode()), b);
      expect(Branding.decode('{not json'), Branding.defaults);
      expect(Branding.decode(null), Branding.defaults);
      expect(Branding.hex(b.primary), '#BE123C');
    });
  });

  group('AppTheme', () {
    test('keeps the brand primary in light mode with readable text on it', () {
      final light = AppTheme.light(Branding.defaults);
      expect(light.colorScheme.primary, Branding.defaults.primary);
      expect(light.colorScheme.onPrimary, Colors.white);
      expect(light.extension<AppPalette>(), isNotNull);
    });

    test('lightens dark brand colours for dark mode and picks contrasting text', () {
      const yellow = Branding(primary: Color(0xFFEAB308), accent: Color(0xFF0EA5E9));
      expect(AppTheme.light(yellow).colorScheme.onPrimary, isNot(Colors.white));
      final dark = AppTheme.dark(Branding.defaults);
      expect(dark.brightness, Brightness.dark);
      expect(HSLColor.fromColor(dark.colorScheme.primary).lightness, greaterThanOrEqualTo(0.64));
    });

    test('theme mode names round-trip with a safe default', () {
      expect(themeModeFromName('dark'), ThemeMode.dark);
      expect(themeModeFromName('light'), ThemeMode.light);
      expect(themeModeFromName(null), ThemeMode.system);
      expect(themeModeFromName('purple'), ThemeMode.system);
    });
  });

  group('Product identity', () {
    testWidgets('wordmark reads KamaiGo with "Go" in the brand colour', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(Branding.defaults),
        home: const Scaffold(body: Column(children: [AppMark(size: 48), BrandWordmark()])),
      ));
      expect(Env.appName, 'KamaiGo');
      expect(find.text('KamaiGo', findRichText: true), findsOneWidget);
      final rich = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
      expect((rich.children!.single as TextSpan).style?.color, Branding.defaults.primary);
      expect(tester.takeException(), isNull);
    });
  });

  test('extra time notifications open home when the feature is off', () {
    expect(notificationRoute({'type': 'OUTSIDE_HOURS', 'date': '2026-10-29'}, extraTime: false), Routes.home);
    expect(notificationRoute({'type': 'REGULARIZATION_DECISION'}, extraTime: false), Routes.home);
  });

  group('TodayView', () {
    Future<void> pump(WidgetTester tester, PunchContext ctx, {required bool extraTime}) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(Branding.defaults),
        home: Scaffold(body: SingleChildScrollView(child: TodayView(ctx: ctx, extraTime: extraTime, onChanged: () {}))),
      ));
    }

    testWidgets('shows the punch button and the outside-hours card when extra time is on', (tester) async {
      await pump(tester, _ctx(), extraTime: true);
      expect(find.text('Punch in'), findsOneWidget);
      expect(find.text('45m outside working hours today'), findsOneWidget);
      expect(find.text('Head office'), findsOneWidget);
    });

    testWidgets('hides the outside-hours card when extra time is off', (tester) async {
      await pump(tester, _ctx(), extraTime: false);
      expect(find.text('45m outside working hours today'), findsNothing);
    });

    testWidgets('explains why punching is closed', (tester) async {
      await pump(tester, _ctx(allowed: false, outside: 0, regState: 'NOT_APPLICABLE'), extraTime: true);
      expect(find.text('Punch in'), findsNothing);
      expect(find.text('Today is your weekly off. Punching is closed.'), findsOneWidget);
    });
  });
}
