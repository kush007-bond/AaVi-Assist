import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'room_map_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  bool _testing = false;
  String? _statusMsg;
  bool _isConnected = false;
  String? _visionModel;
  String? _textModel;
  int? _latencyMs;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ApiService.baseUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _statusMsg = 'Connecting…';
      _isConnected = false;
      _visionModel = null;
      _textModel = null;
    });

    ApiService.baseUrl = _urlCtrl.text.trim();
    final t0 = DateTime.now();
    final health = await ApiService.health();
    final ms = DateTime.now().difference(t0).inMilliseconds;

    if (health == null) {
      setState(() { _statusMsg = 'Connection failed'; _isConnected = false; _testing = false; });
      return;
    }

    final ollamaOk = health['ollama_reachable'] == true;
    setState(() {
      _statusMsg = ollamaOk ? 'Connected' : 'Server up — AI model offline';
      _isConnected = ollamaOk;
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
        SnackBar(
          content: const Text('Settings saved', style: TextStyle(fontFamily: 'Lexend')),
          backgroundColor: AppColors.primaryContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _navigateTo(NavTab tab) {
    switch (tab) {
      case NavTab.home:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      case NavTab.roomMap:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoomMapScreen(mode: 'indoor')));
      case NavTab.settings: break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header
            const Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'PublicSans',
                fontSize: 40,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Configure connection and assistant preferences.',
              style: TextStyle(fontFamily: 'Lexend', fontSize: 16, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Server Connection card
            _buildCard(
              icon: Icons.cloud_sync_outlined,
              title: 'Server Connection',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backend URL',
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlCtrl,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontFamily: 'Lexend', fontSize: 17, color: AppColors.onSurface),
                    decoration: InputDecoration(
                      hintText: 'http://localhost:8000',
                      hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
                      prefixIcon: const Icon(Icons.link, color: AppColors.outline),
                      filled: true,
                      fillColor: AppColors.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primaryContainer, width: 3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The local or remote server processing camera feeds.',
                    style: TextStyle(fontFamily: 'Lexend', fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _testing ? null : _testConnection,
                            icon: _testing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryContainer))
                                : const Icon(Icons.wifi_tethering, size: 20),
                            label: const Text('Test Connection'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save, size: 20),
                            label: const Text('Save Settings'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // System Status card
            _buildCard(
              icon: Icons.analytics_outlined,
              title: 'System Status',
              child: Column(
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current Status', style: TextStyle(fontFamily: 'Lexend', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _statusDot(),
                              const SizedBox(width: 8),
                              Text(
                                _statusMsg ?? 'Not tested',
                                style: TextStyle(
                                  fontFamily: 'Lexend',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                  color: _statusColor(),
                                ),
                              ),
                              if (_latencyMs != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${_latencyMs}ms',
                                  style: const TextStyle(fontFamily: 'Lexend', fontSize: 12, color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_visionModel != null) ...[
                    const SizedBox(height: 16),
                    _modelRow(Icons.model_training, 'Active Vision Model', _visionModel!),
                    const Divider(height: 20, color: AppColors.surfaceVariant),
                    _modelRow(Icons.forum_outlined, 'Active Chat Model', _textModel ?? '—'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(current: NavTab.settings, onTap: _navigateTo),
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

  Widget _buildCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontFamily: 'PublicSans', fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _modelRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontFamily: 'Lexend', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
            Text(value, style: const TextStyle(fontFamily: 'Lexend', fontSize: 16, color: AppColors.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  Widget _statusDot() {
    final color = _statusColor();
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.3),
          ),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: const Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Color _statusColor() {
    if (_statusMsg == null) return AppColors.onSurfaceVariant;
    if (_statusMsg == 'Connecting…') return AppColors.onSurfaceVariant;
    if (_isConnected) return const Color(0xFF2E7D32);
    if (_statusMsg!.contains('offline') || _statusMsg!.contains('up')) return Colors.orange;
    return AppColors.error;
  }
}
