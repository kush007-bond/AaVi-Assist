import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads depth/LiDAR data from the device sensor.
///
/// iOS:  ARKit LiDAR (iPhone 12 Pro+, iPad Pro 2020+)
/// Android: Camera2 ToF / depth stream (device-dependent)
///
/// Uses a MethodChannel to native code. Falls back gracefully on
/// devices without depth hardware.
class DepthService {
  static const _channel = MethodChannel('com.visionaid/depth');

  static bool _hasDepth = false;
  static bool get hasDepth => _hasDepth;

  /// Call once on splash to detect if device has LiDAR / ToF.
  static Future<bool> detectSensor() async {
    if (kIsWeb) {
      _hasDepth = false;
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('hasDepthSensor');
      _hasDepth = result ?? false;
    } on PlatformException {
      _hasDepth = false;
    } on MissingPluginException {
      // Native channel not implemented yet — treat as no sensor
      _hasDepth = false;
    }
    return _hasDepth;
  }

  /// Returns a list of depth readings or null if unavailable.
  /// Each entry: {distance_cm, angle_deg, source}
  static Future<List<Map<String, dynamic>>?> getReadings() async {
    if (!_hasDepth || kIsWeb) return null;
    try {
      final raw = await _channel.invokeMethod<List>('getDepthReadings');
      if (raw == null) return null;
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }
}
