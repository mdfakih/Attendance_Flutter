import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Drives the on-device liveness challenge (blink / turn / smile) over the camera stream.
/// Pure state machine around ML Kit face results; the screen renders [state].
class LivenessController extends ChangeNotifier {
  LivenessController(this.challenge);

  final List<String> challenge;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true, enableTracking: true, performanceMode: FaceDetectorMode.fast, minFaceSize: 0.3),
  );

  int _step = 0;
  bool _busy = false;
  bool _eyesClosedSeen = false;
  bool _faceCentered = false;
  int _faceCount = 0;
  DateTime? _startedAt;
  bool completed = false;
  String hint = 'Hold the phone in front of your face';

  int get stepIndex => _step;
  String? get currentStep => _step < challenge.length ? challenge[_step] : null;
  int get durationMs => _startedAt == null ? 0 : DateTime.now().difference(_startedAt!).inMilliseconds;
  bool get faceReady => _faceCount == 1 && _faceCentered;

  static String label(String step) => switch (step) {
        'BLINK' => 'Blink your eyes',
        'TURN_LEFT' => 'Turn your head left',
        'TURN_RIGHT' => 'Turn your head right',
        'SMILE' => 'Smile',
        _ => step,
      };

  Future<void> process(CameraImage image, CameraDescription camera) async {
    if (_busy || completed) return;
    _busy = true;
    try {
      final input = _toInputImage(image, camera);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      _faceCount = faces.length;
      if (faces.length != 1) {
        _faceCentered = false;
        hint = faces.isEmpty ? 'No face detected' : 'Only one face, please';
        notifyListeners();
        return;
      }
      final face = faces.first;
      final big = face.boundingBox.width >= image.height * 0.3; // image is rotated; height ≈ frame width
      _faceCentered = big;
      if (!big) {
        hint = 'Move closer';
        notifyListeners();
        return;
      }
      _startedAt ??= DateTime.now();
      _evaluate(face);
    } catch (e) {
      debugPrint('liveness: $e');
    } finally {
      _busy = false;
    }
  }

  void _evaluate(Face face) {
    final step = currentStep;
    if (step == null) return;
    hint = label(step);
    var passed = false;
    switch (step) {
      case 'BLINK':
        final left = face.leftEyeOpenProbability ?? 1;
        final right = face.rightEyeOpenProbability ?? 1;
        if (left < 0.2 && right < 0.2) _eyesClosedSeen = true;
        passed = _eyesClosedSeen && left > 0.8 && right > 0.8;
      case 'TURN_LEFT':
        passed = (face.headEulerAngleY ?? 0) > 20; // front camera mirrors: user's left = +Y
      case 'TURN_RIGHT':
        passed = (face.headEulerAngleY ?? 0) < -20;
      case 'SMILE':
        passed = (face.smilingProbability ?? 0) > 0.7;
    }
    if (passed) {
      _step += 1;
      _eyesClosedSeen = false;
      if (_step >= challenge.length) {
        completed = true;
        hint = 'Great! Look straight at the camera';
      }
    }
    notifyListeners();
  }

  /// Converts a camera frame to an ML Kit input (Android NV21 / YUV420 single plane path).
  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) return null;
    final bytes = image.planes.length == 1 ? image.planes.first.bytes : _yuv420ToNv21(image);
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: image.planes.length == 1 ? format : InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  static Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final y = image.planes[0];
    final u = image.planes[1];
    final v = image.planes[2];
    final out = Uint8List(width * height + 2 * (width ~/ 2) * (height ~/ 2));
    var offset = 0;
    for (var row = 0; row < height; row++) {
      out.setRange(offset, offset + width, y.bytes, row * y.bytesPerRow);
      offset += width;
    }
    final uvRowStride = u.bytesPerRow;
    final uvPixelStride = u.bytesPerPixel ?? 1;
    for (var row = 0; row < height ~/ 2; row++) {
      for (var col = 0; col < width ~/ 2; col++) {
        final index = row * uvRowStride + col * uvPixelStride;
        out[offset++] = v.bytes[index];
        out[offset++] = u.bytes[index];
      }
    }
    return out;
  }

  @override
  void dispose() {
    _detector.close();
    super.dispose();
  }
}
