import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/navigation_data.dart';
import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../services/radar_service.dart';
import '../services/depth_service.dart';
import '../services/tts_service.dart';
import '../widgets/radar_map_painter.dart';

class NavigationMapScreen extends StatefulWidget {
  final String mode;

  const NavigationMapScreen({super.key, required this.mode});

  @override
  State<NavigationMapScreen> createState() => _NavigationMapScreenState();
}

class _NavigationMapScreenState extends State<NavigationMapScreen>
    with SingleTickerProviderStateMixin {
  NavigationData? _navData;
  bool _scanning = false;
  bool _autoScan = false;
  String? _errorMsg;
  Timer? _autoTimer;
  int _currentStep = 0;

  // Pulse animation for the scanning indicator
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_pulseCtrl);

    // Initial scan on open
    _scan();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Core scan ────────────────────────────────────────────────────────────

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _errorMsg = null;
    });

    try {
      // Capture frame
      String b64;
      if (CameraService.controller != null &&
          CameraService.controller!.value.isInitialized) {
        final file = await CameraService.controller!.takePicture();
        final bytes = kIsWeb
            ? await file.readAsBytes()
            : await File(file.path).readAsBytes();
        b64 = base64Encode(bytes);
      } else {
        throw Exception('Camera not ready. Return to home and tap START first.');
      }

      final radar = await RadarService.getReadings();
      final depth = await DepthService.getReadings();

      final data = await ApiService.navigate(
        b64,
        widget.mode,
        radar: radar,
        depth: depth,
      );

      if (data != null) {
        if (mounted) {
          setState(() {
            _navData = data;
            _currentStep = 0;
            _scanning = false;
          });
        }
        // Speak the current instruction
        await TtsService.speak(data.spokenInstruction);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _scanning = false;
        });
      }
    }
  }

  void _toggleAutoScan() {
    setState(() => _autoScan = !_autoScan);
    if (_autoScan) {
      _autoTimer = Timer.periodic(
        Duration(milliseconds: widget.mode == 'indoor' ? 5000 : 3000),
        (_) => _scan(),
      );
    } else {
      _autoTimer?.cancel();
      _autoTimer = null;
    }
  }

  Future<void> _speakCurrentStep() async {
    if (_navData == null) return;
    if (_currentStep < _navData!.instructions.length) {
      await TtsService.speak(_navData!.instructions[_currentStep]);
    }
  }

  Future<void> _speakFullRoute() async {
    if (_navData == null) return;
    final full = _navData!.instructions.join('. ');
    await TtsService.speak(full);
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text('Navigation Map',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            _sensorBadge(),
          ],
        ),
        actions: [
          // Auto-scan toggle
          IconButton(
            tooltip: _autoScan ? 'Stop auto-scan' : 'Start auto-scan',
            icon: Icon(
              _autoScan ? Icons.stop_circle_outlined : Icons.loop,
              color: _autoScan ? Colors.green : Colors.white54,
            ),
            onPressed: _toggleAutoScan,
          ),
          // Manual refresh
          IconButton(
            tooltip: 'Scan now',
            icon: const Icon(Icons.refresh),
            onPressed: _scanning ? null : _scan,
          ),
        ],
      ),
      body: Column(
        children: [
          // Radar map takes top portion
          Expanded(
            flex: 60,
            child: _buildMap(),
          ),

          // Divider
          Container(height: 1, color: Colors.green.withValues(alpha: 0.3)),

          // Route instructions panel
          Expanded(
            flex: 40,
            child: _buildInstructions(),
          ),
        ],
      ),
    );
  }

  // ── Map panel ────────────────────────────────────────────────────────────

  Widget _buildMap() {
    return Stack(
      children: [
        // Map canvas
        Container(
          color: const Color(0xFF050F05),
          child: _navData == null
              ? Center(
                  child: _scanning
                      ? _scanningIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.radar,
                                size: 60,
                                color: Colors.green.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'Scanning environment...',
                              style: TextStyle(
                                  color: Colors.green.withValues(alpha: 0.5),
                                  fontSize: 14),
                            ),
                          ],
                        ),
                )
              : CustomPaint(
                  painter: RadarMapPainter(
                    obstacles: _navData!.obstacles,
                    safeAngleDeg: _navData!.safeAngleDeg,
                    isPathClear: _navData!.isPathClear,
                  ),
                  size: Size.infinite,
                ),
        ),

        // Scanning overlay
        if (_scanning && _navData != null)
          Positioned(
            top: 8,
            right: 8,
            child: _scanningIndicator(),
          ),

        // Error overlay
        if (_errorMsg != null)
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red[900]!.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_errorMsg!,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),

        // Processing time badge
        if (_navData != null)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_navData!.processingMs}ms',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }

  // ── Instructions panel ────────────────────────────────────────────────

  Widget _buildInstructions() {
    if (_navData == null) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Text(
            'Route instructions will appear here.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    final nav = _navData!;

    return Container(
      color: Colors.grey[900],
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.black,
            child: Row(
              children: [
                Icon(
                  nav.isPathClear ? Icons.check_circle : Icons.warning_amber,
                  color: nav.isPathClear ? Colors.green : Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    nav.spokenInstruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Speak button
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.green, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Speak current instruction',
                  onPressed: _speakCurrentStep,
                ),
                const SizedBox(width: 6),
                // Speak full route
                IconButton(
                  icon: const Icon(Icons.playlist_play,
                      color: Colors.green, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Speak full route',
                  onPressed: _speakFullRoute,
                ),
              ],
            ),
          ),

          // Steps list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: nav.instructions.length,
              itemBuilder: (_, i) {
                final isActive = i == _currentStep;
                return GestureDetector(
                  onTap: () {
                    setState(() => _currentStep = i);
                    TtsService.speak(nav.instructions[i]);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.transparent,
                      border: Border.all(
                        color: isActive
                            ? Colors.green.withValues(alpha: 0.5)
                            : Colors.white12,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive ? Colors.green : Colors.white12,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.black : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            nav.instructions[i],
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (isActive)
                          const Icon(Icons.volume_up,
                              color: Colors.green, size: 14),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Prev / Next step buttons
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _stepButton(
                  icon: Icons.arrow_back,
                  label: 'Previous',
                  enabled: _currentStep > 0,
                  onTap: () {
                    setState(() => _currentStep--);
                    _speakCurrentStep();
                  },
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.radar, size: 18),
                  label: const Text('Scan Again'),
                  onPressed: _scanning ? null : _scan,
                ),
                const Spacer(),
                _stepButton(
                  icon: Icons.arrow_forward,
                  label: 'Next',
                  enabled:
                      _navData != null &&
                      _currentStep < _navData!.instructions.length - 1,
                  onTap: () {
                    setState(() => _currentStep++);
                    _speakCurrentStep();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper widgets ───────────────────────────────────────────────────────

  Widget _scanningIndicator() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Opacity(
        opacity: _pulseAnim.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.green,
                ),
              ),
              SizedBox(width: 6),
              Text('Scanning',
                  style: TextStyle(color: Colors.green, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sensorBadge() {
    final hasRadar = RadarService.hasRadar;
    final hasDepth = DepthService.hasDepth;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasRadar)
          const Icon(Icons.sensors, color: Colors.green, size: 16),
        if (hasDepth)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.radar, color: Colors.lightBlueAccent, size: 16),
          ),
      ],
    );
  }

  Widget _stepButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: enabled ? Colors.green : Colors.white24,
      ),
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
