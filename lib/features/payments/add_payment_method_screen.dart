import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/credit_card_preview.dart';
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
  final _cvvFocus = FocusNode();

  bool _flipped = false; // card showing its CVV side
  bool _submitted = false; // show field errors after the first save attempt

  @override
  void initState() {
    super.initState();
    // Every keystroke rebuilds the screen, which redraws the live card preview.
    for (final c in [_holderCtrl, _cardCtrl, _expiryCtrl, _cvvCtrl]) {
      c.addListener(_refresh);
    }
    _cvvFocus.addListener(() {
      if (mounted) setState(() => _flipped = _cvvFocus.hasFocus);
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_holderCtrl, _cardCtrl, _expiryCtrl, _cvvCtrl]) {
      c.removeListener(_refresh);
    }
    _phoneCtrl.dispose();
    _holderCtrl.dispose();
    _cardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  String get _cardDigits => _cardCtrl.text.replaceAll(RegExp(r'\D'), '');
  CardBrand get _brand => detectCardBrand(_cardDigits);

  bool _validPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^(255|0)?(6|7|8)[0-9]{8}').hasMatch(digits);
  }

  String? _holderError(AppProvider app) => _holderCtrl.text.trim().length < 2
      ? app.t('Enter the name as shown on the card', 'Weka jina kama lilivyo kwenye kadi')
      : null;

  String? _numberError(AppProvider app) => _cardDigits.length != _brand.numberLength
      ? app.t('Enter all ${_brand.numberLength} digits', 'Weka tarakimu zote ${_brand.numberLength}')
      : null;

  String? _expiryError(AppProvider app) {
    final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(_expiryCtrl.text);
    if (m == null) return app.t('Use MM/YY', 'Tumia MM/YY');
    final month = int.parse(m.group(1)!);
    final year = 2000 + int.parse(m.group(2)!);
    final now = DateTime.now();
    if (month < 1 || month > 12) return app.t('Invalid month', 'Mwezi si sahihi');
    if (year < now.year || (year == now.year && month < now.month)) {
      return app.t('This card has expired', 'Kadi hii imeisha muda');
    }
    return null;
  }

  String? _cvvError(AppProvider app) => _cvvCtrl.text.length != _brand.cvvLength
      ? app.t('${_brand.cvvLength} digits', 'Tarakimu ${_brand.cvvLength}')
      : null;

  bool _cardFormValid(AppProvider app) =>
      _holderError(app) == null && _numberError(app) == null && _expiryError(app) == null && _cvvError(app) == null;

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
      if (!_cardFormValid(app)) {
        setState(() => _submitted = true);
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
      provider: _type == 'momo' ? _provider : _brand.label,
      accountNumber: _type == 'momo' ? _phoneCtrl.text.trim() : null,
      cardLast4: _type == 'bank' ? _cardDigits.substring(_cardDigits.length - 4) : null,
      expiry: _type == 'bank' ? _expiryCtrl.text.trim() : null,
      cardHolder: _type == 'bank' ? _holderCtrl.text.trim() : null,
      cardBrand: _type == 'bank' ? _brand.name : null,
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.brightGreen),
            const SizedBox(height: 10),
            Text(
              app.t('Payment method added', 'Njia ya malipo imeongezwa'),
              softWrap: true,
            ),
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
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(title: Text(app.t('Add payment method', 'Ongeza njia ya malipo'))),
      body: SafeArea(
        child: Column(
          children: [
            if (_type == 'bank') _previewHeader(keyboardOpen),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                Text(app.t('Tap the card to flip it. Your details update on it as you type.', 'Gusa kadi ili kuigeuza. Taarifa zako zinaonekana kwenye kadi unapoandika.'), style: TextStyle(fontSize: 12, color: dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                const SizedBox(height: 14),
                TextField(
                  controller: _holderCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  inputFormatters: cardHolderFormatters,
                  decoration: InputDecoration(
                    labelText: app.t('Card holder name', 'Jina la mwenye kadi'),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    errorText: _submitted ? _holderError(app) : null,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _cardCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [CardNumberInputFormatter()],
                  decoration: InputDecoration(
                    labelText: app.t('Card number', 'Namba ya kadi'),
                    prefixIcon: const Icon(Icons.credit_card_rounded),
                    suffixText: _brand == CardBrand.unknown ? null : _brand.label,
                    errorText: _submitted ? _numberError(app) : null,
                  ),
                ),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextField(
                      controller: _expiryCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: 5,
                      inputFormatters: [ExpiryInputFormatter()],
                      decoration: InputDecoration(
                        labelText: app.t('Expiry (MM/YY)', 'Mwisho (MM/YY)'),
                        counterText: '',
                        errorText: _submitted ? _expiryError(app) : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cvvCtrl,
                      focusNode: _cvvFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: _brand.cvvLength,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        counterText: '',
                        errorText: _submitted ? _cvvError(app) : null,
                      ),
                    ),
                  ),
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
          ],
        ),
      ),
    );
  }

  /// Live card mockup pinned above the form so it stays visible while typing.
  /// It shrinks while the keyboard is open to leave room for the fields.
  Widget _previewHeader(bool keyboardOpen) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: keyboardOpen ? 230 : 350),
            child: CreditCardPreview(
              holder: _holderCtrl.text,
              number: _cardCtrl.text,
              expiry: _expiryCtrl.text,
              cvv: _cvvCtrl.text,
              brand: _brand,
              showBack: _flipped,
              onTap: () => setState(() => _flipped = !_flipped),
            ),
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
