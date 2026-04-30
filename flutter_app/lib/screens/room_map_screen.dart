import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/room_map_data.dart';
import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../services/radar_service.dart';
import '../services/depth_service.dart';
import '../services/room_map_service.dart';
import '../services/tts_service.dart';
import '../widgets/floor_plan_painter.dart';

class RoomMapScreen extends StatefulWidget {
  final String mode;

  const RoomMapScreen({super.key, required this.mode});

  @override
  State<RoomMapScreen> createState() => _RoomMapScreenState();
}

class _RoomMapScreenState extends State<RoomMapScreen>
    with SingleTickerProviderStateMixin {
  bool _scanning = false;
  String? _errorMsg;
  String _guidance = '';

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

    _guidance = RoomMapService.guidanceForCurrentScan();
    // Speak initial guidance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TtsService.speak(_guidance);
    });
  }

  @override
  void dispose() {
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
      String b64;
      if (CameraService.controller != null &&
          CameraService.controller!.value.isInitialized) {
        final file = await CameraService.controller!.takePicture();
        final bytes = kIsWeb
            ? await file.readAsBytes()
            : await File(file.path).readAsBytes();
        b64 = base64Encode(bytes);
      } else {
        throw Exception(
            'Camera not ready. Return to home and tap START first.');
      }

      final radar = await RadarService.getReadings();
      final depth = await DepthService.getReadings();

      final result = await ApiService.roomMapScan(
        b64,
        widget.mode,
        radar: radar,
        depth: depth,
        headingDeg: RoomMapService.nextHeading,
        scanIndex: RoomMapService.currentScanIndex,
      );

      if (result != null && mounted) {
        RoomMapService.addScan(result);
        final guidance = RoomMapService.guidanceForCurrentScan();
        setState(() {
          _guidance = guidance;
          _scanning = false;
        });
        await TtsService.speak(result.walkingInstruction);
        if (!RoomMapService.isComplete) {
          await Future.delayed(const Duration(milliseconds: 800));
          await TtsService.speak(guidance);
        } else {
          await TtsService.speak('Room map complete. All directions scanned.');
        }
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

  void _reset() {
    RoomMapService.reset();
    setState(() {
      _guidance = RoomMapService.guidanceForCurrentScan();
      _errorMsg = null;
    });
    TtsService.speak('Map reset. $_guidance');
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final points = RoomMapService.allPoints;
    final completed = RoomMapService.completedScans;
    final coverage = RoomMapService.coveragePct;
    final isComplete = RoomMapService.isComplete;
    final scannedHeadings =
        RoomMapService.scans.map((s) => s.headingDeg).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text('Room Map',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            _sensorBadge(),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reset map',
            icon: const Icon(Icons.delete_outline, color: Colors.orange),
            onPressed: _reset,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Coverage progress bar ──────────────────────────────────────
          _buildCoverageBar(completed, coverage, isComplete),

          // ── Floor plan ────────────────────────────────────────────────
          Expanded(
            flex: 55,
            child: _buildFloorPlan(points, scannedHeadings),
          ),

          Container(height: 1, color: Colors.green.withValues(alpha: 0.2)),

          // ── Guidance + scan button panel ───────────────────────────────
          Expanded(
            flex: 45,
            child: _buildGuidancePanel(completed, isComplete),
          ),
        ],
      ),
    );
  }

  // ── Coverage bar ─────────────────────────────────────────────────────────

  Widget _buildCoverageBar(int completed, double coverage, bool isComplete) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Coverage: $completed/${RoomMapService.requiredScans} scans',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                isComplete ? 'COMPLETE' : '${coverage.toInt()}%',
                style: TextStyle(
                  color: isComplete ? Colors.green : Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: coverage / 100,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? Colors.green : Colors.amber,
              ),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Floor plan panel ─────────────────────────────────────────────────────

  Widget _buildFloorPlan(
      List<MappedPoint> points, List<double> scannedHeadings) {
    return Container(
      color: const Color(0xFF050F05),
      child: Stack(
        children: [
          // Coverage arc (behind grid)
          if (scannedHeadings.isNotEmpty)
            CustomPaint(
              painter: ScanCoverageArc(scannedHeadings: scannedHeadings),
              size: Size.infinite,
            ),

          // Floor plan points
          CustomPaint(
            painter: FloorPlanPainter(points: points),
            size: Size.infinite,
          ),

          // Empty state
          if (points.isEmpty && !_scanning)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view,
                      size: 52,
                      color: Colors.green.withValues(alpha: 0.25)),
                  const SizedBox(height: 10),
                  Text(
                    'No data yet.\nTap Scan to start mapping.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Scanning overlay
          if (_scanning)
            _scanningOverlay(),

          // Error banner
          if (_errorMsg != null)
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red[900]!.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _errorMsg = null),
                      child: const Icon(Icons.close,
                          color: Colors.white54, size: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Scan count badge
          if (RoomMapService.completedScans > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${RoomMapService.allPoints.length} pts',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Guidance panel ───────────────────────────────────────────────────────

  Widget _buildGuidancePanel(int completed, bool isComplete) {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Direction icons row
          _buildDirectionIcons(),

          const SizedBox(height: 12),

          // Guidance text
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    isComplete
                        ? Icons.check_circle
                        : Icons.navigation,
                    color: isComplete ? Colors.green : Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _guidance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.volume_up, color: Colors.green, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => TtsService.speak(_guidance),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Scan / Done buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _scanning ? Colors.grey[800] : Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _scanning ? null : _scan,
                  icon: _scanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.radar, size: 18),
                  label: Text(_scanning
                      ? 'Scanning...'
                      : (isComplete ? 'Scan Again' : 'Scan Now')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Direction icons strip ─────────────────────────────────────────────────

  Widget _buildDirectionIcons() {
    const directions = [
      (label: 'Fwd', heading: 0.0, icon: Icons.arrow_upward),
      (label: 'Right', heading: 90.0, icon: Icons.arrow_forward),
      (label: 'Back', heading: 180.0, icon: Icons.arrow_downward),
      (label: 'Left', heading: 270.0, icon: Icons.arrow_back),
    ];
    final scannedHeadings =
        RoomMapService.scans.map((s) => s.headingDeg).toSet();
    final nextHeading = RoomMapService.nextHeading;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: directions.map((d) {
        final isDone = scannedHeadings.contains(d.heading);
        final isNext = !isDone && d.heading == nextHeading;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? Colors.green.withValues(alpha: 0.3)
                    : isNext
                        ? Colors.amber.withValues(alpha: 0.3)
                        : Colors.white12,
                border: Border.all(
                  color: isDone
                      ? Colors.green
                      : isNext
                          ? Colors.amber
                          : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: Icon(
                isDone ? Icons.check : d.icon,
                color: isDone
                    ? Colors.green
                    : isNext
                        ? Colors.amber
                        : Colors.white38,
                size: 18,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              d.label,
              style: TextStyle(
                color: isDone
                    ? Colors.green
                    : isNext
                        ? Colors.amber
                        : Colors.white38,
                fontSize: 10,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  Widget _scanningOverlay() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Opacity(
        opacity: _pulseAnim.value,
        child: Container(
          color: Colors.black45,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text('Scanning room...',
                          style:
                              TextStyle(color: Colors.green, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sensorBadge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (RadarService.hasRadar)
          const Icon(Icons.sensors, color: Colors.green, size: 15),
        if (DepthService.hasDepth)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.radar, color: Colors.lightBlueAccent, size: 15),
          ),
        if (!RadarService.hasRadar && !DepthService.hasDepth)
          Text(
            'camera only',
            style: TextStyle(
                color: Colors.white38.withValues(alpha: 0.5), fontSize: 11),
          ),
      ],
    );
  }
}
