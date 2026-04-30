// ignore_for_file: unused_import

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Global, singleton application state that survives navigation.
/// Keeps track of whether the AI pipeline is running, what mode is active, etc.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  // ── Running state ─────────────────────────────────────────────────────────
  bool _running = false;
  bool get running => _running;
  set running(bool v) {
    if (_running == v) return;
    _running = v;
    notifyListeners();
  }

  // ── Mode (indoor / outdoor) ───────────────────────────────────────────────
  String _mode = 'indoor';
  String get mode => _mode;
  set mode(String v) {
    if (_mode == v) return;
    _mode = v;
    notifyListeners();
  }

  void toggleMode() {
    mode = _mode == 'indoor' ? 'outdoor' : 'indoor';
  }

  // ── Real-time mode ────────────────────────────────────────────────────────
  bool _realtimeMode = false;
  bool get realtimeMode => _realtimeMode;
  set realtimeMode(bool v) {
    if (_realtimeMode == v) return;
    _realtimeMode = v;
    notifyListeners();
  }

  // ── Voice ─────────────────────────────────────────────────────────────────
  bool _voiceEnabled = false;
  bool get voiceEnabled => _voiceEnabled;
  set voiceEnabled(bool v) {
    if (_voiceEnabled == v) return;
    _voiceEnabled = v;
    notifyListeners();
  }

  bool _voiceListening = false;
  bool get voiceListening => _voiceListening;
  set voiceListening(bool v) {
    if (_voiceListening == v) return;
    _voiceListening = v;
    notifyListeners();
  }

  bool _voiceProcessing = false;
  bool get voiceProcessing => _voiceProcessing;
  set voiceProcessing(bool v) {
    if (_voiceProcessing == v) return;
    _voiceProcessing = v;
    notifyListeners();
  }

  String voiceStatus = '';
  String voicePartial = '';

  // ── Camera ready ──────────────────────────────────────────────────────────
  bool _cameraReady = false;
  bool get cameraReady => _cameraReady;
  set cameraReady(bool v) {
    if (_cameraReady == v) return;
    _cameraReady = v;
    notifyListeners();
  }

  // ── Loading ───────────────────────────────────────────────────────────────
  bool _loading = false;
  bool get loading => _loading;
  set loading(bool v) {
    if (_loading == v) return;
    _loading = v;
    notifyListeners();
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  String? errorMsg;

  // ── Sensor ────────────────────────────────────────────────────────────────
  bool sensorActive = false;
}
