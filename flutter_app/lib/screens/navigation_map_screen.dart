// ignore_for_file: unused_element

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/navigation_data.dart';
import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../services/radar_service.dart';
import '../services/depth_service.dart';
import '../services/tts_service.dart';
import '../widgets/radar_map_painter.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'room_map_screen.dart';
import 'settings_screen.dart';

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

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() { _scanning = true; _errorMsg = null; });

    try {
      String b64;
      if (CameraService.controller != null && CameraService.controller!.value.isInitialized) {
        final file = await CameraService.controller!.takePicture();
        final bytes = kIsWeb ? await file.readAsBytes() : await File(file.path).readAsBytes();
        b64 = base64Encode(bytes);
      } else {
        throw Exception('Camera not ready. Return to home and tap START first.');
      }

      final radar = await RadarService.getReadings();
      final depth = await DepthService.getReadings();
      final data = await ApiService.navigate(b64, widget.mode, radar: radar, depth: depth);

      if (data != null && mounted) {
        setState(() { _navData = data; _currentStep = 0; _scanning = false; });
        await TtsService.speak(data.spokenInstruction);
      }
    } catch (e) {
      if (mounted) setState(() { _errorMsg = e.toString(); _scanning = false; });
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
    await TtsService.speak(_navData!.instructions.join('. '));
  }

  IconData _stepIcon(String instruction) {
    final l = instruction.toLowerCase();
    if (l.contains('right')) return Icons.turn_right;
    if (l.contains('left')) return Icons.turn_left;
    if (l.contains('straight') || l.contains('forward')) return Icons.straight;
    return Icons.navigation;
  }

  void _navigateTo(NavTab tab) {
    switch (tab) {
      case NavTab.home:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      case NavTab.roomMap:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoomMapScreen(mode: widget.mode)));
      case NavTab.settings:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Sensor status strip
          _buildSensorStrip(),
          // Radar map
          Expanded(flex: 55, child: _buildRadarMap()),
          // Instructions
          Expanded(flex: 45, child: _buildInstructionsPanel()),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(current: NavTab.home, onTap: _navigateTo),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.visibility, color: AppColors.primaryContainer),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('AaVi'),
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

  Widget _buildSensorStrip() {
    final hasRadar = RadarService.hasRadar;
    final hasDepth = DepthService.hasDepth;
    return Container(
      color: AppColors.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.radar, color: AppColors.onPrimaryContainer, size: 18),
          const SizedBox(width: 8),
          const Text(
            'RADAR ACTIVE',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const Spacer(),
          if (hasDepth) ...[
            const Text(
              'LIDAR OK',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: AppColors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.sensors, color: AppColors.surfaceContainerLowest, size: 18),
          ] else if (!hasRadar && !hasDepth)
            const Text(
              'SIM MODE',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: AppColors.primaryFixedDim,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRadarMap() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.onPrimaryFixed,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryContainer, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // Grid circles
            Positioned.fill(
              child: CustomPaint(
                painter: _RadarGridPainter(),
              ),
            ),

            // Radar sweep / obstacles
            if (_navData != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: RadarMapPainter(
                    obstacles: _navData!.obstacles,
                    safeAngleDeg: _navData!.safeAngleDeg,
                    isPathClear: _navData!.isPathClear,
                  ),
                ),
              ),

            // Scanning overlay
            if (_scanning)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  ),
                ),
              ),

            // Heading badge top-left
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.explore, color: AppColors.primaryContainer, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Heading North',
                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Processing ms badge top-right
            if (_navData != null)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_navData!.processingMs}ms',
                    style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Lexend'),
                  ),
                ),
              ),

            // Error message
            if (_errorMsg != null)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 13, fontFamily: 'Lexend')),
                ),
              ),

            // Empty state
            if (_navData == null && !_scanning)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar, size: 56, color: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(height: 8),
                    Text('Scanning environment…', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14, fontFamily: 'Lexend')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        children: [
          // Instruction cards
          Expanded(
            child: _navData == null
                ? const Center(
                    child: Text(
                      'Route instructions will appear here.',
                      style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 15, fontFamily: 'Lexend'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    itemCount: _navData!.instructions.length,
                    itemBuilder: (_, i) {
                      final isActive = i == _currentStep;
                      final isNext = i == _currentStep + 1;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _currentStep = i);
                          TtsService.speak(_navData!.instructions[i]);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.surfaceContainerLowest : AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive ? AppColors.primaryContainer : AppColors.outlineVariant,
                              width: isActive ? 3 : 1,
                            ),
                            boxShadow: isActive
                                ? [const BoxShadow(color: Color(0x261565C0), blurRadius: 12, offset: Offset(0, 4))]
                                : null,
                          ),
                          child: Row(
                            children: [
                              // Direction icon
                              Container(
                                width: isActive ? 56 : 44,
                                height: isActive ? 56 : 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive ? AppColors.primaryContainer : AppColors.surfaceContainerHighest,
                                ),
                                child: Icon(
                                  _stepIcon(_navData!.instructions[i]),
                                  color: isActive ? Colors.white : AppColors.onSurfaceVariant,
                                  size: isActive ? 28 : 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Opacity(
                                  opacity: isNext ? 0.7 : (i > _currentStep + 1 ? 0.5 : 1.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _navData!.instructions[i],
                                        style: TextStyle(
                                          fontFamily: 'PublicSans',
                                          fontSize: isActive ? 18 : 15,
                                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isActive)
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.surfaceContainerHigh,
                                    border: Border.all(color: AppColors.outlineVariant),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.volume_up, color: AppColors.primaryContainer, size: 20),
                                    onPressed: _speakCurrentStep,
                                    tooltip: 'Repeat instruction',
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Prev / Scan Again / Next bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              border: Border(top: BorderSide(color: AppColors.outlineVariant)),
            ),
            child: Row(
              children: [
                // Prev
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: (_navData != null && _currentStep > 0)
                        ? () { setState(() => _currentStep--); _speakCurrentStep(); }
                        : null,
                    child: const Text('Prev'),
                  ),
                ),
                const SizedBox(width: 10),

                // Scan Again
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _scanning ? null : _scan,
                      icon: _scanning
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.radar, size: 20),
                      label: Text(_scanning ? 'Scanning…' : 'Scan Again'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Next
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: (_navData != null && _currentStep < _navData!.instructions.length - 1)
                        ? () { setState(() => _currentStep++); _speakCurrentStep(); }
                        : null,
                    child: const Text('Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Simple radar grid painter for background
class _RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = (size.width < size.height ? size.width : size.height) / 2;

    for (final frac in [0.25, 0.5, 0.75, 1.0]) {
      canvas.drawCircle(Offset(cx, cy), maxR * frac, paint);
    }
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), paint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
  }

  @override
  bool shouldRepaint(_RadarGridPainter oldDelegate) => false;
}
