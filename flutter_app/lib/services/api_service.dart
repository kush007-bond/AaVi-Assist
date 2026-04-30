import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/analyse_response.dart';
import '../models/chat_message.dart';
import '../models/navigation_data.dart';
import '../models/room_map_data.dart';

class ApiService {
  static String baseUrl = 'http://localhost:8000';

  static Future<Map<String, dynamic>?> health() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) return jsonDecode(resp.body);
    } catch (_) {}
    return null;
  }

  static Future<AnalyseResponse?> analyse(
    String imageBase64,
    String mode, {
    List<Map<String, dynamic>>? radar,
    List<Map<String, dynamic>>? depth,
    double? prevMinDistanceCm,
  }) async {
    try {
      final body = <String, dynamic>{
        'image_base64': imageBase64,
        'mode': mode,
      };
      if (radar != null && radar.isNotEmpty) body['radar'] = radar;
      if (depth != null && depth.isNotEmpty) body['depth'] = depth;
      if (prevMinDistanceCm != null) {
        body['prev_min_distance_cm'] = prevMinDistanceCm;
      }

      final resp = await http
          .post(
            Uri.parse('$baseUrl/analyse'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120)); // moondream can be slow first run

      if (resp.statusCode == 200) {
        return AnalyseResponse.fromJson(jsonDecode(resp.body));
      } else {
        // surface the server error message
        final detail = (jsonDecode(resp.body) as Map)['detail'] ?? resp.body;
        throw Exception('Server ${resp.statusCode}: $detail');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<NavigationData?> navigate(
    String imageBase64,
    String mode, {
    List<Map<String, dynamic>>? radar,
    List<Map<String, dynamic>>? depth,
  }) async {
    try {
      final body = <String, dynamic>{
        'image_base64': imageBase64,
        'mode': mode,
      };
      if (radar != null && radar.isNotEmpty) body['radar'] = radar;
      if (depth != null && depth.isNotEmpty) body['depth'] = depth;

      final resp = await http
          .post(
            Uri.parse('$baseUrl/navigate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));

      if (resp.statusCode == 200) {
        return NavigationData.fromJson(jsonDecode(resp.body));
      } else {
        final detail = (jsonDecode(resp.body) as Map)['detail'] ?? resp.body;
        throw Exception('Server ${resp.statusCode}: $detail');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<RoomScanResult?> roomMapScan(
    String imageBase64,
    String mode, {
    List<Map<String, dynamic>>? radar,
    List<Map<String, dynamic>>? depth,
    required double headingDeg,
    required int scanIndex,
  }) async {
    try {
      final body = <String, dynamic>{
        'image_base64': imageBase64,
        'mode': mode,
        'heading_deg': headingDeg,
        'scan_index': scanIndex,
      };
      if (radar != null && radar.isNotEmpty) body['radar'] = radar;
      if (depth != null && depth.isNotEmpty) body['depth'] = depth;

      final resp = await http
          .post(
            Uri.parse('$baseUrl/room-map'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));

      if (resp.statusCode == 200) {
        return RoomScanResult.fromJson(jsonDecode(resp.body));
      } else {
        final detail = (jsonDecode(resp.body) as Map)['detail'] ?? resp.body;
        throw Exception('Server ${resp.statusCode}: $detail');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<String?> chat(
    List<ChatMessage> messages, {
    String? context,
  }) async {
    try {
      final body = <String, dynamic>{
        'messages': messages.map((m) => m.toJson()).toList(),
      };
      if (context != null) body['context'] = context;

      final resp = await http
          .post(
            Uri.parse('$baseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body)['reply'] as String?;
      }
    } catch (_) {}
    return null;
  }
}
