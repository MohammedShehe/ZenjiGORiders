import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_button.dart';
import '../../models/user_model.dart';
import '../../providers/app_provider.dart';
import '../payments/add_payment_method_screen.dart';

class WalletSetupScreen extends StatefulWidget {
  const WalletSetupScreen({super.key});

  @override
  State<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends State<WalletSetupScreen> {
  double _amount = 5000;
  String? _selectedMethodId;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final methods = app.user?.paymentMethods ?? const <PaymentMethodModel>[];
    final accent = app.isDark ? AppColors.aquaGreen : AppColors.oceanTeal;
    final selected = methods.where((m) => m.id == _selectedMethodId).cast<PaymentMethodModel?>().firstOrNull ??
        (methods.where((m) => m.isDefault).isNotEmpty ? methods.firstWhere((m) => m.isDefault) : null);

    return Scaffold(
      appBar: AppBar(title: Text(app.t('Top up wallet', 'Ongeza salio la pochi'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _balanceCard(app),
            const SizedBox(height: 22),
            Text(app.t('Choose amount', 'Chagua kiasi'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                Text('TZS ${_amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                Slider(min: 500, max: 100000, divisions: 199, value: _amount, activeColor: accent, onChanged: (v) => setState(() => _amount = v.roundToDouble())),
                Wrap(spacing: 8, runSpacing: 8, children: [1000, 5000, 10000, 20000, 50000].map((v) => ChoiceChip(label: Text('TZS $v'), selected: _amount == v.toDouble(), onSelected: (_) => setState(() => _amount = v.toDouble()))).toList()),
              ]),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: Text(app.t('Pay using', 'Lipa kwa kutumia'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              TextButton.icon(onPressed: _addPayment, icon: const Icon(Icons.add, size: 18), label: Text(app.t('Add', 'Ongeza'))),
            ]),
            const SizedBox(height: 8),
            if (methods.isEmpty)
              _noMethod(app, accent)
            else ...methods.map((m) => _paymentChoice(m, selected?.id == m.id, accent)),
            const SizedBox(height: 20),
            if (selected != null) _summary(app, selected),
            const SizedBox(height: 16),
            LoadingButton(text: app.t('Confirm secure top-up', 'Thibitisha kuongeza salio'), icon: Icons.lock_rounded, isLoading: _loading, onPressed: selected == null ? _addPayment : _topUp),
          ]),
        ),
      ),
    );
  }

  Widget _balanceCard(AppProvider app) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: app.isDark ? [AppColors.darkCard, AppColors.darkSurface] : [AppColors.deepNavy, AppColors.oceanTeal]),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(children: [
      const CircleAvatar(radius: 24, backgroundColor: Colors.white24, child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(app.t('Current wallet balance', 'Salio la pochi sasa'), style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text('TZS ${app.walletBalance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
      ])),
    ]),
  );

  Widget _noMethod(AppProvider app, Color accent) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: accent.withOpacity(.08), borderRadius: BorderRadius.circular(18)),
    child: Row(children: [Icon(Icons.info_outline, color: accent), const SizedBox(width: 10), Expanded(child: Text(app.t('Add a mobile-money account or bank card before topping up.', 'Ongeza akaunti ya pesa ya simu au kadi ya benki kabla ya kuongeza salio.')))]),
  );

  Widget _paymentChoice(PaymentMethodModel method, bool selected, Color accent) {
    final isCard = method.type == 'bank';
    return GestureDetector(
      onTap: () => setState(() => _selectedMethodId = method.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? accent : Colors.transparent, width: 1.5)),
        child: Row(children: [
          Icon(isCard ? Icons.credit_card_rounded : Icons.phone_android_rounded, color: selected ? accent : null),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isCard ? 'Bank Card' : (method.provider ?? 'Mobile Money'), style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(isCard ? '•••• ${method.cardLast4 ?? ''}' : (method.accountNumber ?? ''), style: const TextStyle(fontSize: 12))])),
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? accent : Colors.grey),
        ]),
      ),
    );
  }

  Widget _summary(AppProvider app, PaymentMethodModel method) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      _row(app.t('Top-up amount', 'Kiasi'), 'TZS ${_amount.toStringAsFixed(0)}'),
      const Divider(height: 20),
      _row(app.t('New balance', 'Salio jipya'), 'TZS ${(app.walletBalance + _amount).toStringAsFixed(0)}', bold: true),
      const SizedBox(height: 6),
      Align(alignment: Alignment.centerLeft, child: Text(app.t('Payment: ${method.provider ?? 'Bank Card'}', 'Malipo: ${method.provider ?? 'Kadi ya benki'}'), style: TextStyle(fontSize: 12, color: app.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))),
    ]),
  );

  Widget _row(String label, String value, {bool bold = false}) => Row(children: [Expanded(child: Text(label)), Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600))]);

  Future<void> _addPayment() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPaymentMethodScreen()));
    if (!mounted) return;
    final app = context.read<AppProvider>();
    final methods = app.user?.paymentMethods ?? const <PaymentMethodModel>[];
    if (methods.isNotEmpty) setState(() => _selectedMethodId = methods.last.id);
  }

  Future<void> _topUp() async {
    final app = context.read<AppProvider>();
    final methods = app.user?.paymentMethods ?? const <PaymentMethodModel>[];
    PaymentMethodModel? method;
    for (final m in methods) {
      if (m.id == _selectedMethodId) method = m;
    }
    method ??= methods.where((m) => m.isDefault).isNotEmpty ? methods.firstWhere((m) => m.isDefault) : null;
    if (method == null) return;

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    app.topUpWallet(amount: _amount, paymentMethod: method.type, provider: method.provider);
    setState(() => _loading = false);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Column(children: [Icon(Icons.check_circle_rounded, color: AppColors.brightGreen, size: 56), SizedBox(height: 8), Text('Top-up successful')]),
        content: Text(app.t('TZS ${_amount.toStringAsFixed(0)} has been added to your ZenjiGO Wallet.', 'TZS ${_amount.toStringAsFixed(0)} imeongezwa kwenye ZenjiGO Wallet yako.'), textAlign: TextAlign.center),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(app.t('Done', 'Maliza')))],
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
