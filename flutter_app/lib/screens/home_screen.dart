import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../app_theme.dart';
import '../models/analyse_response.dart';
import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../services/room_map_service.dart';
import '../services/tts_service.dart';
import '../services/voice_service.dart';
import '../services/realtime_service.dart';
import '../services/sensor_monitor.dart';
import '../widgets/floor_plan_painter.dart';
import '../widgets/bottom_nav_bar.dart';
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
  bool _running = false;
  bool _loading = false;
  bool _cameraReady = false;
  String _mode = 'indoor';
  AnalyseResponse? _lastResult;
  String? _errorMsg;
  String _cameraInitMsg = 'Initialising camera…';

  bool _realtimeMode = false;
  Timer? _rtFrameTimer;
  bool _rtFrameBusy = false;
  StreamSubscription? _rtSub;

  bool _sensorActive = false;
  SensorAlert? _currentSensorAlert;
  StreamSubscription? _sensorSub;

  bool _voiceEnabled = false;
  bool _voiceListening = false;
  bool _voiceProcessing = false;
  String _voiceStatus = '';
  String _voicePartial = '';

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

  Future<void> _initCamera() async {
    try {
      await CameraService.init();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraInitMsg = 'Camera unavailable: $e\n\nYou can still use the chat bar.';
          _cameraReady = false;
        });
      }
    }
  }

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
      _loading = !_realtimeMode;
      _errorMsg = null;
    });
    if (_realtimeMode) {
      _startRealtimeFrames();
    } else {
      CameraService.start(
        _mode,
        onResult: (result) {
          if (mounted) setState(() { _lastResult = result; _loading = false; _errorMsg = null; });
        },
        onError: (err) {
          if (mounted) setState(() { _loading = false; _errorMsg = err; });
        },
      );
    }
  }

  void _toggleSensorMonitor() {
    if (_sensorActive) {
      SensorMonitor.stop();
      _sensorSub?.cancel();
      _sensorSub = null;
      setState(() { _sensorActive = false; _currentSensorAlert = null; });
    } else {
      SensorMonitor.start();
      _sensorSub = SensorMonitor.alerts.listen(_onSensorAlert);
      setState(() => _sensorActive = true);
    }
  }

  void _stopAll() {
    if (_realtimeMode) {
      _rtFrameTimer?.cancel();
      _rtFrameTimer = null;
      _rtSub?.cancel();
      _rtSub = null;
      _rtFrameBusy = false;
    } else {
      CameraService.stop();
    }
    if (mounted) setState(() { _running = false; _loading = false; });
  }

  void _toggleMode() {
    if (_running) _stopAll();
    setState(() => _mode = _mode == 'indoor' ? 'outdoor' : 'indoor');
  }

  Future<void> _switchToRealtimeMode(bool on) async {
    if (on == _realtimeMode) return;
    if (_running) _stopAll();
    if (on) {
      await RealtimeService.connect(ApiService.baseUrl);
      if (!RealtimeService.isConnected) {
        setState(() => _errorMsg = 'WebSocket failed. Check backend URL in Settings.');
        return;
      }
      await TtsService.speak('Real-time mode on.');
    } else {
      RealtimeService.disconnect();
      await TtsService.speak('Real-time mode off.');
    }
    setState(() => _realtimeMode = on);
  }

  void _startRealtimeFrames() {
    _rtSub?.cancel();
    _rtSub = RealtimeService.results.listen(_onRealtimeMessage);
    _rtFrameTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (!_running || _rtFrameBusy) return;
      if (CameraService.controller == null || !CameraService.controller!.value.isInitialized) return;
      _rtFrameBusy = true;
      try {
        final file = await CameraService.controller!.takePicture();
        final bytes = kIsWeb ? await file.readAsBytes() : await File(file.path).readAsBytes();
        RealtimeService.sendFrame(imageBase64: base64Encode(bytes), mode: _mode);
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
          TtsService.speak(result.description);
          if (result.textDetected != null && result.textDetected!.trim().isNotEmpty && result.textDetected!.toLowerCase() != 'null') {
            Future.delayed(const Duration(milliseconds: 800), () => TtsService.speak('I can see text: ${result.textDetected}'));
          }
          setState(() { _lastResult = result; _loading = false; });
        } catch (_) { _rtFrameBusy = false; }

      case 'snapshot_result':
        _voiceProcessing = false;
        final answer = msg['answer'] as String? ?? 'No answer available.';
        TtsService.speak(answer);
        setState(() { _voiceStatus = answer.length > 60 ? '${answer.substring(0, 57)}...' : answer; });
        if (_voiceEnabled) Future.delayed(const Duration(milliseconds: 800), _startListening);

      case 'skipped':
        _rtFrameBusy = false;

      case 'disconnected':
        setState(() { _realtimeMode = false; _running = false; _errorMsg = 'Real-time connection lost. Tap ⚡ to reconnect.'; });

      case 'error':
        _rtFrameBusy = false;
        setState(() => _errorMsg = msg['message'] as String? ?? 'RT error');
    }
  }

  void _onSensorAlert(SensorAlert? alert) {
    if (mounted) setState(() => _currentSensorAlert = alert);
  }

  void _toggleVoice() async {
    if (_voiceListening || _voiceEnabled) {
      await VoiceService.stop();
      _micPulse.stop();
      setState(() { _voiceListening = false; _voiceEnabled = false; _voiceStatus = ''; _voicePartial = ''; });
      await TtsService.speak('Voice off.');
    } else {
      if (!VoiceService.isAvailable) {
        final ok = await VoiceService.init();
        if (!ok) { setState(() => _errorMsg = 'Speech recognition unavailable on this device.'); return; }
      }
      setState(() => _voiceEnabled = true);
      await TtsService.speak('Voice on.');
      await Future.delayed(const Duration(milliseconds: 600));
      _startListening();
    }
  }

  void _startListening() {
    if (!_voiceEnabled || _voiceListening || _voiceProcessing) return;
    setState(() { _voiceListening = true; _voiceStatus = 'Listening...'; _voicePartial = ''; });
    _micPulse.repeat(reverse: true);
    VoiceService.startListening(
      onPartial: (w) { if (mounted) setState(() => _voicePartial = w); },
      onFinal: (w) {
        _micPulse.stop();
        if (mounted) setState(() => _voiceListening = false);
        _handleVoiceResult(w);
      },
      onDone: () {
        _micPulse.stop();
        if (mounted) setState(() { _voiceListening = false; if (_voicePartial.isEmpty) _voiceStatus = 'Tap mic to speak'; });
        if (_voiceEnabled && !_voiceProcessing) Future.delayed(const Duration(milliseconds: 300), _startListening);
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
        if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => RoomMapScreen(mode: _mode)));
      case VoiceCommand.question:
        setState(() { _voiceStatus = question ?? words; _voiceProcessing = true; });
        await TtsService.speak('Let me look...');
        await _takeSnapshot(question ?? words);
      case VoiceCommand.none:
        if (_voiceEnabled) Future.delayed(const Duration(milliseconds: 300), _startListening);
    }
    if (cmd != VoiceCommand.question && cmd != VoiceCommand.none && _voiceEnabled) {
      Future.delayed(const Duration(milliseconds: 800), _startListening);
    }
  }

  Future<void> _takeSnapshot(String question) async {
    if (!_cameraReady || CameraService.controller == null) {
      await TtsService.speak('Camera not ready.');
      setState(() => _voiceProcessing = false);
      if (_voiceEnabled) Future.delayed(const Duration(milliseconds: 800), _startListening);
      return;
    }
    try {
      final file = await CameraService.controller!.takePicture();
      final bytes = kIsWeb ? await file.readAsBytes() : await File(file.path).readAsBytes();
      final b64 = base64Encode(bytes);
      if (_realtimeMode && RealtimeService.isConnected) {
        RealtimeService.sendSnapshot(imageBase64: b64, mode: _mode, question: question);
      } else {
        final analyse = await ApiService.analyse(b64, _mode);
        final ctx = analyse?.description ?? '';
        final answer = ctx.isNotEmpty ? (await ApiService.chat([], context: '$ctx\nUser asked: $question') ?? ctx) : 'I could not see anything clearly.';
        await TtsService.speak(answer);
        if (mounted) setState(() { _voiceStatus = answer.length > 60 ? '${answer.substring(0, 57)}...' : answer; _voiceProcessing = false; });
        if (_voiceEnabled) Future.delayed(const Duration(milliseconds: 600), _startListening);
      }
    } catch (e) {
      await TtsService.speak('Could not capture image.');
      setState(() => _voiceProcessing = false);
      if (_voiceEnabled) Future.delayed(const Duration(milliseconds: 800), _startListening);
    }
  }

  void _navigateTo(NavTab tab) {
    switch (tab) {
      case NavTab.home: break;
      case NavTab.navigate:
        Navigator.push(context, MaterialPageRoute(builder: (_) => NavigationMapScreen(mode: _mode)));
      case NavTab.roomMap:
        Navigator.push(context, MaterialPageRoute(builder: (_) => RoomMapScreen(mode: _mode))).then((_) => setState(() {}));
      case NavTab.settings:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Camera view
          _buildCameraSection(),

          // Sensor & status area
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDistanceBar(),
                    const SizedBox(height: 8),
                    if (_voiceEnabled) _buildVoiceStrip(),
                    if (_voiceEnabled) const SizedBox(height: 8),
                    _buildActionBar(),
                    const SizedBox(height: 8),
                    _buildDescriptionBanner(),
                    if (_errorMsg != null) ...[const SizedBox(height: 8), _buildErrorBanner()],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        current: NavTab.home,
        onTap: _navigateTo,
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.visibility, color: AppColors.primaryContainer),
        onPressed: () => _switchToRealtimeMode(!_realtimeMode),
        tooltip: _realtimeMode ? 'Disable real-time AI' : 'Enable real-time AI',
      ),
      title: const Text('VisionAid'),
      actions: [
        IconButton(
          icon: const Icon(Icons.sos_outlined, color: AppColors.primaryContainer),
          onPressed: () {},
          tooltip: 'Emergency',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(height: 2, color: const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildCameraSection() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(),

          // LIVE badge
          if (_realtimeMode && _running)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Lexend',
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Mini-map bottom-left
          Positioned(
            bottom: 12,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoomMapScreen(mode: _mode))).then((_) => setState(() {})),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryContainer, width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: RoomMapService.allPoints.isEmpty
                    ? const Icon(Icons.map_outlined, color: AppColors.primaryContainer, size: 36)
                    : MiniMapWidget(points: RoomMapService.allPoints, size: 96, onTap: () {}),
              ),
            ),
          ),

          // Mic FAB bottom-right
          Positioned(
            bottom: 12,
            right: 12,
            child: _buildMicButton(),
          ),

          // Loading overlay
          if (_loading && !_realtimeMode)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 10),
                    Text('Analysing scene…', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Lexend')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_cameraReady || CameraService.controller == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _cameraInitMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 15, fontFamily: 'Lexend'),
            ),
          ),
        ),
      );
    }
    return CameraPreview(CameraService.controller!);
  }

  Widget _buildDistanceBar() {
    final alert = _currentSensorAlert;
    final distText = alert != null ? '${alert.distanceCm.toInt()} cm' : '> 5m';
    final statusText = alert != null ? alert.message : 'Clear Path';
    final isAlert = alert != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isAlert ? AppColors.error : AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.radar,
            color: isAlert ? AppColors.error : AppColors.onSurfaceVariant,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          GestureDetector(
            onTap: _toggleSensorMonitor,
            child: Text(
              distText,
              style: TextStyle(
                fontFamily: 'PublicSans',
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: isAlert ? AppColors.error : AppColors.primaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceStrip() {
    final isListening = _voiceListening;
    final isProcessing = _voiceProcessing;
    final text = isProcessing
        ? (_voiceStatus.isNotEmpty ? _voiceStatus : 'Processing…')
        : isListening
            ? (_voicePartial.isNotEmpty ? '"$_voicePartial"' : 'Listening for command…')
            : (_voiceStatus.isNotEmpty ? _voiceStatus : 'Listening for command…');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryFixedDim),
      ),
      child: Row(
        children: [
          // Animated waveform
          SizedBox(
            width: 32,
            height: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(5, (i) {
                final heights = [12.0, 20.0, 16.0, 24.0, 12.0];
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300 + i * 80),
                  width: 4,
                  height: (isListening || isProcessing) ? heights[i] : 6.0,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontSize: 16,
                color: AppColors.onPrimaryFixed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        // Indoor / Outdoor toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: ['indoor', 'outdoor'].map((m) {
              final active = _mode == m;
              return GestureDetector(
                onTap: () { if (!active) _toggleMode(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.surfaceContainerLowest : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: active ? [const BoxShadow(color: Color(0x1A000000), blurRadius: 4)] : null,
                  ),
                  child: Text(
                    m[0].toUpperCase() + m.substring(1),
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: active ? AppColors.primaryContainer : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 12),

        // START / STOP NAV button
        Expanded(
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _running ? AppColors.tertiaryContainer : AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
                shadowColor: AppColors.primaryContainer.withValues(alpha: 0.4),
              ),
              onPressed: _cameraReady ? _toggleRunning : null,
              icon: Icon(_running ? Icons.stop : Icons.play_arrow, size: 24),
              label: Text(
                _running ? 'STOP' : 'START NAV',
                style: const TextStyle(
                  fontFamily: 'PublicSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionBanner() {
    final description = _lastResult?.description;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.visibility_outlined, color: AppColors.primaryContainer, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description ?? '"You are in a well-lit environment. Start navigation to analyse your surroundings."',
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontSize: 18,
                height: 1.5,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMsg!,
              style: const TextStyle(color: AppColors.error, fontSize: 14, fontFamily: 'Lexend'),
              maxLines: 3,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMsg = null),
            child: const Icon(Icons.close, color: AppColors.error, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    Color bg;
    Color fg;
    IconData icon;

    if (_voiceProcessing) {
      bg = Colors.amber.shade700;
      fg = Colors.black;
      icon = Icons.hourglass_empty;
    } else if (_voiceListening) {
      bg = AppColors.error;
      fg = Colors.white;
      icon = Icons.mic;
    } else if (_voiceEnabled) {
      bg = AppColors.primaryContainer;
      fg = Colors.white;
      icon = Icons.mic;
    } else {
      bg = AppColors.primaryContainer;
      fg = Colors.white;
      icon = Icons.mic;
    }

    final btn = GestureDetector(
      onTap: _toggleVoice,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Icon(icon, color: fg, size: 28),
      ),
    );

    if (_voiceListening) {
      return AnimatedBuilder(
        animation: _micScale,
        builder: (_, child) => Transform.scale(scale: _micScale.value, child: child),
        child: btn,
      );
    }
    return btn;
  }
}
