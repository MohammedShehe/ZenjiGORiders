import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/credit_card_preview.dart';
import '../../core/widgets/loading_button.dart';
import '../../models/user_model.dart';
import '../../providers/app_provider.dart';
import '../../core/api/rider_api.dart';

enum _Stage { form, waiting, success, failed, timedOut }

/// Wallet top-up.
///
/// Mobile money : phone -> USSD prompt -> wallet credited when the provider webhook confirms.
/// Card / bank  : card form with LIVE preview -> secure bank checkout (3-D Secure / OTP)
///                -> wallet credited when the provider webhook confirms.
/// The card number and CVV are used only for the on-screen preview and validation. They are
/// never sent to the ZenjiGO API (PCI-DSS) - the app only sends brand, last 4 and holder name.
class WalletSetupScreen extends StatefulWidget {
  final double? initialAmount;
  const WalletSetupScreen({super.key, this.initialAmount});

  @override
  State<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends State<WalletSetupScreen> {
  double _amount = 5000;
  String _method = 'momo'; // momo | card
  _Stage _stage = _Stage.form;
  bool _loading = false;
  bool _stopPolling = false;

  // mobile money
  final _phoneCtrl = TextEditingController();
  bool _phoneTouched = false;

  // card
  String? _savedCardId; // null => enter a new card
  bool _saveCard = true;
  bool _flipped = false;
  bool _submitted = false;
  final _holderCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _cvvFocus = FocusNode();

  // in-flight payment
  String? _paymentId;
  String? _checkoutUrl;
  String _resultMessage = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAmount;
    if (initial != null) _amount = initial.clamp(500, 100000).toDouble();
    for (final c in [_holderCtrl, _cardCtrl, _expiryCtrl, _cvvCtrl]) {
      c.addListener(_refresh);
    }
    _cvvFocus.addListener(() {
      if (mounted) setState(() => _flipped = _cvvFocus.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  void _prefill() {
    if (!mounted) return;
    final app = context.read<AppProvider>();
    final methods = app.user?.paymentMethods ?? const <PaymentMethodModel>[];
    final momo = methods.where((m) => m.type == 'momo').toList();
    final defMomo = momo.where((m) => m.isDefault).toList();
    final pick = defMomo.isNotEmpty ? defMomo.first : (momo.isNotEmpty ? momo.first : null);
    final phone = pick?.accountNumber ?? app.user?.phone;
    if (phone != null && phone.isNotEmpty && _phoneCtrl.text.isEmpty) _phoneCtrl.text = phone;

    final cards = methods.where((m) => m.type == 'bank').toList();
    if (cards.isNotEmpty) {
      final defCard = cards.where((m) => m.isDefault).toList();
      _savedCardId = (defCard.isNotEmpty ? defCard.first : cards.first).id;
      // A rider whose default method is a card lands on the card tab.
      if (defMomo.isEmpty && momo.isEmpty) setState(() => _method = 'card');
    }
    setState(() {});
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stopPolling = true;
    for (final c in [_holderCtrl, _cardCtrl, _expiryCtrl, _cvvCtrl]) {
      c.removeListener(_refresh);
      c.dispose();
    }
    _phoneCtrl.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  // ───────────────────────── validation ─────────────────────────
  String get _cardDigits => _cardCtrl.text.replaceAll(RegExp(r'\D'), '');
  CardBrand get _brand => detectCardBrand(_cardDigits);

  bool _luhn(String d) {
    var sum = 0;
    var alt = false;
    for (var i = d.length - 1; i >= 0; i--) {
      var n = int.parse(d[i]);
      if (alt) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  bool get _phoneValid => RegExp(r'^(255|0)?[67][0-9]{8}$').hasMatch(_phoneCtrl.text.replaceAll(RegExp(r'\D'), ''));

  String? _holderError(AppProvider a) =>
      _holderCtrl.text.trim().length < 2 ? a.t('Enter the name as shown on the card', 'Weka jina kama lilivyo kwenye kadi') : null;

  String? _numberError(AppProvider a) {
    if (_cardDigits.length != _brand.numberLength) {
      return a.t('Enter all ${_brand.numberLength} digits', 'Weka tarakimu zote ${_brand.numberLength}');
    }
    if (!_luhn(_cardDigits)) return a.t('This card number is not valid', 'Namba ya kadi si sahihi');
    return null;
  }

  String? _expiryError(AppProvider a) {
    final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(_expiryCtrl.text);
    if (m == null) return a.t('Use MM/YY', 'Tumia MM/YY');
    final month = int.parse(m.group(1)!);
    final year = 2000 + int.parse(m.group(2)!);
    final now = DateTime.now();
    if (month < 1 || month > 12) return a.t('Invalid month', 'Mwezi si sahihi');
    if (year < now.year || (year == now.year && month < now.month)) return a.t('This card has expired', 'Kadi hii imeisha muda');
    return null;
  }

  String? _cvvError(AppProvider a) =>
      _cvvCtrl.text.length != _brand.cvvLength ? a.t('${_brand.cvvLength} digits', 'Tarakimu ${_brand.cvvLength}') : null;

  bool _newCardValid(AppProvider a) =>
      _holderError(a) == null && _numberError(a) == null && _expiryError(a) == null && _cvvError(a) == null;

  PaymentMethodModel? _savedCard(AppProvider app) {
    final cards = (app.user?.paymentMethods ?? const <PaymentMethodModel>[]).where((m) => m.type == 'bank');
    for (final c in cards) {
      if (c.id == _savedCardId) return c;
    }
    return null;
  }

  // ───────────────────────── actions ─────────────────────────
  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _submit() async {
    final app = context.read<AppProvider>();
    if (_amount < 500) return _snack(app.t('Minimum top-up is TZS 500.', 'Kiwango cha chini ni TZS 500.'));

    if (_method == 'momo') {
      if (!_phoneValid) {
        setState(() => _phoneTouched = true);
        return _snack(app.t('Enter a valid mobile money number.', 'Weka namba sahihi ya pesa ya simu.'));
      }
    } else if (_savedCard(app) == null && !_newCardValid(app)) {
      setState(() => _submitted = true);
      return _snack(app.t('Complete the card details correctly.', 'Jaza taarifa za kadi kwa usahihi.'));
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      TopUpStart start;
      if (_method == 'momo') {
        start = await app.startWalletTopUp(amount: _amount, paymentMethod: 'momo', phone: _phoneCtrl.text.trim());
      } else {
        final saved = _savedCard(app);
        final brand = saved?.cardBrand ?? _brand.name;
        final last4 = saved?.cardLast4 ?? _cardDigits.substring(_cardDigits.length - 4);
        final holder = saved?.cardHolder ?? _holderCtrl.text.trim();
        // Remember the card (masked details only) for next time.
        if (saved == null && _saveCard) {
          try {
            await app.addPaymentMethod(PaymentMethodModel(
              id: '',
              type: 'bank',
              provider: _brand.label,
              cardLast4: last4,
              expiry: _expiryCtrl.text.trim(),
              cardHolder: holder,
              cardBrand: _brand.name,
              isDefault: false,
            ));
          } catch (_) {}
        }
        start = await app.startWalletTopUp(
          amount: _amount,
          paymentMethod: 'card',
          cardBrand: brand,
          cardLast4: last4,
          cardHolder: holder,
        );
        if (start.paymentUrl == null) {
          throw Exception(app.t('The card checkout could not be opened. Please try again.', 'Ukurasa wa malipo ya kadi haukufunguka. Tafadhali jaribu tena.'));
        }
      }
      if (!mounted) return;
      _paymentId = start.paymentId;
      _checkoutUrl = start.paymentUrl;
      _stopPolling = false;
      setState(() {
        _loading = false;
        _stage = _Stage.waiting;
      });
      if (_checkoutUrl != null) await _openCheckout();
      unawaited(_track());
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openCheckout() async {
    final url = _checkoutUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!ok) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) _snack(context.read<AppProvider>().t('Could not open the secure checkout.', 'Imeshindwa kufungua ukurasa salama wa malipo.'));
      }
    }
  }

  Future<void> _track() async {
    final id = _paymentId;
    if (id == null || id.isEmpty) return;
    final app = context.read<AppProvider>();
    final result = await app.waitForTopUp(id, shouldStop: () => _stopPolling || !mounted);
    if (!mounted || _stopPolling) return;
    setState(() {
      _stage = result == 'success' ? _Stage.success : (result == 'failed' ? _Stage.failed : _Stage.timedOut);
    });
    if (result == 'success') {
      try {
        await closeInAppWebView();
      } catch (_) {}
    }
  }

  Future<void> _cancelPayment() async {
    _stopPolling = true;
    final id = _paymentId;
    if (id != null && id.isNotEmpty) unawaited(RiderApi.cancelTopUp(id));
    if (mounted) setState(() => _stage = _Stage.form);
  }

  Future<void> _checkNow() async {
    final app = context.read<AppProvider>();
    final id = _paymentId;
    if (id == null) return;
    setState(() => _stage = _Stage.waiting);
    _stopPolling = false;
    final r = await app.waitForTopUp(id, timeout: const Duration(seconds: 12));
    if (!mounted) return;
    setState(() => _stage = r == 'success' ? _Stage.success : (r == 'failed' ? _Stage.failed : _Stage.timedOut));
  }

  // ───────────────────────── UI ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final accent = app.isDark ? AppColors.aquaGreen : AppColors.oceanTeal;

    return PopScope(
      canPop: _stage != _Stage.waiting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _stage == _Stage.waiting) {
          _snack(app.t('Payment in progress. Use Cancel to stop it.', 'Malipo yanaendelea. Tumia Ghairi kusimamisha.'));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(app.t('Top up wallet', 'Ongeza salio la pochi'))),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (_stage) {
              _Stage.form => _form(app, accent),
              _Stage.waiting => _statusView(app, accent, waiting: true),
              _ => _statusView(app, accent, waiting: false),
            },
          ),
        ),
      ),
    );
  }

