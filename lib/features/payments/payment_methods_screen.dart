import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_button.dart';
import '../../models/user_model.dart';
import '../../providers/app_provider.dart';
import 'add_payment_method_screen.dart';
import '../wallet/wallet_setup_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  final VoidCallback? onSkip;
  final VoidCallback? onComplete;
  const PaymentMethodsScreen({super.key, this.onSkip, this.onComplete});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  bool _busy = false;

  Future<void> _add() async {
    final method = await Navigator.push<PaymentMethodModel>(context, MaterialPageRoute(builder: (_) => const AddPaymentMethodScreen()));
    if (method != null && mounted) setState(() {});
  }

  Future<void> _remove(PaymentMethodModel method) async {
    final app = context.read<AppProvider>();
    final methods = app.user?.paymentMethods ?? const <PaymentMethodModel>[];
    if (methods.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.t('Keep at least one payment method. Cash remains available for rides.', 'Weka angalau njia moja ya malipo. Fedha taslimu bado inapatikana kwa safari.'))));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(app.t('Remove payment method?', 'Ondoa njia ya malipo?')),
        content: Text(app.t('You will no longer be able to use this method for rides or wallet top-ups.', 'Hutaweza kutumia njia hii kwa safari au kuongeza salio la pochi.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(app.t('Cancel', 'Ghairi'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(app.t('Remove', 'Ondoa'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    app.removePaymentMethod(method.id);
  }

  Future<void> _setDefault(PaymentMethodModel method) async {
    final app = context.read<AppProvider>();
    if (method.isDefault) return;
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    app.setDefaultPaymentMethod(method.id);
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final methods = app.user?.paymentMethods ?? const <PaymentMethodModel>[];
    final accent = app.isDark ? AppColors.aquaGreen : AppColors.oceanTeal;

    return Scaffold(
      appBar: AppBar(
        title: Text(app.t('Payment methods', 'Njia za malipo')),
        actions: [IconButton(onPressed: _busy ? null : _add, icon: const Icon(Icons.add_card_rounded))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: accent.withOpacity(.10), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Icon(Icons.verified_user_rounded, color: accent),
              const SizedBox(width: 12),
              Expanded(child: Text(app.t('Add and manage the payment methods you trust. Your default method is highlighted and can be changed anytime.', 'Ongeza na simamia njia zako za malipo. Njia ya msingi imeonyeshwa na unaweza kuibadilisha wakati wowote.'), style: const TextStyle(fontSize: 13, height: 1.35))),
            ]),
          ),
          const SizedBox(height: 22),
          if (methods.isEmpty)
            _empty(app, accent)
          else ...[
            ...methods.map((method) => _methodTile(method, accent)),
          ],
          const SizedBox(height: 12),
          LoadingButton(text: app.t('Add payment method', 'Ongeza njia ya malipo'), icon: Icons.add_rounded, isLoading: _busy, onPressed: _add),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletSetupScreen())),
            icon: const Icon(Icons.account_balance_wallet_rounded),
            label: Text(app.t('Top up ZenjiGO Wallet', 'Ongeza salio la ZenjiGO Wallet')),
          ),
        ],
      ),
    );
  }

  Widget _empty(AppProvider app, Color accent) => Container(
    padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
    child: Column(children: [
      Icon(Icons.payments_outlined, size: 56, color: accent),
      const SizedBox(height: 12),
      Text(app.t('No saved payment methods', 'Hakuna njia za malipo zilizohifadhiwa'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      const SizedBox(height: 6),
      Text(app.t('Add mobile money or a bank card to make booking and wallet top-ups faster.', 'Ongeza pesa ya simu au kadi ya benki ili kurahisisha safari na kuongeza salio.'), textAlign: TextAlign.center),
    ]),
  );

  Widget _methodTile(PaymentMethodModel method, Color accent) {
    final app = context.read<AppProvider>();
    final isCard = method.type == 'bank';
    final title = isCard ? app.t('Bank Card', 'Kadi ya benki') : (method.provider ?? 'Mobile Money');
    final subtitle = isCard ? '•••• ${method.cardLast4 ?? '----'}${method.expiry != null ? '  ·  ${method.expiry}' : ''}' : (method.accountNumber ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: accent.withOpacity(.12), borderRadius: BorderRadius.circular(14)), child: Icon(isCard ? Icons.credit_card_rounded : Icons.phone_android_rounded, color: accent)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))), if (method.isDefault) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.brightGreen.withOpacity(.12), borderRadius: BorderRadius.circular(20)), child: const Text('DEFAULT', style: TextStyle(color: AppColors.brightGreen, fontSize: 9, fontWeight: FontWeight.w800))) ]),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: app.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          ])),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'default') _setDefault(method);
              if (value == 'remove') _remove(method);
            },
            itemBuilder: (_) => [
              if (!method.isDefault) PopupMenuItem(value: 'default', child: Text(app.t('Make default', 'Fanya msingi'))),
              PopupMenuItem(value: 'remove', child: Text(app.t('Remove', 'Ondoa'))),
            ],
          ),
        ]),
      ),
    );
  }
}
