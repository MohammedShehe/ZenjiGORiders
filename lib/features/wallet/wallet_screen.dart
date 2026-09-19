import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_provider.dart';
import '../payments/payment_methods_screen.dart';
import 'wallet_setup_screen.dart';
import 'transaction_history_screen.dart';
import 'referral_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool hide = false;
  double amount = 5000;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = app.isDark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZenjiGO Wallet'),
        actions: [
          IconButton(
            onPressed: () => setState(() => hide = !hide),
            icon: Icon(hide ? Icons.visibility_off : Icons.visibility),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
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
                  Text(
                    hide ? '••••••' : 'TZS ${app.walletBalance.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletSetupScreen())),
                          icon: const Icon(Icons.add),
                          label: const Text('Top Up'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())),
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
            GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() => amount = (amount - details.delta.dy * 100).clamp(500, 100000));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const Text('Quick Top Up · swipe up/down', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('TZS ${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        app.topUpWallet(amount: amount, paymentMethod: 'momo', provider: 'Quick Top-up');
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.t('TZS ${amount.toStringAsFixed(0)} added to your wallet.', 'TZS ${amount.toStringAsFixed(0)} imeongezwa kwenye pochi.'))));
                      },
                      child: const Text('Top Up Now'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _tile(context, Icons.payment, 'Payment Methods', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())), dark),
            _tile(context, Icons.receipt_long, 'Transaction History', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())), dark),
            _tile(context, Icons.card_giftcard, 'Refer & Earn', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferralScreen())), dark),
          ],
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
