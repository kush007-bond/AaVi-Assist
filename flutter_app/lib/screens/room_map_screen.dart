import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/room_map_data.dart';
import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../services/radar_service.dart';
import '../services/depth_service.dart';
import '../services/room_map_service.dart';
import '../services/tts_service.dart';
import '../widgets/floor_plan_painter.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class RoomMapScreen extends StatefulWidget {
  final String mode;

  const RoomMapScreen({super.key, required this.mode});

  @override
  State<RoomMapScreen> createState() => _RoomMapScreenState();
}

class _RoomMapScreenState extends State<RoomMapScreen> {
  bool _scanning = false;
  String? _errorMsg;
  String _guidance = '';

  @override
  void initState() {
    super.initState();
    _guidance = RoomMapService.guidanceForCurrentScan();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TtsService.speak(_guidance);
    });
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
      final result = await ApiService.roomMapScan(
        b64, widget.mode, radar: radar, depth: depth,
        headingDeg: RoomMapService.nextHeading,
        scanIndex: RoomMapService.currentScanIndex,
      );

      if (result != null && mounted) {
        RoomMapService.addScan(result);
        final guidance = RoomMapService.guidanceForCurrentScan();
        setState(() { _guidance = guidance; _scanning = false; });
        await TtsService.speak(result.walkingInstruction);
        if (!RoomMapService.isComplete) {
          await Future.delayed(const Duration(milliseconds: 800));
          await TtsService.speak(guidance);
        } else {
          await TtsService.speak('Room map complete. All directions scanned.');
        }
      }
    } catch (e) {
      if (mounted) setState(() { _errorMsg = e.toString(); _scanning = false; });
    }
  }

  void _reset() {
    RoomMapService.reset();
    setState(() { _guidance = RoomMapService.guidanceForCurrentScan(); _errorMsg = null; });
    TtsService.speak('Map reset. $_guidance');
  }

  void _navigateTo(NavTab tab) {
    switch (tab) {
      case NavTab.home:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      case NavTab.roomMap: break;
      case NavTab.settings:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = RoomMapService.allPoints;
    final completed = RoomMapService.completedScans;
    final coverage = RoomMapService.coveragePct;
    final isComplete = RoomMapService.isComplete;
    final scannedHeadings = RoomMapService.scans.map((s) => s.headingDeg).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Coverage progress
              _buildCoverageCard(completed, RoomMapService.requiredScans, coverage, isComplete),
              const SizedBox(height: 16),

              // Floor plan
              _buildFloorPlanCard(points, scannedHeadings),
              const SizedBox(height: 16),

              // Direction scan guidance
              _buildDirectionPanel(completed, isComplete),
              const SizedBox(height: 16),

              // Error
              if (_errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMsg!, style: const TextStyle(color: AppColors.error, fontFamily: 'Lexend', fontSize: 14)),
                ),
                const SizedBox(height: 16),
              ],

              // Scan Now button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: isComplete ? null : (_scanning ? null : _scan),
                  icon: _scanning
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.radar, size: 22),
                  label: Text(
                    _scanning ? 'Scanning…' : (isComplete ? 'Scan Complete' : 'Scan Now'),
                    style: const TextStyle(fontFamily: 'PublicSans', fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(current: NavTab.roomMap, onTap: _navigateTo),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.visibility, color: AppColors.primaryContainer),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('VisionAid'),
      actions: [
        IconButton(
          icon: const Icon(Icons.sos_outlined, color: AppColors.primaryContainer),
          onPressed: _reset,
          tooltip: 'Reset Map',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(height: 2, color: const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildCoverageCard(int completed, int required, double coverage, bool isComplete) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Room Coverage',
                style: TextStyle(fontFamily: 'PublicSans', fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onSurface),
              ),
              Text(
                '$completed/$required Scans',
                style: const TextStyle(fontFamily: 'Lexend', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryContainer),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: coverage / 100,
              minHeight: 14,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? const Color(0xFF2E7D32) : AppColors.primaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isComplete ? 'Map complete! All directions scanned.' : 'Complete remaining directions to build map.',
            style: const TextStyle(fontFamily: 'Lexend', fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorPlanCard(List<MappedPoint> points, List<double> scannedHeadings) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            // Grid background
            Positioned.fill(
              child: CustomPaint(painter: _GridBackgroundPainter()),
            ),

            // Coverage arc
            if (scannedHeadings.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(painter: ScanCoverageArc(scannedHeadings: scannedHeadings)),
              ),

            // Floor plan
            Positioned.fill(
              child: CustomPaint(painter: FloorPlanPainter(points: points)),
            ),

            // Empty state
            if (points.isEmpty && !_scanning)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 52, color: AppColors.primaryContainer.withValues(alpha: 0.3)),
                    const SizedBox(height: 8),
                    const Text('No data yet. Tap Scan Now to start.', style: TextStyle(color: AppColors.onSurfaceVariant, fontFamily: 'Lexend', fontSize: 14)),
                  ],
                ),
              ),

            // Legend
            Positioned(
              bottom: 8,
              right: 8,
              child: Row(
                children: [
                  _legendItem(AppColors.primaryContainer.withValues(alpha: 0.2), AppColors.primaryContainer, 'Scanned'),
                  const SizedBox(width: 6),
                  _legendItem(AppColors.error.withValues(alpha: 0.2), AppColors.error, 'Obstacle'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color fill, Color border, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: border),
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontFamily: 'Lexend', fontSize: 11, color: AppColors.onSurface)),
        ],
      ),
    );
  }

  Widget _buildDirectionPanel(int completed, bool isComplete) {
    final directions = ['Forward', 'Right', 'Back', 'Left'];
    final icons = [Icons.arrow_upward, Icons.arrow_forward, Icons.arrow_downward, Icons.arrow_back];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Required Scans',
            style: TextStyle(fontFamily: 'Lexend', fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.onSurface),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: List.generate(directions.length, (i) {
              final isDone = i < completed;
              final isNext = i == completed && !isComplete;
              final isPending = i > completed;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isNext
                      ? const Color(0xFFFFF8E1)
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isNext ? Colors.orange : AppColors.outlineVariant,
                    width: isNext ? 2 : 1,
                  ),
                  boxShadow: isNext
                      ? [BoxShadow(color: Colors.orange.withValues(alpha: 0.2), blurRadius: 12)]
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Opacity(
                    opacity: isPending ? 0.5 : 1.0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDone)
                          const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 16)
                        else if (isNext)
                          const Icon(Icons.radio_button_unchecked, color: Colors.orange, size: 14),
                        const SizedBox(height: 2),
                        Icon(
                          icons[i],
                          size: 24,
                          color: isNext ? Colors.orange : (isDone ? AppColors.onSurface : AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isNext ? '${directions[i]}\n(Next)' : directions[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 9,
                            height: 1.1,
                            fontWeight: isNext ? FontWeight.w700 : FontWeight.w400,
                            color: isNext ? Colors.orange.shade800 : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x12808080)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridBackgroundPainter oldDelegate) => false;
}
