class AnalyseResponse {
  final String description;
  final List<String> obstacles;
  final List<String> warnings;
  final String mapText;
  final String? radarWarning;
  final String? depthWarning;
  final String? textDetected;       // any text/signs found in the scene
  final String? approachingWarning; // something moving closer from beyond sensor limit
  final String mode;
  final int processingMs;

  AnalyseResponse({
    required this.description,
    required this.obstacles,
    required this.warnings,
    required this.mapText,
    this.radarWarning,
    this.depthWarning,
    this.textDetected,
    this.approachingWarning,
    required this.mode,
    required this.processingMs,
  });

  /// Most urgent spoken alert — depth > radar > approaching > description
  String get spokenAlert =>
      depthWarning ?? radarWarning ?? approachingWarning ?? description;

  factory AnalyseResponse.fromJson(Map<String, dynamic> json) {
    return AnalyseResponse(
      description: json['description'] ?? '',
      obstacles: List<String>.from(json['obstacles'] ?? []),
      warnings: List<String>.from(json['warnings'] ?? []),
      mapText: json['map_text'] ?? '',
      radarWarning: json['radar_warning'],
      depthWarning: json['depth_warning'],
      textDetected: json['text_detected'],
      approachingWarning: json['approaching_warning'],
      mode: json['mode'] ?? 'indoor',
      processingMs: json['processing_ms'] ?? 0,
    );
  }
}
