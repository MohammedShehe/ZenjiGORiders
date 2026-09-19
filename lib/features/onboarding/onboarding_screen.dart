import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/loading_button.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/app_provider.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _locationGranted = false;
  bool _subscribeOffers = true;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    try {
      final status = await Permission.locationWhenInUse.request();
      final granted = status.isGranted || status.isLimited;
      setState(() => _locationGranted = granted);
      if (mounted) {
        context.read<AppProvider>().setLocationGranted(granted);
        if (granted) {
          // Mock realistic Zanzibar coords for frontend demo
          context.read<AppProvider>().setCurrentLocation(
            lat: -6.1659,
            lng: 39.2026,
            address: 'Mwanakwerekwe, Zanzibar',
          );
        }
      }
    } catch (_) {
      // Emulator / desktop may not support; allow mock grant for UI testing
      setState(() => _locationGranted = true);
      if (mounted) {
        context.read<AppProvider>().setLocationGranted(true);
        context.read<AppProvider>().setCurrentLocation(
          lat: -6.1659,
          lng: 39.2026,
          address: 'Mwanakwerekwe, Zanzibar',
        );
      }
    }
  }

  void _next() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      if (!_locationGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<AppProvider>().t(
              'Please enable location to continue',
              'Tafadhali washa eneo ili kuendelea',
            )),
          ),
        );
        return;
      }
      context.read<AppProvider>().completeOnboarding();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Language selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        _langChip(app, 'EN', 'en', isDark),
                        _langChip(app, 'SW', 'sw', isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildAboutPage(app, isDark, size),
                  _buildPermissionsPage(app, isDark),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: 2,
                    effect: ExpandingDotsEffect(
                      activeDotColor: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
                      dotColor: isDark ? AppColors.darkCard : Colors.grey.shade300,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  LoadingButton(
                    text: _currentPage == 0
                        ? app.t('Next', 'Endelea')
                        : app.t('Get Started', 'Anza Sasa'),
                    onPressed: _next,
                    icon: _currentPage == 1 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _langChip(AppProvider app, String label, String code, bool isDark) {
    final selected = app.locale.languageCode == code;
    return GestureDetector(
      onTap: () => app.setLocale(Locale(code)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.aquaGreen : AppColors.oceanTeal)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildAboutPage(AppProvider app, bool isDark, Size size) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const AppLogo(height: 70)
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: -0.2, end: 0),
          const SizedBox(height: 32),
          Text(
            app.t('Welcome to ZenjiGO', 'Karibu ZenjiGO'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.offWhite : AppColors.charcoal,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 12),
          Text(
            app.t(
              'Your trusted ride partner in Zanzibar. Fast, safe & affordable rides across Unguja & Pemba.',
              'Mshirika wako wa kuaminika wa usafiri Zanzibar. Safari za haraka, salama na nafuu Unguja na Pemba.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ).animate().fadeIn(delay: 350.ms),
          const SizedBox(height: 36),
          _featureCard(
            Icons.motorcycle_rounded,
            app.t('Boda, Bajaji & Taxi', 'Boda, Bajaji & Teksi'),
            app.t('Choose the ride that fits your trip', 'Chagua usafiri unaofaa safari yako'),
            isDark,
            0,
          ),
          _featureCard(
            Icons.location_on_rounded,
            app.t('Live Tracking', 'Ufuatiliaji wa Moja kwa Moja'),
            app.t('Track your driver in real-time', 'Fuatilia dereva wako kwa wakati halisi'),
            isDark,
            1,
          ),
          _featureCard(
            Icons.payments_rounded,
            app.t('Flexible Payments', 'Malipo Rahisi'),
            app.t('Cash, M-Pesa, Airtel, Wallet & more', 'Fedha, M-Pesa, Airtel, Pochi na zaidi'),
            isDark,
            2,
          ),
          _featureCard(
            Icons.support_agent_rounded,
            app.t('24/7 Support', 'Msaada 24/7'),
            app.t('We are always here for you', 'Tuko hapa kila wakati kwa ajili yako'),
            isDark,
            3,
          ),
        ],
      ),
    );
  }

  Widget _featureCard(IconData icon, String title, String subtitle, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.aquaGreen : AppColors.oceanTeal).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (400 + index * 100).ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildPermissionsPage(AppProvider app, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Icon(
            Icons.security_rounded,
            size: 72,
            color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            app.t('Enable Permissions', 'Ruhusu Ruhusa'),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.offWhite : AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            app.t(
              'To give you the best experience, we need a few permissions.',
              'Ili kukupa huduma bora, tunahitaji ruhusa chache.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 36),
          _permissionTile(
            Icons.location_on_rounded,
            app.t('Location Access', 'Ufikiaji wa Mahali'),
            app.t('Required to find nearby drivers and show your position on the map.',
                'Inahitajika kupata madereva karibu na kuonyesha nafasi yako kwenye ramani.'),
            _locationGranted,
            (v) async {
              if (v == true) {
                await _requestLocation();
              } else {
                setState(() => _locationGranted = false);
                if (mounted) context.read<AppProvider>().setLocationGranted(false);
              }
            },
            isDark,
            true,
          ),
          const SizedBox(height: 14),
          _permissionTile(
            Icons.notifications_active_rounded,
            app.t('Offers & Updates', 'Ofa na Taarifa'),
            app.t('Receive exclusive promotions, ride updates and news from ZenjiGO.',
                'Pokea ofa maalum, taarifa za safari na habari kutoka ZenjiGO.'),
            _subscribeOffers,
            (v) => setState(() => _subscribeOffers = v),
            isDark,
            false,
          ),
          const SizedBox(height: 24),
          if (!_locationGranted)
            Text(
              app.t('Location is required to continue', 'Mahali inahitajika kuendelea'),
              style: TextStyle(color: AppColors.sunsetOrange, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _permissionTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDark,
    bool required,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: value
            ? Border.all(color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.aquaGreen : AppColors.oceanTeal).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    if (required) ...[
                      const SizedBox(width: 6),
                      Text('*', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
          ),
        ],
      ),
    );
  }
}
