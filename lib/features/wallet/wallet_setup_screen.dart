import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/loading_button.dart';
import '../../providers/app_provider.dart';

class WalletSetupScreen extends StatefulWidget {
  const WalletSetupScreen({super.key});

  @override
  State<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends State<WalletSetupScreen> {
  double _amount = 5000;
  String? _source;
  bool _loading = false;
  final _amountCtrl = TextEditingController(text: '5000');

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _adjust(int delta) {
    setState(() {
      _amount = (_amount + delta).clamp(500, 500000);
      _amountCtrl.text = _amount.toStringAsFixed(0);
    });
  }

  Future<void> _topUp() async {
    if (_source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<AppProvider>().t('Select payment source', 'Chagua chanzo cha malipo'))),
      );
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final app = context.read<AppProvider>();
    app.topUpWallet(amount: _amount, paymentMethod: 'momo', provider: _source);
    setState(() => _loading = false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: AppColors.brightGreen, size: 56),
        content: Text(
          context.read<AppProvider>().t(
                'Successfully topped up TZS ${_amount.toStringAsFixed(0)}!',
                'Umefanikiwa kuongeza TZS ${_amount.toStringAsFixed(0)}!',
              ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(context.read<AppProvider>().t('Done', 'Tayari')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;

    return Scaffold(
      appBar: AppBar(title: Text(app.t('Top Up Wallet', 'Ongeza Pochi'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(app.t('Enter Amount', 'Ingiza Kiasi'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            // Slider style amount
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => _adjust(-500),
                        icon: const Icon(Icons.remove_circle_outline, size: 36),
                        color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'TZS ${_amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      ).animate(key: ValueKey(_amount)).fadeIn(duration: 200.ms).scale(begin: const Offset(0.95, 0.95)),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () => _adjust(500),
                        icon: const Icon(Icons.add_circle_outline, size: 36),
                        color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _amount,
                    min: 500,
                    max: 100000,
                    divisions: 199,
                    activeColor: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
                    onChanged: (v) => setState(() {
                      _amount = v;
                      _amountCtrl.text = v.toStringAsFixed(0);
                    }),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [1000, 5000, 10000, 20000, 50000].map((a) {
                      return ActionChip(
                        label: Text('$a'),
                        onPressed: () => setState(() {
                          _amount = a.toDouble();
                          _amountCtrl.text = a.toString();
                        }),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1, end: 0),
            const SizedBox(height: 28),
            Text(app.t('Pay From', 'Lipa Kutoka'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...AppConstants.mobileProviders.map((p) {
              final selected = _source == p['id'];
              return GestureDetector(
                onTap: () => setState(() => _source = p['id'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: selected ? Border.all(color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal, width: 1.5) : null,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 18, child: Text(p['name']![0], style: const TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(p['name']!, style: const TextStyle(fontWeight: FontWeight.w500))),
                      if (selected) Icon(Icons.check_circle, color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 28),
            LoadingButton(
              text: app.t('Confirm Top Up', 'Thibitisha Ongezo'),
              isLoading: _loading,
              onPressed: _topUp,
              icon: Icons.check_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
