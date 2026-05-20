import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/theme.dart';
import '../../services/settings_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _settingsService = SettingsService();
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initApp();
    _initFuture.then((_) async {
      if (!mounted) return;

      final user = Supabase.instance.client.auth.currentUser;
      final isGuest = await _settingsService.getIsGuest();

      if (!mounted) return;

      if (user != null || isGuest) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/sign-in');
      }
    });
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.15, end: 1.25),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, radius, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.2),
                radius: radius,
                colors: const [
                  Color(0xFFFFC0A8),
                  AppColors.background,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: const SafeArea(
          child: Center(
            child: Text(
              "Что нового?",
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}