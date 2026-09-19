import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../providers/app_provider.dart';
import '../onboarding/onboarding_screen.dart';
import '../auth/login_screen.dart';
import '../home/main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    final app = context.read<AppProvider>();
    Widget next;
    if (!app.onboardingComplete) {
      next = const OnboardingScreen();
    } else if (!app.isAuthenticated) {
      next = const LoginScreen();
    } else {
      next = const MainShell();
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(tween: Tween(begin: 0.0, end: 1.0), duration: const Duration(milliseconds: 1200), curve: Curves.elasticOut, builder: (_, v, __) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: v, child: Image.asset('assets/logos/icon.png', width: 260, height: 260, fit: BoxFit.contain)))),
            const SizedBox(height: 32),
            // Animated progress indicator
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(
                  isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .fadeIn(duration: 600.ms)
                .then()
                .shimmer(duration: 1200.ms, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