  Widget _form(AppProvider app, Color accent) {
    final dark = app.isDark;
    final muted = dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _balanceCard(app),
        const SizedBox(height: 22),
        Text(app.t('Choose amount', 'Chagua kiasi'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        _amountCard(accent),
        const SizedBox(height: 22),
        Text(app.t('Pay using', 'Lipa kwa kutumia'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _methodTile('momo', Icons.phone_android_rounded, app.t('Mobile Money', 'Pesa ya simu'), accent)),
          const SizedBox(width: 12),
          Expanded(child: _methodTile('card', Icons.credit_card_rounded, app.t('Card / Bank', 'Kadi / Benki'), accent)),
        ]),
        const SizedBox(height: 18),
        if (_method == 'momo') ..._momoSection(app, muted) else ..._cardSection(app, accent, muted),
        const SizedBox(height: 16),
        _summary(app),
        const SizedBox(height: 16),
        LoadingButton(
          text: _method == 'card'
              ? app.t('Continue to secure payment', 'Endelea kwenye malipo salama')
              : app.t('Send payment prompt', 'Tuma ombi la malipo'),
          icon: Icons.lock_rounded,
          isLoading: _loading,
          onPressed: _submit,
        ),
      ]),
    );
  }

  List<Widget> _momoSection(AppProvider app, Color muted) => [
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          autocorrect: false,
          onChanged: (_) => setState(() => _phoneTouched = true),
          decoration: InputDecoration(
            labelText: app.t('Mobile money phone number', 'Namba ya simu ya pesa ya simu'),
            hintText: '0712 345 678',
            prefixIcon: const Icon(Icons.phone_android),
            errorText: _phoneTouched && !_phoneValid ? app.t('Enter a valid Tanzania number', 'Weka namba sahihi ya Tanzania') : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(app.t('You will get a prompt on this phone. Enter your PIN to approve the payment.', 'Utapokea ombi kwenye simu hii. Weka PIN yako kuthibitisha malipo.'),
            style: TextStyle(fontSize: 12, color: muted)),
      ];

  List<Widget> _cardSection(AppProvider app, Color accent, Color muted) {
    final saved = (app.user?.paymentMethods ?? const <PaymentMethodModel>[]).where((m) => m.type == 'bank').toList();
    final usingSaved = _savedCard(app) != null;
    final sc = _savedCard(app);

    return [
      // Live preview: mirrors the typed details, or shows the chosen saved card.
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: CreditCardPreview(
            holder: usingSaved ? (sc!.cardHolder ?? '') : _holderCtrl.text,
            number: usingSaved ? '' : _cardCtrl.text,
            expiry: usingSaved ? (sc!.expiry ?? '') : _expiryCtrl.text,
            cvv: usingSaved ? '' : _cvvCtrl.text,
            brand: usingSaved ? cardBrandFromKey(sc!.cardBrand) : _brand,
            showBack: !usingSaved && _flipped,
            onTap: usingSaved ? null : () => setState(() => _flipped = !_flipped),
          ),
        ),
      ),
      if (usingSaved)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(child: Text('•••• •••• •••• ${sc!.cardLast4 ?? ''}', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2, color: muted))),
        ),
      const SizedBox(height: 14),
      if (saved.isNotEmpty) ...[
        ...saved.map((m) => _savedCardTile(m, m.id == _savedCardId, accent)),
        _newCardTile(!usingSaved, accent, app),
        const SizedBox(height: 10),
      ],
      if (!usingSaved) ..._newCardFields(app, accent, muted),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: accent.withOpacity(.08), borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.verified_user_rounded, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              app.t('Your card number and CVV stay on this device. You approve the payment on your bank\'s secure page (3-D Secure / OTP). The wallet is credited only after the bank confirms.',
                  'Namba ya kadi na CVV hubaki kwenye simu hii. Unathibitisha malipo kwenye ukurasa salama wa benki yako. Salio huongezwa baada ya benki kuthibitisha.'),
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
        ]),
      ),
    ];
  }

  List<Widget> _newCardFields(AppProvider app, Color accent, Color muted) => [
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
              decoration: InputDecoration(labelText: 'CVV', counterText: '', errorText: _submitted ? _cvvError(app) : null),
            ),
          ),
        ]),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _saveCard,
          activeColor: accent,
          title: Text(app.t('Save this card for next time', 'Hifadhi kadi hii kwa wakati ujao')),
          subtitle: Text(app.t('Only the last 4 digits, name and expiry are saved.', 'Tarakimu 4 za mwisho, jina na tarehe ya mwisho pekee ndizo huhifadhiwa.')),
          onChanged: (v) => setState(() => _saveCard = v),
        ),
      ];

  Widget _savedCardTile(PaymentMethodModel m, bool selected, Color accent) => GestureDetector(
        onTap: () => setState(() => _savedCardId = m.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? accent : Colors.transparent, width: 1.5)),
          child: Row(children: [
            Icon(Icons.credit_card_rounded, color: selected ? accent : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.provider ?? 'Bank Card', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('•••• ${m.cardLast4 ?? ''}${(m.expiry ?? '').isEmpty ? '' : '  ·  ${m.expiry}'}', style: const TextStyle(fontSize: 12)),
              ]),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? accent : Colors.grey),
          ]),
        ),
      );

  Widget _newCardTile(bool selected, Color accent, AppProvider app) => GestureDetector(
        onTap: () => setState(() {
          _savedCardId = null;
          _submitted = false;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? accent : Colors.transparent, width: 1.5)),
          child: Row(children: [
            Icon(Icons.add_card_rounded, color: selected ? accent : null),
            const SizedBox(width: 12),
            Expanded(child: Text(app.t('Use a new card', 'Tumia kadi mpya'), style: const TextStyle(fontWeight: FontWeight.w700))),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? accent : Colors.grey),
          ]),
        ),
      );

  Widget _methodTile(String id, IconData icon, String label, Color accent) {
    final selected = _method == id;
    return GestureDetector(
      onTap: () => setState(() => _method = id),
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

  Widget _amountCard(Color accent) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Text(formatTzs(_amount), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          Slider(min: 500, max: 100000, divisions: 199, value: _amount.clamp(500, 100000).toDouble(), activeColor: accent, onChanged: (v) => setState(() => _amount = v.roundToDouble())),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [1000, 5000, 10000, 20000, 50000]
                .map((v) => ChoiceChip(label: Text(formatTzs(v)), selected: _amount == v.toDouble(), onSelected: (_) => setState(() => _amount = v.toDouble())))
                .toList(),
          ),
        ]),
      );

  Widget _balanceCard(AppProvider app) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: app.isDark ? [AppColors.darkCard, AppColors.darkSurface] : [AppColors.deepNavy, AppColors.oceanTeal]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          const CircleAvatar(radius: 24, backgroundColor: Colors.white24, child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.t('Current wallet balance', 'Salio la pochi sasa'), style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(formatTzs(app.walletBalance), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      );

  Widget _summary(AppProvider app) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          _row(app.t('Top-up amount', 'Kiasi'), formatTzs(_amount)),
          const Divider(height: 20),
          _row(app.t('Balance after top-up', 'Salio baada ya kuongeza'), formatTzs(app.walletBalance + _amount), bold: true),
        ]),
      );

  Widget _row(String label, String value, {bool bold = false}) =>
      Row(children: [Expanded(child: Text(label)), Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600))]);

  // ───────────────────────── status screens ─────────────────────────
  Widget _statusView(AppProvider app, Color accent, {required bool waiting}) {
    final isCard = _method == 'card';
    IconData icon;
    Color color;
    String title;
    String body;
    switch (_stage) {
      case _Stage.success:
        icon = Icons.check_circle_rounded;
        color = AppColors.brightGreen;
        title = app.t('Wallet topped up', 'Salio limeongezwa');
        body = app.t('${formatTzs(_amount)} was added. New balance: ${formatTzs(app.walletBalance)}.', '${formatTzs(_amount)} imeongezwa. Salio jipya: ${formatTzs(app.walletBalance)}.');
        break;
      case _Stage.failed:
        icon = Icons.cancel_rounded;
        color = Colors.redAccent;
        title = app.t('Payment not completed', 'Malipo hayakukamilika');
        body = app.t('The payment was declined or cancelled. Your wallet was not charged or changed.', 'Malipo yalikataliwa au yalighairiwa. Salio lako halijabadilika.');
        break;
      case _Stage.timedOut:
        icon = Icons.hourglass_bottom_rounded;
        color = Colors.orange;
        title = app.t('Still waiting for confirmation', 'Bado tunasubiri uthibitisho');
        body = app.t('We have not received confirmation yet. If you already approved the payment, your wallet will update automatically once it arrives.', 'Hatujapokea uthibitisho bado. Ikiwa umeshaidhinisha, salio litasasishwa moja kwa moja likifika.');
        break;
      default:
        icon = isCard ? Icons.lock_clock_rounded : Icons.phone_android_rounded;
        color = accent;
        title = isCard ? app.t('Complete payment on the secure page', 'Kamilisha malipo kwenye ukurasa salama') : app.t('Approve the prompt on your phone', 'Idhinisha ombi kwenye simu yako');
        body = isCard
            ? app.t('Approve the payment with your bank (OTP / 3-D Secure). Come back here when you are done. We will confirm automatically.', 'Idhinisha malipo kwa benki yako (OTP / 3-D Secure). Rudi hapa ukimaliza. Tutathibitisha moja kwa moja.')
            : app.t('Enter your mobile-money PIN to approve ${formatTzs(_amount)}. This screen updates by itself.', 'Weka PIN ya pesa ya simu kuidhinisha ${formatTzs(_amount)}. Skrini hii inajisasisha yenyewe.');
    }

    return Center(
      key: ValueKey(_stage),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (waiting) SizedBox(width: 72, height: 72, child: CircularProgressIndicator(strokeWidth: 5, color: accent)) else Icon(icon, color: color, size: 84),
          const SizedBox(height: 22),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 26),
          if (waiting) ...[
            if (isCard && _checkoutUrl != null)
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _openCheckout, icon: const Icon(Icons.open_in_new_rounded), label: Text(app.t('Reopen secure payment page', 'Fungua tena ukurasa wa malipo')))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _checkNow, child: Text(app.t('I have paid. Check now', 'Nimelipa. Angalia sasa')))),
            TextButton(onPressed: _cancelPayment, child: Text(app.t('Cancel payment', 'Ghairi malipo'))),
          ] else if (_stage == _Stage.success)
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(app.t('Done', 'Maliza'))))
          else ...[
            if (_stage == _Stage.timedOut)
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _checkNow, child: Text(app.t('Check again', 'Angalia tena')))),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => setState(() => _stage = _Stage.form), child: Text(app.t('Try again', 'Jaribu tena')))),
            TextButton(onPressed: () => Navigator.pop(context, _stage == _Stage.timedOut), child: Text(app.t('Close', 'Funga'))),
          ],
        ]),
      ),
    );
  }
}
