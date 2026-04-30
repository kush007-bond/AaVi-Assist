import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket client for the `/ws/realtime` backend endpoint.
///
/// Three outbound message types:
///   sensor_ping  — fast sensor check, no AI
///   analyse      — full AI pipeline (skipped if AI is busy)
///   snapshot     — immediate photo + voice question, cancels pending analyse
///
/// All inbound results are delivered via [results] stream.
class RealtimeService {
  static WebSocketChannel? _channel;
  static StreamSubscription? _sub;
  static bool _connected = false;

  static bool get isConnected => _connected;

  static final StreamController<Map<String, dynamic>> _ctrl =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of all messages from the server.
  static Stream<Map<String, dynamic>> get results => _ctrl.stream;

  // ── Connection ────────────────────────────────────────────────────────────

  static Future<void> connect(String httpBaseUrl) async {
    disconnect();
    final wsUrl = httpBaseUrl
        .replaceFirst(RegExp(r'^https://'), 'wss://')
        .replaceFirst(RegExp(r'^http://'), 'ws://');
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/realtime'),
      );
      // Await handshake (throws if server unreachable)
      await _channel!.ready;
      _connected = true;

      _sub = _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            _ctrl.add(msg);
          } catch (e) {
            debugPrint('RealtimeService parse error: $e');
          }
        },
        onDone: () {
          _connected = false;
          _ctrl.add({'type': 'disconnected'});
        },
        onError: (e) {
          _connected = false;
          _ctrl.add({'type': 'error', 'message': e.toString()});
        },
        cancelOnError: false,
      );
    } catch (e) {
      _connected = false;
      debugPrint('RealtimeService connect failed: $e');
    }
  }

  static void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  // ── Outbound messages ─────────────────────────────────────────────────────

  /// Full AI analysis of a camera frame.
  /// Sensors are handled locally by SensorMonitor — not sent here.
  static void sendFrame({
    required String imageBase64,
    required String mode,
    List<Map<String, dynamic>>? radar,
    List<Map<String, dynamic>>? depth,
    double? prevMinDistanceCm,
  }) {
    _send({
      'type': 'analyse',
      'image_base64': imageBase64,
      'mode': mode,
      if (radar != null && radar.isNotEmpty) 'radar': radar,
      if (depth != null && depth.isNotEmpty) 'depth': depth,
      if (prevMinDistanceCm != null) 'prev_min_distance_cm': prevMinDistanceCm,
    });
  }

  /// Priority snapshot — cancels pending AI analysis, answers a question
  /// using an immediately captured image.
  static void sendSnapshot({
    required String imageBase64,
    required String mode,
    required String question,
  }) {
    _send({
      'type': 'snapshot',
      'image_base64': imageBase64,
      'mode': mode,
      'question': question,
    });
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static void _send(Map<String, dynamic> msg) {
    if (!_connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(msg));
    } catch (e) {
      debugPrint('RealtimeService send error: $e');
    }
  }
}
