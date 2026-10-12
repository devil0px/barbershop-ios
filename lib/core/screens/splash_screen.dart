import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main_navigation.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/auth_repository.dart';
import '../services/notification_service.dart';

import '../services/version_check_service.dart';
import 'update_required_screen.dart';

/// Splash screen that checks session and routes accordingly.
/// Customer  → HomeScreen (tab 0)
/// Owner     → OwnerDashboard (tab 0, which shows dashboard for 'barber' user type)
/// No token  → LoginPage
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );
    _controller.forward();
    _checkSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    if (!mounted) return;

    // 🚀 Check app version requirement from server first
    final versionResult = await VersionCheckService.checkVersion();
    if (!mounted) return;

    if (versionResult.isUpdateRequired) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UpdateRequiredScreen(
            title: versionResult.title,
            message: versionResult.message,
            storeUrl: versionResult.storeUrl,
            buttonText: versionResult.buttonText,
          ),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      // 🔄 Refresh user data from server to ensure role is up-to-date
      // This runs before navigation so MainNavigationContainer reads the correct user_type
      try {
        await AuthRepository().getMe();
      } catch (_) {
        // Silent fail — proceed with cached data
      }

      NotificationService.registerToken();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationContainer()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      ),
    );
  }
}
