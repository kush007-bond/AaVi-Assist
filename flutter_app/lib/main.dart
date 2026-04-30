import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('backend_url');
  if (savedUrl != null && savedUrl.isNotEmpty) {
    ApiService.baseUrl = savedUrl;
  }
  runApp(const AaViApp());
}

class AaViApp extends StatelessWidget {
  const AaViApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AaVi',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}
