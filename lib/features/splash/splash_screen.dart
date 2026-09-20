import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_provider.dart';
import '../onboarding/onboarding_screen.dart';
import '../auth/login_screen.dart';
import '../home/main_shell.dart';

/// Brand splash: a map-pin "drop" animation (the ZenjiGO pin lands like a
/// pickup marker, complete with impact ripple + ground shadow), a
/// wordmark reveal, and a small car gliding along a dashed road as the
/// loading indicator — echoing the ride-hailing theme end to end.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Pin drop + impact (plays once).
  late final AnimationController _dropCtrl;
  late final Animation<double> _dropY;
  late final Animation<double> _pinScale;
  late final Animation<double> _shadowScale;
  late final Animation<double> _shadowOpacity;

  // Impact ripple rings (loops after landing).
  late final AnimationController _rippleCtrl;

  // Gentle idle "breathing" once the pin has landed (loops).
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowScale;

  // Car sliding along the dashed road loader (loops).
  late final AnimationController _roadCtrl;

  // Slow background wave drift (loops).
  late final AnimationController _waveCtrl;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _dropCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _dropY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -230.0, end: 16.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 58,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 16.0, end: -8.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -8.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 22,
      ),
    ]).animate(_dropCtrl);

    _pinScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.45, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 58,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.14, end: 0.95)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
    ]).animate(_dropCtrl);

    _shadowScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.32), weight: 58),
      TweenSequenceItem(
        tween: Tween(begin: 0.32, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 0.92)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 28,
      ),
    ]).animate(_dropCtrl);

    _shadowOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.18), weight: 58),
      TweenSequenceItem(tween: Tween(begin: 0.18, end: 0.38), weight: 14),
      TweenSequenceItem(tween: Tween(begin: 0.38, end: 0.30), weight: 28),
    ]).animate(_dropCtrl);

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    _glowScale = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _roadCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();

    _dropCtrl.forward();
    // Kick off the impact ripple + idle glow right as the pin lands.
    Future.delayed(const Duration(milliseconds: 560), () {
      if (!mounted) return;
      _rippleCtrl.repeat();
      _glowCtrl.repeat(reverse: true);
    });

    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 3300));
    if (!mounted || _navigated) return;
    _navigated = true;
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
    _dropCtrl.dispose();
    _rippleCtrl.dispose();
    _glowCtrl.dispose();
    _roadCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The splash always uses the brand-navy treatment so it hands off
    // seamlessly from the native launch screen with zero color flash.
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Soft brand gradient behind everything.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.darkBg,
                  Color(0xFF0E2340),
                  AppColors.darkBg,
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // Gentle drifting ocean waves along the bottom, echoing the
          // logo's own water motif.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, __) => CustomPaint(
                painter: _WavePainter(progress: _waveCtrl.value),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 4),

                // --- Pin drop + ripple + shadow -----------------------
                SizedBox(
                  height: 260,
                  child: AnimatedBuilder(
                    animation: Listenable.merge(
                        [_dropCtrl, _rippleCtrl, _glowCtrl]),
                    builder: (context, child) {
                      final landed = _dropCtrl.isCompleted;
                      final scale =
                          _pinScale.value * (landed ? _glowScale.value : 1.0);
                      return Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Ground shadow (a true ellipse, not a circle
                          // squashed into a non-square box).
                          Positioned(
                            bottom: 18,
                            child: Transform.scale(
                              scale: _shadowScale.value,
                              child: Container(
                                width: 120,
                                height: 22,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.all(Radius.elliptical(60, 11)),
                                  color: Colors.black
                                      .withOpacity(_shadowOpacity.value),
                                ),
                              ),
                            ),
                          ),

                          // Impact ripple rings.
                          if (_rippleCtrl.isAnimating)
                            ...List.generate(3, (i) {
                              final offset = i / 3;
                              final t = (_rippleCtrl.value + offset) % 1.0;
                              final w = 40 + t * 170;
                              final h = 14 + t * 26;
                              return Positioned(
                                bottom: 26,
                                child: Opacity(
                                  opacity: (1 - t).clamp(0.0, 1.0) * 0.35,
                                  child: Container(
                                    width: w,
                                    height: h,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(
                                          Radius.elliptical(w / 2, h / 2)),
                                      border: Border.all(
                                        color: AppColors.aquaGreen,
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),

                          // The pin itself.
                          Transform.translate(
                            offset: Offset(0, _dropY.value),
                            child: Transform.scale(
                              scale: scale,
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: landed
                                      ? [
                                          BoxShadow(
                                            color: AppColors.skyBlue
                                                .withOpacity(0.35),
                                            blurRadius: 34,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Image.asset(
                                  'assets/logos/icon.png',
                                  width: 148,
                                  height: 148,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 22),

                // --- Wordmark -------------------------------------------
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    children: const [
                      TextSpan(
                        text: 'Zenji',
                        style: TextStyle(color: AppColors.offWhite),
                      ),
                      TextSpan(
                        text: 'GO',
                        style: TextStyle(color: AppColors.aquaGreen),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 640.ms, duration: 520.ms)
                    .slideY(
                        begin: 0.35,
                        end: 0,
                        delay: 640.ms,
                        duration: 520.ms,
                        curve: Curves.easeOutCubic),

                const SizedBox(height: 8),

                Builder(builder: (context) {
                  final app = context.watch<AppProvider>();
                  return Text(
                    app.t('RIDE  •  EXPLORE  •  ZANZIBAR',
                            'SAFARI  •  GUNDUA  •  ZANZIBAR')
                        .toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: AppColors.darkTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.2,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 900.ms, duration: 500.ms)
                      .slideY(
                          begin: 0.3,
                          end: 0,
                          delay: 900.ms,
                          duration: 500.ms,
                          curve: Curves.easeOutCubic);
                }),

                const Spacer(flex: 3),

                // --- Road loader -----------------------------------------
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: SizedBox(
                    width: 168,
                    height: 30,
                    child: AnimatedBuilder(
                      animation: _roadCtrl,
                      builder: (_, __) => CustomPaint(
                        painter: _RoadLoaderPainter(progress: _roadCtrl.value),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 1150.ms, duration: 450.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed road with a small car gliding along it — the splash's loading
/// indicator, styled to match the pin's own road-and-car artwork.
class _RoadLoaderPainter extends CustomPainter {
  final double progress;
  _RoadLoaderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final roadY = size.height * 0.72;

    // Road base line.
    final roadPaint = Paint()
      ..color = AppColors.darkTextSecondary.withOpacity(0.25)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, roadY), Offset(size.width, roadY), roadPaint);

    // Dashes scrolling to suggest forward motion.
    final dashPaint = Paint()
      ..color = AppColors.aquaGreen.withOpacity(0.85)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dashWidth = 10.0;
    const dashGap = 9.0;
    final shift = progress * (dashWidth + dashGap);
    for (double x = -dashWidth + shift; x < size.width; x += dashWidth + dashGap) {
      canvas.drawLine(
        Offset(x, roadY),
        Offset(x + dashWidth * 0.55, roadY),
        dashPaint,
      );
    }

    // Car bobbing gently as it glides left to right, then loops.
    final carX = size.width * progress;
    final bob = math.sin(progress * math.pi * 6) * 1.4;
    final carCenter = Offset(carX, roadY - 9 + bob);

    final bodyPaint = Paint()..color = AppColors.offWhite;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: carCenter, width: 26, height: 12),
      const Radius.circular(5),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    final cabinRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: carCenter.translate(-1, -7), width: 14, height: 8),
      const Radius.circular(3),
    );
    canvas.drawRRect(cabinRect, bodyPaint);

    final wheelPaint = Paint()..color = AppColors.darkBg;
    canvas.drawCircle(carCenter.translate(-7, 6.5), 3.1, wheelPaint);
    canvas.drawCircle(carCenter.translate(7, 6.5), 3.1, wheelPaint);

    // Soft glow trailing the car.
    final glowPaint = Paint()
      ..color = AppColors.aquaGreen.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(carCenter, 14, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _RoadLoaderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Two soft, slowly drifting wave layers along the bottom of the splash,
/// nodding to the water in the ZenjiGO mark without competing with it.
class _WavePainter extends CustomPainter {
  final double progress;
  _WavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    _drawWave(
      canvas,
      size,
      baseHeight: size.height * 0.94,
      amplitude: 7,
      waveLength: size.width * 0.9,
      phase: progress * 2 * math.pi,
      color: AppColors.oceanTeal.withOpacity(0.10),
    );
    _drawWave(
      canvas,
      size,
      baseHeight: size.height * 0.965,
      amplitude: 5,
      waveLength: size.width * 0.65,
      phase: -progress * 2 * math.pi * 1.4,
      color: AppColors.aquaGreen.withOpacity(0.08),
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required double baseHeight,
    required double amplitude,
    required double waveLength,
    required double phase,
    required Color color,
  }) {
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, baseHeight);
    for (double x = 0; x <= size.width; x++) {
      final y = baseHeight +
          amplitude * math.sin((x / waveLength) * 2 * math.pi + phase);
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
