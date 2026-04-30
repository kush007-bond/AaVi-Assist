import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/radar_service.dart';
import '../services/depth_service.dart';
import '../services/tts_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Starting up...';
  bool _connected = false;
  bool _visionReady = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await TtsService.init();

    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('backend_url') ?? 'http://localhost:8000';
    ApiService.baseUrl = url;

    setState(() => _status = 'Checking server...');
    final health = await ApiService.health();
    if (health != null) {
      _connected = true;
      _visionReady = health['vision_model_loaded'] == true;
      setState(() => _status = _visionReady
          ? 'Server ready — vision model loaded'
          : 'Server connected — vision model not loaded\n(run: ollama pull moondream)');
    } else {
      setState(() => _status = 'Server not reachable\nConfigure URL in Settings');
    }

    setState(() => _status += '\nDetecting sensors...');
    await Future.wait([
      RadarService.detectSensor(),
      DepthService.detectSensor(),
    ]);

    final sensorStatus = [
      if (RadarService.hasRadar) 'Radar detected',
      if (DepthService.hasDepth) 'LiDAR/ToF detected',
      if (!RadarService.hasRadar && !DepthService.hasDepth) 'No external sensors — camera-only mode',
    ].join(' · ');
    setState(() => _status += '\n$sensorStatus');

    await Future.delayed(const Duration(milliseconds: 1800));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility, color: Colors.green, size: 72),
            const SizedBox(height: 24),
            const Text(
              'VisionAid',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'AI Navigation Assistant',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _connected
                    ? (_visionReady ? Colors.green : Colors.amber)
                    : Colors.white38,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
