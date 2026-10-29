import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/notifications/punch_reminder.dart';
import '../../../core/providers.dart';
import '../../regularization/presentation/regularization_screen.dart';
import '../data/punch_service.dart';
import 'liveness_controller.dart';

final punchServiceProvider = Provider<PunchService>((ref) => PunchService(api: ref.watch(apiProvider), deviceKey: ref.watch(deviceKeyProvider)));

enum _Stage { permissions, locating, intent, liveness, uploading, done, failed }

/// Punch in/out: permissions → GPS fix → server intent (geofence) → liveness selfie → upload → signed commit.
class PunchFlowScreen extends ConsumerStatefulWidget {
  const PunchFlowScreen({super.key});

  @override
  ConsumerState<PunchFlowScreen> createState() => _PunchFlowScreenState();
}

class _PunchFlowScreenState extends ConsumerState<PunchFlowScreen> {
  _Stage _stage = _Stage.permissions;
  String _status = 'Checking permissions…';
  String? _error;
  String? _errorCode;
  Map<String, dynamic>? _errorDetails;
  Position? _fix;
  PunchIntent? _intent;
  CameraController? _camera;
  LivenessController? _liveness;
  Map<String, dynamic>? _result;
  bool _regRequested = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _camera?.dispose();
    _liveness?.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final granted = await [Permission.camera, Permission.locationWhenInUse].request();
      if (granted.values.any((s) => !s.isGranted)) {
        return _fail('Camera and location permissions are needed to punch. Enable them in Settings.', openSettings: true);
      }
      setState(() {
        _stage = _Stage.locating;
        _status = 'Getting your location…';
      });
      final fix = await _bestFix();
      _fix = fix;
      setState(() {
        _stage = _Stage.intent;
        _status = 'Checking your work site…';
      });
      final intent = await ref.read(punchServiceProvider).intent(lat: fix.latitude, lng: fix.longitude, accuracyM: fix.accuracy, isMock: fix.isMocked);
      _intent = intent;
      await _startCamera(intent.challenge);
    } catch (e) {
      final failure = ApiFailure.from(e);
      _fail(failure.message, code: failure.code, details: failure.details is Map ? (failure.details as Map).cast<String, dynamic>() : null);
    }
  }

  /// Waits up to ~12 s for a fix better than 30 m, otherwise uses the best seen.
  Future<Position> _bestFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw const ApiFailure('LOCATION_OFF', 'Turn on location (GPS) to punch.');
    Position? best;
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    await for (final p in Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0))) {
      if (best == null || p.accuracy < best.accuracy) best = p;
      setState(() => _status = 'Getting your location… ±${p.accuracy.round()} m');
      if (p.accuracy <= 30 || DateTime.now().isAfter(deadline)) break;
    }
    return best ?? await Geolocator.getCurrentPosition();
  }

  Future<void> _startCamera(List<String> challenge) async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
    final controller = CameraController(front, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);
    await controller.initialize();
    final liveness = LivenessController(challenge);
    liveness.addListener(_onLiveness);
    await controller.startImageStream((image) => liveness.process(image, front));
    setState(() {
      _camera = controller;
      _liveness = liveness;
      _stage = _Stage.liveness;
    });
  }

  Future<void> _onLiveness() async {
    final liveness = _liveness;
    final camera = _camera;
    if (liveness == null || camera == null) return;
    if (!liveness.completed) return setState(() {});
    liveness.removeListener(_onLiveness);
    await Future<void>.delayed(const Duration(milliseconds: 600)); // let the user face forward
    await camera.stopImageStream();
    setState(() {
      _stage = _Stage.uploading;
      _status = 'Taking your selfie…';
    });
    try {
      final shot = await camera.takePicture();
      final compressed = await FlutterImageCompress.compressAndGetFile(shot.path, '${shot.path}.c.jpg', quality: 80, minWidth: 720, minHeight: 720, keepExif: false);
      final file = File(compressed?.path ?? shot.path);
      setState(() => _status = 'Uploading…');
      final sha = await ref.read(punchServiceProvider).uploadSelfie(_intent!.id, file);
      final fix = _fix!;
      final result = await ref.read(punchServiceProvider).commit(
            intent: _intent!,
            lat: fix.latitude,
            lng: fix.longitude,
            accuracyM: fix.accuracy,
            isMock: fix.isMocked,
            selfieSha256: sha,
            livenessSteps: liveness.challenge,
            durationMs: liveness.durationMs.clamp(500, 60000),
          );
      setState(() {
        _result = result;
        _stage = _Stage.done;
      });
      // Punch-in schedules "forgot to punch out?"; punch-out (reminderAt null) cancels it.
      unawaited(PunchReminder.sync(result['reminderAt'] as String?));
    } catch (e) {
      final failure = ApiFailure.from(e);
      _fail(failure.message, code: failure.code, details: failure.details is Map ? (failure.details as Map).cast<String, dynamic>() : null);
    }
  }

  void _fail(String message, {String? code, Map<String, dynamic>? details, bool openSettings = false}) {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.failed;
      _error = message;
      _errorCode = code;
      _errorDetails = {...?details, if (openSettings) 'openSettings': true};
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Punch'), leading: CloseButton(onPressed: () => context.pop())),
      body: switch (_stage) {
        _Stage.liveness => _livenessView(),
        _Stage.done => _doneView(scheme),
        _Stage.failed => _failedView(scheme),
        _ => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(_status)])),
      },
    );
  }

  Widget _livenessView() {
    final camera = _camera!;
    final liveness = _liveness!;
    final step = liveness.currentStep;
    return Column(
      children: [
        Expanded(child: ClipRRect(child: AspectRatio(aspectRatio: 1 / camera.value.aspectRatio, child: CameraPreview(camera)))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(liveness.hint, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(liveness.challenge.length, (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Chip(label: Text(LivenessController.label(liveness.challenge[i])), avatar: Icon(i < liveness.stepIndex ? Icons.check_circle : Icons.radio_button_unchecked, size: 18)),
                    )),
              ),
              if (step != null && _intent != null) Text('Site: ${_intent!.siteName}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _doneView(ColorScheme scheme) {
    final punch = _result?['punch'] as Map<String, dynamic>?;
    final day = _result?['day'] as Map<String, dynamic>?;
    final direction = punch?['direction'] == 'IN' ? 'Punched in' : 'Punched out';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 80, color: scheme.primary),
            const SizedBox(height: 16),
            Text(direction, style: Theme.of(context).textTheme.headlineSmall),
            if (punch != null) Text(TimeOfDay.fromDateTime(DateTime.parse(punch['at'] as String).toLocal()).format(context), style: Theme.of(context).textTheme.headlineMedium),
            if (day != null) Text('Today: ${(day['workedMinutes'] as int) ~/ 60}h ${(day['workedMinutes'] as int) % 60}m worked'),
            if (day != null && day['regState'] == 'AVAILABLE') _outsideNotice(day),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => context.pop(true), child: const Text('Done')),
          ],
        ),
      ),
    );
  }

  /// Time outside working hours is recorded but not counted unless the employee asks and the employer approves.
  Widget _outsideNotice(Map<String, dynamic> day) {
    final outside = day['outsideMinutes'] as int? ?? 0;
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('${fmtDuration(outside)} of today is outside your working hours and is not counted.', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            if (_regRequested)
              const Text('Request sent to your employer.')
            else
              TextButton.icon(
                onPressed: () async {
                  final sent = await showRegularizationRequestSheet(context, date: day['date'] as String, outsideMinutes: outside);
                  if (sent && mounted) setState(() => _regRequested = true);
                },
                icon: const Icon(Icons.more_time),
                label: const Text('Ask to count this time'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _failedView(ColorScheme scheme) {
    final d = _errorDetails ?? const {};
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 72, color: scheme.error),
            const SizedBox(height: 16),
            Text(_error ?? 'Could not punch', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            if (d['nearestSite'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('You are ${d['distanceM']} m from ${d['nearestSite']} (allowed ${d['radiusM']} m).', textAlign: TextAlign.center)),
            const SizedBox(height: 24),
            if (d['openSettings'] == true) OutlinedButton(onPressed: openAppSettings, child: const Text('Open settings')),
            // Retrying cannot lift the daily punch limit; only the employer can.
            if (_errorCode != 'PUNCH_LIMIT')
              FilledButton(onPressed: () => setState(() {
                    _stage = _Stage.permissions;
                    _error = null;
                    _errorCode = null;
                    _run();
                  }), child: const Text('Try again')),
            TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}
