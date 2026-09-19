import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/loading_button.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/app_provider.dart';
import '../home/main_shell.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String _countryCode = '+255';
  bool _otpSent = false;
  bool _loading = false;
  bool _useWhatsApp = false;
  int _countdown = 0;

  final List<Map<String, String>> _countries = [
    {'name': 'Tanzania', 'code': '+255', 'flag': '🇹🇿'},
    {'name': 'Kenya', 'code': '+254', 'flag': '🇰🇪'},
    {'name': 'Uganda', 'code': '+256', 'flag': '🇺🇬'},
    {'name': 'Rwanda', 'code': '+250', 'flag': '🇷🇼'},
    {'name': 'Burundi', 'code': '+257', 'flag': '🇧🇮'},
    {'name': 'Mozambique', 'code': '+258', 'flag': '🇲🇿'},
    {'name': 'Malawi', 'code': '+265', 'flag': '🇲🇼'},
    {'name': 'Zambia', 'code': '+260', 'flag': '🇿🇲'},
    {'name': 'South Africa', 'code': '+27', 'flag': '🇿🇦'},
    {'name': 'Nigeria', 'code': '+234', 'flag': '🇳🇬'},
    {'name': 'Ghana', 'code': '+233', 'flag': '🇬🇭'},
    {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧'},
    {'name': 'United States', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'India', 'code': '+91', 'flag': '🇮🇳'},
    {'name': 'UAE', 'code': '+971', 'flag': '🇦🇪'},
    {'name': 'Germany', 'code': '+49', 'flag': '🇩🇪'},
    {'name': 'France', 'code': '+33', 'flag': '🇫🇷'},
    {'name': 'China', 'code': '+86', 'flag': '🇨🇳'},
    {'name': 'Canada', 'code': '+1', 'flag': '🇨🇦'},
    {'name': 'Australia', 'code': '+61', 'flag': '🇦🇺'},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.trim().length < 9) {
      _showSnack(context.read<AppProvider>().t('Enter a valid phone number', 'Ingiza nambari sahihi ya simu'));
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _otpSent = true;
      _countdown = 60;
    });
    _startCountdown();
    _showSnack(
      context.read<AppProvider>().t(
            'OTP sent via ${_useWhatsApp ? "WhatsApp" : "SMS"}',
            'OTP imetumwa kupitia ${_useWhatsApp ? "WhatsApp" : "SMS"}',
          ),
    );
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _countdown <= 0) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 4) {
      _showSnack(context.read<AppProvider>().t('Enter 4-digit OTP', 'Ingiza OTP ya tarakimu 4'));
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Demo: accept 1234 or any 4 digits
    final user = UserModel(
      id: 'u1',
      fullName: 'Guest Rider',
      phone: '$_countryCode${_phoneController.text.trim()}',
      island: 'Unguja',
      region: 'Zanzibar Urban/West (Mjini Magharibi)',
      district: 'West (Magharibi)',
      ward: 'Mwanakwerekwe',
      walletBalance: 5000,
      savedLocations: [
        SavedLocationModel(
          id: 'home',
          label: 'Home',
          address: 'Mwanakwerekwe, West',
          island: 'Unguja',
          region: 'Zanzibar Urban/West (Mjini Magharibi)',
          district: 'West (Magharibi)',
          ward: 'Mwanakwerekwe',
        ),
      ],
    );
    await context.read<AppProvider>().login(user);
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (_) => false,
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showCountryPicker() {
    final isDark = context.read<AppProvider>().isDark;
    final searchCtrl = TextEditingController();
    List<Map<String, String>> filtered = List.from(_countries);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollCtrl) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          hintText: context.read<AppProvider>().t('Search country', 'Tafuta nchi'),
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (q) {
                          setModal(() {
                            filtered = _countries
                                .where((c) =>
                                    c['name']!.toLowerCase().contains(q.toLowerCase()) ||
                                    c['code']!.contains(q))
                                .toList();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final c = filtered[i];
                          final selected = c['code'] == _countryCode;
                          return ListTile(
                            leading: Text(c['flag']!, style: const TextStyle(fontSize: 28)),
                            title: Text(c['name']!),
                            trailing: Text(c['code']!, style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? (isDark ? AppColors.aquaGreen : AppColors.oceanTeal)
                                  : null,
                            )),
                            selected: selected,
                            onTap: () {
                              setState(() => _countryCode = c['code']!);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const AppLogo(height: 70)
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 32),
              Text(
                _otpSent
                    ? app.t('Verify OTP', 'Thibitisha OTP')
                    : app.t('Welcome Back', 'Karibu Tena'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.offWhite : AppColors.charcoal,
                ),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? app.t(
                        'Enter the 4-digit code sent to $_countryCode ${_phoneController.text}',
                        'Ingiza nambari ya tarakimu 4 iliyotumwa $_countryCode ${_phoneController.text}',
                      )
                    : app.t(
                        'Sign in with your phone number to continue',
                        'Ingia kwa nambari ya simu kuendelea',
                      ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 36),
              if (!_otpSent) ...[
                // Phone input
                Row(
                  children: [
                    GestureDetector(
                      onTap: _showCountryPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? AppColors.darkCard : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(_countryCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          hintText: app.t('Phone number', 'Nambari ya simu'),
                          prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 20),
                // WhatsApp toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.chat_rounded, color: const Color(0xFF25D366), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          app.t('Send OTP via WhatsApp', 'Tuma OTP kupitia WhatsApp'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Switch.adaptive(
                        value: _useWhatsApp,
                        onChanged: (v) => setState(() => _useWhatsApp = v),
                        activeColor: const Color(0xFF25D366),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 350.ms),
                const SizedBox(height: 28),
                LoadingButton(
                  text: app.t('Send OTP', 'Tuma OTP'),
                  isLoading: _loading,
                  onPressed: _sendOtp,
                  icon: Icons.send_rounded,
                ).animate().fadeIn(delay: 450.ms),
              ] else ...[
                // OTP input
                PinCodeTextField(
                  appContext: context,
                  length: 4,
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.scale,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 58,
                    fieldWidth: 58,
                    activeFillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                    inactiveFillColor: isDark ? AppColors.darkSurface : AppColors.lightCard,
                    selectedFillColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
                    activeColor: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
                    inactiveColor: isDark ? AppColors.darkCard : Colors.grey.shade300,
                    selectedColor: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
                  ),
                  enableActiveFill: true,
                  onCompleted: (_) => _verifyOtp(),
                  onChanged: (_) {},
                ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
                const SizedBox(height: 16),
                Center(
                  child: _countdown > 0
                      ? Text(
                          app.t('Resend in $_countdown s', 'Tuma tena baada ya $_countdown s'),
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        )
                      : TextButton(
                          onPressed: () {
                            setState(() {
                              _otpSent = false;
                              _otpController.clear();
                            });
                          },
                          child: Text(app.t('Resend OTP', 'Tuma OTP tena')),
                        ),
                ),
                const SizedBox(height: 24),
                LoadingButton(
                  text: app.t('Verify & Continue', 'Thibitisha & Endelea'),
                  isLoading: _loading,
                  onPressed: _verifyOtp,
                  icon: Icons.check_circle_outline_rounded,
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _otpSent = false;
                    _otpController.clear();
                  }),
                  child: Text(app.t('Change number', 'Badilisha nambari')),
                ),
              ],
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    app.t("Don't have an account? ", 'Huna akaunti? '),
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    child: Text(
                      app.t('Sign Up', 'Jisajili'),
                      style: TextStyle(
                        color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
