import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_button.dart';
import '../../core/constants/location_data.dart';
import '../../models/user_model.dart';
import '../../providers/app_provider.dart';
import '../home/main_shell.dart';
import '../payments/payment_methods_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _loading = false;
  bool _otpSent = false;
  bool _useWhatsApp = false;
  int _countdown = 0;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String _countryCode = '+255';

  String? _island;
  String? _region;
  String? _district;
  String? _ward;

  final List<Map<String, String>> _countries = [
    {'name': 'Tanzania', 'code': '+255', 'flag': '🇹🇿'},
    {'name': 'Kenya', 'code': '+254', 'flag': '🇰🇪'},
    {'name': 'Uganda', 'code': '+256', 'flag': '🇺🇬'},
    {'name': 'Rwanda', 'code': '+250', 'flag': '🇷🇼'},
    {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧'},
    {'name': 'United States', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'India', 'code': '+91', 'flag': '🇮🇳'},
    {'name': 'UAE', 'code': '+971', 'flag': '🇦🇪'},
    {'name': 'Germany', 'code': '+49', 'flag': '🇩🇪'},
    {'name': 'South Africa', 'code': '+27', 'flag': '🇿🇦'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().length < 9) {
      _snack(context.read<AppProvider>().t('Please fill name and phone', 'Jaza jina na nambari ya simu'));
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _otpSent = true;
      _countdown = 60;
    });
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _countdown <= 0) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  Future<void> _verifyAndNext() async {
    if (_otpCtrl.text.length != 4) {
      _snack(context.read<AppProvider>().t('Enter valid OTP', 'Ingiza OTP sahihi'));
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _step = 1;
    });
    _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  Future<void> _completeSignup({bool skipPayment = false}) async {
    if (_island == null || _region == null || _district == null || _ward == null) {
      _snack(context.read<AppProvider>().t('Please select full location', 'Chagua mahali kamili'));
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    final user = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullName: _nameCtrl.text.trim(),
      phone: '$_countryCode${_phoneCtrl.text.trim()}',
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      island: _island!,
      region: _region!,
      district: _district!,
      ward: _ward!,
      walletBalance: 0,
      savedLocations: [
        SavedLocationModel(
          id: 'home',
          label: 'Home',
          address: '$_ward, $_district',
          island: _island!,
          region: _region!,
          district: _district!,
          ward: _ward!,
        ),
      ],
    );
    await context.read<AppProvider>().login(user);
    if (!mounted) return;
    setState(() => _loading = false);

    if (skipPayment) {
      _goHome();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentMethodsScreen(onSkip: _goHome, onComplete: _goHome),
        ),
      );
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (_) => false,
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _showSearchablePicker({
    required String title,
    required List<String> items,
    required ValueChanged<String> onSelect,
  }) {
    final isDark = context.read<AppProvider>().isDark;
    final searchCtrl = TextEditingController();
    List<String> filtered = List.from(items);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, sc) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: searchCtrl,
                            decoration: InputDecoration(
                              hintText: context.read<AppProvider>().t('Search...', 'Tafuta...'),
                              prefixIcon: const Icon(Icons.search),
                            ),
                            onChanged: (q) {
                              setModal(() {
                                filtered = items.where((e) => e.toLowerCase().contains(q.toLowerCase())).toList();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: sc,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => ListTile(
                          title: Text(filtered[i]),
                          onTap: () {
                            onSelect(filtered[i]);
                            Navigator.pop(ctx);
                          },
                        ),
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
      appBar: AppBar(
        title: Text(app.t('Create Account', 'Unda Akaunti')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: List.generate(2, (i) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? (isDark ? AppColors.aquaGreen : AppColors.oceanTeal)
                          : (isDark ? AppColors.darkCard : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPersonalStep(app, isDark),
                _buildLocationStep(app, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalStep(AppProvider app, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(app.t('Personal Details', 'Taarifa Binafsi'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: app.t('Full Name', 'Jina Kamili'),
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final searchCtrl = TextEditingController();
                  List<Map<String, String>> filtered = List.from(_countries);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx, setModal) => DraggableScrollableSheet(
                        initialChildSize: 0.6,
                        expand: false,
                        builder: (_, sc) => Column(
                          children: [
                            const SizedBox(height: 12),
                            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: TextField(
                                controller: searchCtrl,
                                decoration: InputDecoration(hintText: app.t('Search country', 'Tafuta nchi'), prefixIcon: const Icon(Icons.search)),
                                onChanged: (q) => setModal(() {
                                  filtered = _countries.where((c) => c['name']!.toLowerCase().contains(q.toLowerCase()) || c['code']!.contains(q)).toList();
                                }),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                controller: sc,
                                itemCount: filtered.length,
                                itemBuilder: (_, i) => ListTile(
                                  leading: Text(filtered[i]['flag']!, style: const TextStyle(fontSize: 24)),
                                  title: Text(filtered[i]['name']!),
                                  trailing: Text(filtered[i]['code']!),
                                  onTap: () {
                                    setState(() => _countryCode = filtered[i]['code']!);
                                    Navigator.pop(ctx);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(_countryCode, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: app.t('Phone', 'Simu'),
                    prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: app.t('Email (Optional)', 'Barua pepe (Si lazima)'),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          if (!_otpSent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(app.t('OTP via WhatsApp', 'OTP kupitia WhatsApp'), style: const TextStyle(fontSize: 13))),
                  Switch.adaptive(value: _useWhatsApp, onChanged: (v) => setState(() => _useWhatsApp = v), activeColor: const Color(0xFF25D366)),
                ],
              ),
            ),
          if (_otpSent) ...[
            const SizedBox(height: 20),
            Text(app.t('Enter OTP', 'Ingiza OTP'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            PinCodeTextField(
              appContext: context,
              length: 4,
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(12),
                fieldHeight: 54,
                fieldWidth: 54,
                activeFillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                inactiveFillColor: isDark ? AppColors.darkSurface : AppColors.lightCard,
                selectedFillColor: isDark ? AppColors.darkCard : Colors.white,
                activeColor: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
                inactiveColor: isDark ? AppColors.darkCard : Colors.grey.shade300,
                selectedColor: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
              ),
              enableActiveFill: true,
              onChanged: (_) {},
            ),
            if (_countdown > 0)
              Text(app.t('Resend in $_countdown s', 'Tuma tena baada ya $_countdown s'),
                  style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 28),
          LoadingButton(
            text: _otpSent ? app.t('Verify & Continue', 'Thibitisha & Endelea') : app.t('Send OTP', 'Tuma OTP'),
            isLoading: _loading,
            onPressed: _otpSent ? _verifyAndNext : _sendOtp,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep(AppProvider app, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(app.t('Your Location', 'Mahali Pako'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            app.t('Help us serve you better in Zanzibar', 'Tusaidie kukuhudumia vizuri Zanzibar'),
            style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
          const SizedBox(height: 24),
          _locationField(app.t('Island', 'Kisiwa'), _island, () => _showSearchablePicker(
            title: app.t('Select Island', 'Chagua Kisiwa'),
            items: LocationData.islands,
            onSelect: (v) => setState(() { _island = v; _region = null; _district = null; _ward = null; }),
          ), isDark),
          const SizedBox(height: 14),
          _locationField(app.t('Region', 'Mkoa'), _region, _island == null ? null : () => _showSearchablePicker(
            title: app.t('Select Region', 'Chagua Mkoa'),
            items: LocationData.regions[_island!] ?? [],
            onSelect: (v) => setState(() { _region = v; _district = null; _ward = null; }),
          ), isDark),
          const SizedBox(height: 14),
          _locationField(app.t('District', 'Wilaya'), _district, _region == null ? null : () => _showSearchablePicker(
            title: app.t('Select District', 'Chagua Wilaya'),
            items: LocationData.districts[_region!] ?? [],
            onSelect: (v) => setState(() { _district = v; _ward = null; }),
          ), isDark),
          const SizedBox(height: 14),
          _locationField(app.t('Ward (Shehia)', 'Kata (Shehia)'), _ward, _district == null ? null : () => _showSearchablePicker(
            title: app.t('Select Ward', 'Chagua Kata'),
            items: LocationData.wards[_district!] ?? LocationData.getAllWards(),
            onSelect: (v) => setState(() => _ward = v),
          ), isDark),
          const SizedBox(height: 32),
          LoadingButton(
            text: app.t('Continue to Payments', 'Endelea kwa Malipo'),
            isLoading: _loading,
            onPressed: () => _completeSignup(skipPayment: false),
            icon: Icons.payment_rounded,
          ),
          const SizedBox(height: 12),
          LoadingButton(
            text: app.t('Skip for now', 'Ruka kwa sasa'),
            isOutlined: true,
            onPressed: () => _completeSignup(skipPayment: true),
          ),
        ],
      ),
    );
  }

  Widget _locationField(String label, String? value, VoidCallback? onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkCard : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    value ?? context.read<AppProvider>().t('Select', 'Chagua'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
                      color: value != null
                          ? (isDark ? AppColors.offWhite : AppColors.charcoal)
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ],
        ),
      ),
    );
  }
}
