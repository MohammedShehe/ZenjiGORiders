import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/app_provider.dart';
import '../wallet/wallet_setup_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  final VoidCallback? onSkip;
  final VoidCallback? onComplete;
  const PaymentMethodsScreen({super.key, this.onSkip, this.onComplete});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  Future<void> _remove(PaymentMethodModel method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove payment method?'),
        content: const Text('This payment method will be removed from your ZenjiGO account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<AppProvider>().removePaymentMethod(method.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment method removed.')));
    }
  }

  Future<void> _addMethod() async {
    String type = 'momo';
    final provider = TextEditingController();
    final value = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Add Payment Method'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Method'),
                    items: const [
                      DropdownMenuItem(value: 'momo', child: Text('Mobile Money')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank Card')),
                    ],
                    onChanged: (v) => setDialogState(() => type = v ?? 'momo'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: provider,
                    decoration: InputDecoration(
                      labelText: type == 'bank' ? 'Card holder' : 'Provider',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: value,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: type == 'bank' ? 'Last 4 card digits' : 'Phone / account number',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (value.text.trim().isEmpty) return;
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );
      if (confirmed == true && mounted) {
        final text = value.text.trim();
        context.read<AppProvider>().addPaymentMethod(
          PaymentMethodModel(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: type,
            provider: provider.text.trim().isEmpty ? (type == 'bank' ? 'Bank Card' : 'Mobile Money') : provider.text.trim(),
            accountNumber: type == 'bank' ? null : text,
            cardLast4: type == 'bank' ? text : null,
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment method added.')));
      }
    } finally {
      provider.dispose();
      value.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = context.watch<AppProvider>().user?.paymentMethods ?? const <PaymentMethodModel>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
        actions: [IconButton(onPressed: _addMethod, icon: const Icon(Icons.add))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (methods.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
              child: Column(
                children: [
                  Icon(Icons.payment_outlined, size: 64),
                  SizedBox(height: 12),
                  Text('No saved payment methods'),
                  SizedBox(height: 4),
                  Text('Add mobile money or a bank card to pay faster.'),
                ],
              ),
            )
          else
            ...methods.map(
              (method) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(method.type == 'bank' ? Icons.credit_card : Icons.phone_android),
                  ),
                  title: Text(method.type == 'bank' ? 'Bank Card' : (method.provider ?? 'Mobile Money')),
                  subtitle: Text(method.type == 'bank' ? '•••• ${method.cardLast4 ?? ''}' : (method.accountNumber ?? '')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(method),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: _addMethod, icon: const Icon(Icons.add), label: const Text('Add Payment Method')),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              if (widget.onComplete != null) {
                widget.onComplete!();
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Done'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletSetupScreen())),
            child: const Text('Top up ZenjiGO Wallet'),
          ),
        ],
      ),
    );
  }
}
