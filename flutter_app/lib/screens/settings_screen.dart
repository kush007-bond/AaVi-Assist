import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  bool _testing = false;
  String? _statusMsg;
  Color _statusColor = Colors.white54;
  String? _visionModel;
  String? _textModel;
  int? _latencyMs;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ApiService.baseUrl);
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _statusMsg = 'Connecting...';
      _statusColor = Colors.white54;
    });

    ApiService.baseUrl = _urlCtrl.text.trim();
    final t0 = DateTime.now();
    final health = await ApiService.health();
    final ms = DateTime.now().difference(t0).inMilliseconds;

    if (health == null) {
      setState(() {
        _statusMsg = 'Connection failed';
        _statusColor = Colors.red;
        _testing = false;
      });
      return;
    }

    final ollamaOk = health['ollama_reachable'] == true;
    setState(() {
      _statusMsg = ollamaOk ? 'Connected' : 'Server up — AI model offline';
      _statusColor = ollamaOk ? Colors.green : Colors.amber;
      _visionModel = health['vision_model'];
      _textModel = health['text_model'];
      _latencyMs = ms;
      _testing = false;
    });
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    ApiService.baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL saved'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend URL',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'http://localhost:8000',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                    onPressed: _testing ? null : _testConnection,
                    child: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.green,
                            ),
                          )
                        : const Text('Test Connection'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
            if (_statusMsg != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusMsg!,
                    style: TextStyle(color: _statusColor, fontSize: 14),
                  ),
                  if (_latencyMs != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${_latencyMs}ms',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ],
              ),
              if (_visionModel != null) ...[
                const SizedBox(height: 12),
                _modelRow('Vision', _visionModel!),
                const SizedBox(height: 4),
                _modelRow('Chat', _textModel ?? '—'),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _modelRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label model: ',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        Text(value, style: const TextStyle(color: Colors.green, fontSize: 13)),
      ],
    );
  }
}
