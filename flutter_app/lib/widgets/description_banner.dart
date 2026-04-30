import 'package:flutter/material.dart';
import '../models/analyse_response.dart';

class DescriptionBanner extends StatelessWidget {
  final AnalyseResponse? result;
  final bool loading;

  const DescriptionBanner({super.key, this.result, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                ),
                SizedBox(width: 8),
                Text('Analysing scene...', style: TextStyle(color: Colors.green, fontSize: 14)),
              ],
            )
          else if (result != null) ...[
            // Depth/LiDAR warning (highest priority — blue)
            if (result!.depthWarning != null)
              _warningBadge(result!.depthWarning!, Colors.lightBlue[900]!, Icons.radar),

            // Radar warning (second priority — red)
            if (result!.radarWarning != null)
              _warningBadge(result!.radarWarning!, Colors.red[900]!, Icons.sensors),

            // Approaching object warning (purple)
            if (result!.approachingWarning != null)
              _warningBadge(
                result!.approachingWarning!,
                Colors.purple[900]!,
                Icons.directions_run,
              ),

            // Scene description
            Text(
              result!.description,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            ),

            // Detected text badge
            if (result!.textDetected != null &&
                result!.textDetected!.trim().isNotEmpty &&
                result!.textDetected!.toLowerCase() != 'null') ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal[900],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.text_fields,
                        color: Colors.tealAccent, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        result!.textDetected!,
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Map text
            if (result!.mapText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                result!.mapText,
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],

            // Obstacle chips
            if (result!.obstacles.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: result!.obstacles
                    .map((o) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(o, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ))
                    .toList(),
              ),
            ],
          ] else
            const Text(
              'Tap START to begin scene analysis.',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _warningBadge(String message, Color bg, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
