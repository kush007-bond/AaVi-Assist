import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../models/analyse_response.dart';
import 'api_service.dart';
import 'radar_service.dart';
import 'depth_service.dart';
import 'tts_service.dart';

typedef OnResult = void Function(AnalyseResponse result);
typedef OnError = void Function(String error);

class CameraService {
  static CameraController? controller;
  static List<CameraDescription> cameras = [];
  static Timer? _timer;
  static String _mode = 'indoor';
  static bool _busy = false;

  // Track the previous scan's minimum sensor distance for approaching-object detection
  static double? _prevMinDistanceCm;

  static int get intervalMs => _mode == 'indoor' ? 3500 : 1500;

  /// Compute minimum distance across all radar + depth readings.
  static double? _minDistance(
    List<Map<String, dynamic>>? radar,
    List<Map<String, dynamic>>? depth,
  ) {
    final all = [
      ...(radar ?? []).map((r) => (r['distance_cm'] as num).toDouble()),
      ...(depth ?? []).map((d) => (d['distance_cm'] as num).toDouble()),
    ];
    if (all.isEmpty) return null;
    return all.reduce((a, b) => a < b ? a : b);
  }

  static Future<void> init() async {
    cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No cameras found on this device.');
    controller = CameraController(
      cameras.first,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller!.initialize();
  }

  static Future<void> start(
    String mode, {
    required OnResult onResult,
    required OnError onError,
  }) async {
    _mode = mode;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) async {
      if (_busy) return;
      _busy = true;
      try {
        // capture frame
        final file = await controller!.takePicture();
        final bytes = kIsWeb
            ? await file.readAsBytes()
            : await File(file.path).readAsBytes();
        final b64 = base64Encode(bytes);

        // sensor readings
        final radar = await RadarService.getReadings();
        final depth = await DepthService.getReadings();

        final currentMin = _minDistance(radar, depth);

        final result = await ApiService.analyse(
          b64,
          _mode,
          radar: radar,
          depth: depth,
          prevMinDistanceCm: _prevMinDistanceCm,
        );

        // Update previous min distance for next scan
        _prevMinDistanceCm = currentMin;

        if (result != null) {
          // Priority: depth > radar > approaching > description
          await TtsService.speak(result.spokenAlert);

          // Read detected text separately after the primary alert
          if (result.textDetected != null &&
              result.textDetected!.trim().isNotEmpty &&
              result.textDetected!.toLowerCase() != 'null') {
            await Future.delayed(const Duration(milliseconds: 800));
            await TtsService.speak('I can see text: ${result.textDetected}');
          }

          onResult(result);
        } else {
          onError('No response from server. Check backend URL in Settings.');
        }
      } catch (e) {
        onError(e.toString());
      } finally {
        _busy = false;
      }
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _prevMinDistanceCm = null;
  }

  static void dispose() {
    stop();
    controller?.dispose();
    controller = null;
  }
}
