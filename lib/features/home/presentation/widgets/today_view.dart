import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../punch/data/punch_service.dart';
import '../../../regularization/presentation/regularization_screen.dart';

/// Today at a glance: the punch card, time outside working hours and where punching works.
class TodayView extends StatelessWidget {
  const TodayView({super.key, required this.ctx, required this.extraTime, required this.onChanged});

  final PunchContext ctx;
  final bool extraTime;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroCard(ctx: ctx, onChanged: onChanged),
        if (extraTime && ctx.outsideMinutes > 0 && ctx.regState != 'NOT_APPLICABLE') ...[
          const SizedBox(height: 16),
          _OutsideCard(ctx: ctx, onChanged: onChanged),
        ],
        const SectionHeader('Where you can punch'),
        _SitesCard(sites: ctx.sites),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Punching needs your location and a quick selfie.', style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.ctx, required this.onChanged});

  final PunchContext ctx;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final text = Theme.of(context).textTheme;
    final onHero = palette.onHero;
    final today = ctx.today;
    final worked = today['workedMinutes'] as int? ?? 0;
    final status = today['status'] as String? ?? 'NOT_STARTED';
    final late = today['isLate'] == true;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: palette.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: palette.heroStart.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            StatusPill(label: _label(status), color: onHero, onDark: true),
            const Spacer(),
            if (ctx.shift != null) ...[
              Icon(Icons.schedule_rounded, size: 16, color: onHero.withValues(alpha: 0.85)),
              const SizedBox(width: 6),
              Text('${ctx.shift!['startTime']}–${ctx.shift!['endTime']}', style: text.labelLarge?.copyWith(color: onHero.withValues(alpha: 0.9))),
            ],
          ]),
          const SizedBox(height: 22),
          Text('${worked ~/ 60}h ${worked % 60}m', style: text.displaySmall?.copyWith(color: onHero)),
          const SizedBox(height: 2),
          Text('worked today${late ? ' · late' : ''}', style: text.bodyMedium?.copyWith(color: onHero.withValues(alpha: 0.85))),
          const SizedBox(height: 18),
          _Timeline(punches: ctx.punches, color: onHero),
          const SizedBox(height: 20),
          if (!ctx.punchAllowed || ctx.limitReached) _Blocked(message: _blocked(ctx), color: onHero) else _PunchButton(ctx: ctx, onChanged: onChanged),
        ],
      ),
    );
  }

  static String _label(String status) => switch (status) {
        'NOT_STARTED' => 'Not punched yet',
        'IN_PROGRESS' => 'Working',
        'PRESENT' => 'Present',
        'HALF_DAY' => 'Half day',
        'ABSENT' => 'Absent',
        'LEAVE' => 'On leave',
        'HOLIDAY' => 'Holiday',
        'WEEKLY_OFF' => 'Weekly off',
        _ => status,
      };

  static String _blocked(PunchContext ctx) => switch (ctx.blockedReason ?? (ctx.limitReached ? 'PUNCH_LIMIT' : null)) {
        'NON_WORKING_DAY' => ctx.dayType == 'HOLIDAY' ? 'Today is a holiday${ctx.holidayName != null ? ' (${ctx.holidayName})' : ''}. Punching is closed.' : 'Today is your weekly off. Punching is closed.',
        'ON_LEAVE' => 'You are on approved leave today.',
        'PUNCH_LIMIT' => 'You have reached today’s punch limit. Contact your employer.',
        _ => 'Punching is not available today.',
      };
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.punches, required this.color});

  final List<Map<String, dynamic>> punches;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(color: color);
    if (punches.isEmpty) return Text('No punches yet today', style: style?.copyWith(color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w500));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: punches.map((p) {
        final isIn = p['direction'] == 'IN';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isIn ? Icons.login_rounded : Icons.logout_rounded, size: 15, color: color),
            const SizedBox(width: 6),
            Text(DateFormat('HH:mm').format(DateTime.parse(p['at'] as String).toLocal()), style: style),
          ]),
        );
      }).toList(),
    );
  }
}

class _PunchButton extends StatelessWidget {
  const _PunchButton({required this.ctx, required this.onChanged});

  final PunchContext ctx;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isIn = ctx.nextDirection == 'IN';
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: isIn ? palette.heroStart : const Color(0xFF0F172A),
          minimumSize: const Size.fromHeight(58),
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () async {
          final replaced = ctx.replacedPunchOut;
          if (replaced != null && !await _confirmReplace(context, replaced)) return;
          if (!context.mounted) return;
          final ok = await context.push<bool>(Routes.punch);
          if (ok == true) onChanged();
        },
        icon: Icon(isIn ? Icons.fingerprint_rounded : Icons.logout_rounded, size: 26),
        label: Text(isIn ? 'Punch in' : 'Punch out'),
      ),
    );
  }

  /// FIRST_IN_LAST_OUT keeps only the last punch-out, so say so before punching out again.
  static Future<bool> _confirmReplace(BuildContext context, DateTime earlier) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.swap_horiz_rounded),
          title: const Text('Punch out again?'),
          content: Text('Punching out again replaces your earlier punch-out time (${DateFormat('HH:mm').format(earlier)}).'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Punch out'))],
        ),
      ) ==
      true;
}

class _Blocked extends StatelessWidget {
  const _Blocked({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600))),
        ]),
      );
}

class _OutsideCard extends StatelessWidget {
  const _OutsideCard({required this.ctx, required this.onChanged});

  final PunchContext ctx;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final color = regStateColor(ctx.regState, Theme.of(context).colorScheme);
    return Card(
      child: InkWell(
        onTap: () async {
          await context.push<void>(Routes.regularizationOn(ctx.date));
          if (context.mounted) onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.more_time_rounded, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${fmtDuration(ctx.outsideMinutes)} outside working hours today', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(ctx.regState == 'AVAILABLE' ? 'Not counted. Tap to ask your employer to count it.' : regStateLabel(ctx.regState), style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      ),
    );
  }
}

class _SitesCard extends StatelessWidget {
  const _SitesCard({required this.sites});

  final List<Map<String, dynamic>> sites;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (sites.isEmpty) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.wrong_location_outlined, color: scheme.error),
          title: const Text('No work site assigned'),
          subtitle: const Text('Contact your employer to be added to a site.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < sites.length; i++) ...[
            if (i > 0) const Divider(indent: 64),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.place_rounded, color: scheme.primary, size: 20),
              ),
              title: Text(sites[i]['name'] as String? ?? 'Work site'),
            ),
          ],
        ],
      ),
    );
  }
}
