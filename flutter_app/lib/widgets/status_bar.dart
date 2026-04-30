import 'package:flutter/material.dart';
import '../services/radar_service.dart';
import '../services/depth_service.dart';

class StatusBarWidget extends StatelessWidget {
  final String mode;
  final bool running;
  final VoidCallback onToggle;
  final VoidCallback onModeToggle;
  final bool realtimeMode;
  final bool sensorActive;
  final VoidCallback onSensorToggle;

  const StatusBarWidget({
    super.key,
    required this.mode,
    required this.running,
    required this.onToggle,
    required this.onModeToggle,
    required this.onSensorToggle,
    this.realtimeMode = false,
    this.sensorActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Mode toggle
          GestureDetector(
            onTap: onModeToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                mode.toUpperCase(),
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            realtimeMode ? 'LIVE' : (mode == 'indoor' ? '3.5s' : '1.5s'),
            style: TextStyle(
              color: realtimeMode ? Colors.green : Colors.white38,
              fontSize: 12,
              fontWeight:
                  realtimeMode ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 10),

          // Radar icon
          Tooltip(
            message: RadarService.hasRadar ? 'Radar connected' : 'No radar',
            child: Icon(
              Icons.sensors,
              color: RadarService.hasRadar ? Colors.green : Colors.white12,
              size: 18,
            ),
          ),
          const SizedBox(width: 6),

          // LiDAR / depth icon
          Tooltip(
            message: DepthService.hasDepth ? 'LiDAR/ToF active' : 'No depth sensor',
            child: Icon(
              Icons.radar,
              color: DepthService.hasDepth ? Colors.lightBlueAccent : Colors.white12,
              size: 18,
            ),
          ),

          const Spacer(),

          // Realtime sensor toggle button
          GestureDetector(
            onTap: onSensorToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: sensorActive
                    ? Colors.cyan.withValues(alpha: 0.2)
                    : Colors.transparent,
                border: Border.all(
                  color: sensorActive
                      ? Colors.cyan
                      : Colors.white38,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sensors,
                    color: sensorActive ? Colors.cyan : Colors.white38,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'REALTIME',
                    style: TextStyle(
                      color: sensorActive ? Colors.cyan : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Start / Stop button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: running ? Colors.red[800] : Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              minimumSize: const Size(80, 36),
            ),
            onPressed: onToggle,
            child: Text(
              running ? 'STOP' : 'START',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
