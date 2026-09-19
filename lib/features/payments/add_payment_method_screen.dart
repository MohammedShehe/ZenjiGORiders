import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_button.dart';
import '../../models/user_model.dart';
import '../../providers/app_provider.dart';

class AddPaymentMethodScreen extends StatefulWidget {
  const AddPaymentMethodScreen({super.key});

  @override
  State<AddPaymentMethodScreen> createState() => _AddPaymentMethodScreenState();
}

class _AddPaymentMethodScreenState extends State<AddPaymentMethodScreen> {
  String _type = 'momo';
  String? _provider;
  bool _makeDefault = true;
  bool _loading = false;

  final _phoneCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _holderCtrl.dispose();
    _cardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  bool _validPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^(255|0)?(6|7|8)[0-9]{8}').hasMatch(digits);
  }

  bool _validCard(String value) => value.replaceAll(' ', '').length == 16;

  Future<void> _save() async {
    final app = context.read<AppProvider>();
    if (_type == 'momo') {
      if (_provider == null || !_validPhone(_phoneCtrl.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(app.t('Choose a provider and enter a valid Tanzania mobile number.', 'Chagua mtandao na ingiza namba sahihi ya Tanzania.'))),
        );
        return;
      }
    } else {
      if (_holderCtrl.text.trim().length < 2 ||
          !_validCard(_cardCtrl.text) ||
          !RegExp(r'^\d{2}/\d{2}$').hasMatch(_expiryCtrl.text.trim()) ||
          !RegExp(r'^\d{3,4}$').hasMatch(_cvvCtrl.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(app.t('Complete the card details correctly.', 'Jaza taarifa za kadi kwa usahihi.'))),
        );
        return;
      }
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final method = PaymentMethodModel(
      id: id,
      type: _type,
      provider: _type == 'momo' ? _provider : 'Bank Card',
      accountNumber: _type == 'momo' ? _phoneCtrl.text.trim() : null,
      cardLast4: _type == 'bank' ? _cardCtrl.text.replaceAll(' ', '').substring(12) : null,
      expiry: _type == 'bank' ? _expiryCtrl.text.trim() : null,
      isDefault: _makeDefault,
    );
    app.addPaymentMethod(method);
    setState(() => _loading = false);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.brightGreen),
            const SizedBox(width: 10),
            Text(app.t('Payment method added', 'Njia ya malipo imeongezwa')),
          ],
        ),
        content: Text(app.t(
          'Your payment method is ready to use for rides and wallet top-ups.',
          'Njia yako ya malipo iko tayari kwa safari na kuongeza salio la pochi.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(app.t('Done', 'Maliza'))),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, method);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = app.isDark;
    final accent = dark ? AppColors.aquaGreen : AppColors.oceanTeal;

    return Scaffold(
      appBar: AppBar(title: Text(app.t('Add payment method', 'Ongeza njia ya malipo'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accent.withOpacity(.18), AppColors.skyBlue.withOpacity(.10)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: accent.withOpacity(.18), child: Icon(Icons.shield_rounded, color: accent)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(app.t('Secure payment setup. Your details stay attached to your rider account.', 'Usanidi salama wa malipo. Taarifa zako zitaunganishwa na akaunti yako.'), style: const TextStyle(fontSize: 13, height: 1.35))),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(app.t('Choose method', 'Chagua njia'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _methodCard('momo', Icons.phone_android_rounded, app.t('Mobile Money', 'Pesa ya simu'), accent)),
                  const SizedBox(width: 12),
                  Expanded(child: _methodCard('bank', Icons.credit_card_rounded, app.t('Bank Card', 'Kadi ya benki'), accent)),
                ],
              ),
              const SizedBox(height: 22),
              if (_type == 'momo') ...[
                Text(app.t('Mobile network', 'Mtandao wa simu'), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _provider,
                  decoration: InputDecoration(labelText: app.t('Select provider', 'Chagua mtandao')),
                  items: const [
                    DropdownMenuItem(value: 'M-Pesa', child: Text('M-Pesa')),
                    DropdownMenuItem(value: 'Mix by Yas', child: Text('Mix by Yas')),
                    DropdownMenuItem(value: 'Airtel Money', child: Text('Airtel Money')),
                    DropdownMenuItem(value: 'HaloPesa', child: Text('HaloPesa')),
                  ],
                  onChanged: (v) => setState(() => _provider = v),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: app.t('Mobile number', 'Namba ya simu'), prefixText: '+255 '),
                ),
                const SizedBox(height: 8),
                Text(app.t('Use the number registered with the selected mobile-money service.', 'Tumia namba iliyosajiliwa kwenye huduma uliyochagua.'), style: TextStyle(fontSize: 12, color: dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
              ] else ...[
                TextField(controller: _holderCtrl, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: app.t('Card holder name', 'Jina la mwenye kadi'))),
                const SizedBox(height: 14),
                TextField(controller: _cardCtrl, keyboardType: TextInputType.number, maxLength: 19, decoration: InputDecoration(labelText: app.t('Card number', 'Namba ya kadi'), counterText: ''), onChanged: (v) => setState(() {})),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: TextField(controller: _expiryCtrl, keyboardType: TextInputType.number, maxLength: 5, decoration: const InputDecoration(labelText: 'Expiry (MM/YY)', counterText: ''))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _cvvCtrl, keyboardType: TextInputType.number, obscureText: true, maxLength: 4, decoration: const InputDecoration(labelText: 'CVV', counterText: ''))),
                ]),
              ],
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _makeDefault,
                activeColor: accent,
                title: Text(app.t('Make default payment method', 'Fanya iwe njia ya malipo ya msingi')),
                subtitle: Text(app.t('Use it automatically when booking a ride.', 'Itatumika moja kwa moja wakati wa kuomba safari.')),
                onChanged: (v) => setState(() => _makeDefault = v),
              ),
              const SizedBox(height: 18),
              LoadingButton(text: app.t('Save payment method', 'Hifadhi njia ya malipo'), icon: Icons.lock_rounded, isLoading: _loading, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodCard(String type, IconData icon, String label, Color accent) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(.12) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? accent : Colors.transparent, width: 1.5),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? accent : null, size: 30),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
