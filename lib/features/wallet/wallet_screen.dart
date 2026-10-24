import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../providers/app_provider.dart';
import '../payments/payment_methods_screen.dart';
import 'wallet_setup_screen.dart';
import 'transaction_history_screen.dart';
import 'referral_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  /// Balance hidden by default for privacy.
  bool _hideBalance = true;
  final List<int> _quickAmounts = const [2000, 5000, 10000, 20000, 50000];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppProvider>().refreshWallet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = app.isDark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZenjiGO Wallet'),
        actions: [
          IconButton(
            tooltip: _hideBalance ? 'Show balance' : 'Hide balance',
            onPressed: () => setState(() => _hideBalance = !_hideBalance),
            icon: Icon(_hideBalance ? Icons.visibility_off : Icons.visibility),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppProvider>().refreshWallet(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dark
                        ? [AppColors.darkCard, AppColors.aquaGreen.withValues(alpha: .3)]
                        : [AppColors.deepNavy, AppColors.oceanTeal],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text('Available Balance', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _hideBalance ? '••••••' : formatTzs(app.walletBalance),
                        key: ValueKey(_hideBalance),
                        style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const WalletSetupScreen()),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Top Up'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
                            ),
                            icon: const Icon(Icons.history, color: Colors.white),
                            label: const Text('History', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Quick Top Up',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: dark ? Colors.white : AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _quickAmounts.map((amt) {
                  return ActionChip(
                    label: Text(formatTzs(amt)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WalletSetupScreen(initialAmount: amt.toDouble()),
                        ),
                      );
                    },
                    backgroundColor: dark ? AppColors.darkCard : AppColors.lightCard,
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              _tile(context, Icons.payment, 'Payment Methods', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()));
              }, dark),
              _tile(context, Icons.receipt_long, 'Transaction History', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()));
              }, dark),
              _tile(context, Icons.card_giftcard, 'Refer & Earn', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralScreen()));
              }, dark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, VoidCallback action, bool dark) {
    return Card(
      child: ListTile(
        onTap: action,
        leading: Icon(icon, color: dark ? AppColors.aquaGreen : AppColors.oceanTeal),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
