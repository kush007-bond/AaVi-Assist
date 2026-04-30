import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/analyse_response.dart';
import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../services/radar_service.dart';
import '../services/depth_service.dart';
import '../services/room_map_service.dart';
import '../services/tts_service.dart';
import '../services/voice_service.dart';
import '../services/realtime_service.dart';
import '../services/sensor_monitor.dart';
import '../widgets/status_bar.dart';
import '../widgets/description_banner.dart';
import '../widgets/chat_bar.dart';
import '../widgets/floor_plan_painter.dart';
import 'settings_screen.dart';
import 'navigation_map_screen.dart';
import 'room_map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ── Core state ────────────────────────────────────────────────────────────
  bool _running = false;
  bool _loading = false;
  bool _cameraReady = false;
  String _mode = 'indoor';
  AnalyseResponse? _lastResult;
  String? _errorMsg;
  String _cameraInitMsg = 'Initialising camera...';

  // Real-time AI mode (WebSocket frames instead of HTTP timer)
  bool _realtimeMode = false;
  Timer? _rtFrameTimer;
  bool _rtFrameBusy = false;
  StreamSubscription? _rtSub;

  // Sensor monitor (always local, no network) — toggled independently
  bool _sensorActive = false;
  SensorAlert? _currentSensorAlert;
  StreamSubscription? _sensorSub;

  // Voice
  bool _voiceEnabled = false;
  bool _voiceListening = false;
  bool _voiceProcessing = false;
  String _voiceStatus = '';
  String _voicePartial = '';

  // Mic pulse animation
  late AnimationController _micPulse;
  late Animation<double> _micScale;

  @override
  void initState() {
    super.initState();
    _micPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _micScale = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _micPulse, curve: Curves.easeInOut),
    );
    _micPulse.stop();

    _initCamera();
    VoiceService.init();
  }

  @override
  void dispose() {
    _stopAll();
    if (_sensorActive) {
      SensorMonitor.stop();
      _sensorSub?.cancel();
    }
    CameraService.dispose();
    VoiceService.cancel();
    _micPulse.dispose();
    super.dispose();
  }

  // ── Camera init ───────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      await CameraService.init();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraInitMsg =
              'Camera unavailable: $e\n\nYou can still use the chat bar.';
          _cameraReady = false;
        });
      }
    }
  }

  // ── Start / Stop ──────────────────────────────────────────────────────────

  void _toggleRunning() {
    if (_running) {
      _stopAll();
    } else {
      _startAll();
    }
  }

  void _startAll() {
    setState(() {
      _running = true;
      _loading = !_realtimeMode; // RT mode shows results as they arrive
      _errorMsg = null;
    });

    // ── AI analysis ──
    if (_realtimeMode) {
      _startRealtimeFrames();
    } else {
      CameraService.start(
        _mode,
        onResult: (result) {
          if (mounted) {
            setState(() {
              _lastResult = result;
              _loading = false;
              _errorMsg = null;
            });
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _loading = false;
              _errorMsg = err;
            });
          }
        },
      );
    }
  }

  void _toggleSensorMonitor() {
    if (_sensorActive) {
      SensorMonitor.stop();
      _sensorSub?.cancel();
      _sensorSub = null;
      setState(() {
        _sensorActive = false;
        _currentSensorAlert = null;
      });
    } else {
      SensorMonitor.start();
      _sensorSub = SensorMonitor.alerts.listen(_onSensorAlert);
      setState(() => _sensorActive = true);
    }
  }

  void _stopAll() {
    // Stop AI
    if (_realtimeMode) {
      _rtFrameTimer?.cancel();
      _rtFrameTimer = null;
      _rtSub?.cancel();
      _rtSub = null;
      _rtFrameBusy = false;
    } else {
      CameraService.stop();
    }

    if (mounted) {
      setState(() {
        _running = false;
        _loading = false;
      });
    }
  }

  // ── Mode toggle ───────────────────────────────────────────────────────────

  void _toggleMode() {
    if (_running) _stopAll();
    setState(() => _mode = _mode == 'indoor' ? 'outdoor' : 'indoor');
  }

  // ── Real-time AI mode ─────────────────────────────────────────────────────

  Future<void> _switchToRealtimeMode(bool on) async {
    if (on == _realtimeMode) return;
    if (_running) _stopAll();

    if (on) {
      await RealtimeService.connect(ApiService.baseUrl);
      if (!RealtimeService.isConnected) {
        setState(() => _errorMsg =
            'WebSocket failed. Check backend URL in Settings.');
        return;
      }
      await TtsService.speak('Real-time mode on.');
    } else {
      RealtimeService.disconnect();
      await TtsService.speak('Real-time mode off.');
    }
    setState(() => _realtimeMode = on);
  }

  /// Sends camera frames to the WebSocket for continuous AI analysis.
  /// Sensor warnings are handled independently by SensorMonitor.
  void _startRealtimeFrames() {
    _rtSub?.cancel();
    _rtSub = RealtimeService.results.listen(_onRealtimeMessage);

    // Frame every 1.5 s — skipped server-side if AI is still busy
    _rtFrameTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (!_running || _rtFrameBusy) return;
      if (CameraService.controller == null ||
          !CameraService.controller!.value.isInitialized) {
        return;
      }
      _rtFrameBusy = true;
      try {
        final file = await CameraService.controller!.takePicture();
        final bytes = kIsWeb
            ? await file.readAsBytes()
            : await File(file.path).readAsBytes();
        RealtimeService.sendFrame(
          imageBase64: base64Encode(bytes),
          mode: _mode,
        );
      } catch (_) {
        _rtFrameBusy = false;
      }
    });
  }

  void _onRealtimeMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    final type = msg['type'] as String?;

    switch (type) {
      case 'analyse_result':
        _rtFrameBusy = false;
        try {
          final result = AnalyseResponse.fromJson(msg);
          TtsService.speak(result.description); // sensor alerts already handle warnings
          if (result.textDetected != null &&
              result.textDetected!.trim().isNotEmpty &&
              result.textDetected!.toLowerCase() != 'null') {
            Future.delayed(const Duration(milliseconds: 800), () {
              TtsService.speak('I can see text: ${result.textDetected}');
            });
          }
          setState(() {
            _lastResult = result;
            _loading = false;
          });
        } catch (_) {
          _rtFrameBusy = false;
        }

      case 'snapshot_result':
        _voiceProcessing = false;
        final answer = msg['answer'] as String? ?? 'No answer available.';
        TtsService.speak(answer);
        setState(() {
          _voiceStatus =
              answer.length > 60 ? '${answer.substring(0, 57)}...' : answer;
        });
        if (_voiceEnabled) {
          Future.delayed(const Duration(milliseconds: 800), _startListening);
        }

      case 'skipped':
        _rtFrameBusy = false;

      case 'disconnected':
        setState(() {
          _realtimeMode = false;
          _running = false;
          _errorMsg = 'Real-time connection lost. Tap ⚡ to reconnect.';
        });

      case 'error':
        _rtFrameBusy = false;
        setState(() => _errorMsg = msg['message'] as String? ?? 'RT error');
    }
  }

  // ── Sensor monitor callback ───────────────────────────────────────────────

  void _onSensorAlert(SensorAlert? alert) {
    if (mounted) setState(() => _currentSensorAlert = alert);
  }

  // ── Voice control ─────────────────────────────────────────────────────────

  void _toggleVoice() async {
    if (_voiceListening || _voiceEnabled) {
      await VoiceService.stop();
      _micPulse.stop();
      setState(() {
        _voiceListening = false;
        _voiceEnabled = false;
        _voiceStatus = '';
        _voicePartial = '';
      });
      await TtsService.speak('Voice off.');
    } else {
      if (!VoiceService.isAvailable) {
        final ok = await VoiceService.init();
        if (!ok) {
          setState(
              () => _errorMsg = 'Speech recognition unavailable on this device.');
          return;
        }
      }
      setState(() => _voiceEnabled = true);
      await TtsService.speak('Voice on.');
      await Future.delayed(const Duration(milliseconds: 600));
      _startListening();
    }
  }

  void _startListening() {
    if (!_voiceEnabled || _voiceListening || _voiceProcessing) return;
    setState(() {
      _voiceListening = true;
      _voiceStatus = 'Listening...';
      _voicePartial = '';
    });
    _micPulse.repeat(reverse: true);

    VoiceService.startListening(
      onPartial: (w) {
        if (mounted) setState(() => _voicePartial = w);
      },
      onFinal: (w) {
        _micPulse.stop();
        if (mounted) setState(() => _voiceListening = false);
        _handleVoiceResult(w);
      },
      onDone: () {
        _micPulse.stop();
        if (mounted) {
          setState(() {
            _voiceListening = false;
            if (_voicePartial.isEmpty) _voiceStatus = 'Tap mic to speak';
          });
        }
        if (_voiceEnabled && !_voiceProcessing) {
          Future.delayed(const Duration(milliseconds: 300), _startListening);
        }
      },
    );
  }

  void _handleVoiceResult(String words) async {
    if (words.trim().isEmpty) return;
    final (cmd, question) = VoiceService.parseCommand(words);

    switch (cmd) {
      case VoiceCommand.start:
        setState(() => _voiceStatus = 'Starting...');
        await TtsService.speak('Starting.');
        if (!_running) _startAll();

      case VoiceCommand.stop:
        setState(() => _voiceStatus = 'Stopping...');
        await TtsService.speak('Stopping.');
        if (_running) _stopAll();

      case VoiceCommand.indoor:
        setState(() => _voiceStatus = 'Indoor mode.');
        await TtsService.speak('Indoor mode.');
        if (_mode != 'indoor') _toggleMode();

      case VoiceCommand.outdoor:
        setState(() => _voiceStatus = 'Outdoor mode.');
        await TtsService.speak('Outdoor mode.');
        if (_mode != 'outdoor') _toggleMode();

      case VoiceCommand.openMap:
        setState(() => _voiceStatus = 'Opening room map...');
        await TtsService.speak('Opening room map.');
        if (mounted) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => RoomMapScreen(mode: _mode)));
        }

      case VoiceCommand.question:
        setState(() {
          _voiceStatus = question ?? words;
          _voiceProcessing = true;
        });
        await TtsService.speak('Let me look...');
        await _takeSnapshot(question ?? words);

      case VoiceCommand.none:
        if (_voiceEnabled) {
          Future.delayed(const Duration(milliseconds: 300), _startListening);
        }
    }

    if (cmd != VoiceCommand.question &&
        cmd != VoiceCommand.none &&
        _voiceEnabled) {
      Future.delayed(const Duration(milliseconds: 800), _startListening);
    }
  }

  Future<void> _takeSnapshot(String question) async {
    if (!_cameraReady || CameraService.controller == null) {
      await TtsService.speak('Camera not ready.');
      setState(() => _voiceProcessing = false);
      if (_voiceEnabled) {
        Future.delayed(const Duration(milliseconds: 800), _startListening);
      }
      return;
    }
    try {
      final file = await CameraService.controller!.takePicture();
      final bytes = kIsWeb
          ? await file.readAsBytes()
          : await File(file.path).readAsBytes();
      final b64 = base64Encode(bytes);

      if (_realtimeMode && RealtimeService.isConnected) {
        RealtimeService.sendSnapshot(
            imageBase64: b64, mode: _mode, question: question);
        // Result handled in _onRealtimeMessage
      } else {
        // Run analyse + chat concurrently where possible:
        // analyse gives visual context; chat wraps it with the question.
        final analyse = await ApiService.analyse(b64, _mode);
        final ctx = analyse?.description ?? '';
        final answer = ctx.isNotEmpty
            ? (await ApiService.chat([], context: '$ctx\nUser asked: $question') ??
                ctx)
            : 'I could not see anything clearly.';
        await TtsService.speak(answer);
        if (mounted) {
          setState(() {
            _voiceStatus =
                answer.length > 60 ? '${answer.substring(0, 57)}...' : answer;
            _voiceProcessing = false;
          });
        }
        if (_voiceEnabled) {
          Future.delayed(const Duration(milliseconds: 600), _startListening);
        }
      }
    } catch (e) {
      await TtsService.speak('Could not capture image.');
      setState(() => _voiceProcessing = false);
      if (_voiceEnabled) {
        Future.delayed(const Duration(milliseconds: 800), _startListening);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Camera preview + overlays
          Expanded(flex: 55, child: _buildCameraPreview()),

          // Sensor bar — visible when sensor monitor is active
          if (_sensorActive) _buildSensorBar(),

          // Voice status strip
          if (_voiceEnabled) _buildVoiceStrip(),

          // Status bar
          StatusBarWidget(
            mode: _mode,
            running: _running,
            onToggle: _cameraReady ? _toggleRunning : () {},
            onModeToggle: _toggleMode,
            realtimeMode: _realtimeMode,
            sensorActive: _sensorActive,
            onSensorToggle: _toggleSensorMonitor,
          ),

          // Description banner (AI scene output)
          DescriptionBanner(result: _lastResult, loading: _loading),

          // Error banner
          if (_errorMsg != null)
            Container(
              color: Colors.red[900],
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              width: double.infinity,
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_errorMsg!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                        maxLines: 3),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _errorMsg = null),
                    child: const Icon(Icons.close,
                        color: Colors.white54, size: 16),
                  ),
                ],
              ),
            ),

          // Chat bar
          ChatBar(lastDescription: _lastResult?.description),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('VisionAid',
              style:
                  TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          if (_realtimeMode) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
              ),
              child: const Text('LIVE',
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          tooltip: _realtimeMode ? 'Disable real-time AI' : 'Enable real-time AI',
          icon: Icon(Icons.bolt,
              color: _realtimeMode ? Colors.green : Colors.white38),
          onPressed: () => _switchToRealtimeMode(!_realtimeMode),
        ),
        IconButton(
          tooltip: 'Room Map',
          icon: const Icon(Icons.grid_view_outlined, color: Colors.green),
          onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => RoomMapScreen(mode: _mode)))
              .then((_) => setState(() {})),
        ),
        if (RadarService.hasRadar || DepthService.hasDepth)
          IconButton(
            tooltip: 'Navigation Map',
            icon: const Icon(Icons.map_outlined, color: Colors.green),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => NavigationMapScreen(mode: _mode))),
          ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ],
    );
  }

  // ── Camera preview ────────────────────────────────────────────────────────

  Widget _buildCameraPreview() {
    if (!_cameraReady || CameraService.controller == null) {
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(_cameraInitMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(CameraService.controller!),

        // Mini floor-plan — bottom-left
        Positioned(
          bottom: 10,
          left: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MiniMapWidget(
                points: RoomMapService.allPoints,
                size: 100,
                onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => RoomMapScreen(mode: _mode)))
                    .then((_) => setState(() {})),
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(
                  RoomMapService.completedScans == 0
                      ? 'Map room'
                      : MiniMapWidget.coverageLabel(
                          RoomMapService.completedScans,
                          RoomMapService.requiredScans),
                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                ),
              ),
            ],
          ),
        ),

        // Mic button — bottom-right
        Positioned(bottom: 10, right: 10, child: _buildMicButton()),

        // LIVE badge — top-right when streaming
        if (_realtimeMode && _running)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record,
                      color: Colors.white, size: 8),
                  SizedBox(width: 4),
                  Text('LIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

        // AI loading overlay (timer mode only)
        if (_loading && !_realtimeMode)
          Container(
            color: Colors.black38,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 10),
                  Text('Analysing scene...',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Sensor bar ────────────────────────────────────────────────────────────

  Widget _buildSensorBar() {
    final alert = _currentSensorAlert;
    final isSim = SensorMonitor.simulationActive;
    final hasHardware = RadarService.hasRadar || DepthService.hasDepth;

    // Colours based on alert level
    final Color bg;
    final Color fg;
    final IconData icon;
    final String mainText;

    if (alert == null) {
      bg = const Color(0xFF0A2A0A);
      fg = Colors.green;
      icon = Icons.sensors;
      mainText = 'Clear';
    } else {
      switch (alert.level) {
        case AlertLevel.danger:
          bg = Colors.red[900]!;
          fg = Colors.white;
          icon = Icons.warning_amber_rounded;
        case AlertLevel.caution:
          bg = Colors.orange[900]!;
          fg = Colors.white;
          icon = Icons.sensors;
        case AlertLevel.info:
          bg = const Color(0xFF1A1400);
          fg = Colors.yellow;
          icon = Icons.sensors;
        default:
          bg = Colors.grey[900]!;
          fg = Colors.white54;
          icon = Icons.sensors;
      }
      mainText = alert.message;
    }

    // Distance fill bar (0–300 cm → 0–1, inverted so closer = more filled)
    final distCm = alert?.distanceCm ?? 300.0;
    final fillFraction = ((300.0 - distCm.clamp(0.0, 300.0)) / 300.0);

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Sensor icon
              Icon(icon, color: fg, size: 16),
              const SizedBox(width: 8),

              // Main message
              Expanded(
                child: Text(
                  mainText,
                  style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Source / distance badge
              if (alert != null)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${distCm.toInt()} cm',
                    style: TextStyle(
                        color: fg, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),

              // SIM / HW badge + toggle
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  SensorMonitor.toggleSimulation();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSim
                        ? Colors.amber.withValues(alpha: 0.25)
                        : Colors.green.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSim
                          ? Colors.amber.withValues(alpha: 0.7)
                          : Colors.green.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Text(
                    isSim
                        ? (hasHardware ? 'SIM' : 'SIM ⚙')
                        : 'HW',
                    style: TextStyle(
                      color: isSim ? Colors.amber : Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Distance fill bar
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fillFraction,
              minHeight: 3,
              backgroundColor: fg.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                alert?.level == AlertLevel.danger
                    ? Colors.red
                    : alert?.level == AlertLevel.caution
                        ? Colors.orange
                        : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mic button ────────────────────────────────────────────────────────────

  Widget _buildMicButton() {
    final (bg, fg, icon) = switch ((_voiceProcessing, _voiceListening,
        _voiceEnabled)) {
      (true, _, _) => (
          Colors.amber.withValues(alpha: 0.85),
          Colors.black,
          Icons.hourglass_empty
        ),
      (_, true, _) => (
          Colors.red.withValues(alpha: 0.9),
          Colors.white,
          Icons.mic
        ),
      (_, _, true) => (
          Colors.green.withValues(alpha: 0.85),
          Colors.white,
          Icons.mic
        ),
      _ => (Colors.black54, Colors.white38, Icons.mic_off),
    };

    final btn = GestureDetector(
      onTap: _toggleVoice,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(
              color: _voiceListening ? Colors.red : Colors.white24,
              width: 2),
        ),
        child: Icon(icon, color: fg, size: 26),
      ),
    );

    if (_voiceListening) {
      return AnimatedBuilder(
        animation: _micScale,
        builder: (_, child) =>
            Transform.scale(scale: _micScale.value, child: child),
        child: btn,
      );
    }
    return btn;
  }

  // ── Voice strip ───────────────────────────────────────────────────────────

  Widget _buildVoiceStrip() {
    final (bg, text) = switch ((_voiceProcessing, _voiceListening)) {
      (true, _) => (
          Colors.amber[900]!,
          _voiceStatus.isNotEmpty ? _voiceStatus : 'Processing...'
        ),
      (_, true) => (
          Colors.red[900]!,
          _voicePartial.isNotEmpty ? '"$_voicePartial"' : 'Listening...'
        ),
      _ => (
          Colors.grey[850]!,
          _voiceStatus.isNotEmpty ? _voiceStatus : 'Tap mic or say a command'
        ),
    };

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Icon(
            _voiceListening ? Icons.graphic_eq : Icons.mic,
            color: Colors.white70,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.3),
                maxLines: 2),
          ),
          if (!_voiceListening && !_voiceProcessing)
            GestureDetector(
              onTap: _startListening,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.5)),
                ),
                child: const Text('Speak',
                    style:
                        TextStyle(color: Colors.green, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}
