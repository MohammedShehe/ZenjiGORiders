import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Card brand helpers
// ─────────────────────────────────────────────────────────────────────────────

enum CardBrand { visa, mastercard, amex, discover, unknown }

extension CardBrandX on CardBrand {
  /// Total number of digits on the card number.
  int get numberLength => this == CardBrand.amex ? 15 : 16;

  /// Digits in the security code (Amex uses a 4 digit code on the front).
  int get cvvLength => this == CardBrand.amex ? 4 : 3;

  String get label {
    switch (this) {
      case CardBrand.visa:
        return 'Visa';
      case CardBrand.mastercard:
        return 'Mastercard';
      case CardBrand.amex:
        return 'American Express';
      case CardBrand.discover:
        return 'Discover';
      case CardBrand.unknown:
        return 'Bank Card';
    }
  }

  List<Color> get gradient {
    switch (this) {
      case CardBrand.visa:
        return const [Color(0xFF12296B), Color(0xFF2E6FE0)];
      case CardBrand.mastercard:
        return const [Color(0xFF1E2230), Color(0xFF6B2D3C)];
      case CardBrand.amex:
        return const [Color(0xFF0A5E66), Color(0xFF38B8A8)];
      case CardBrand.discover:
        return const [Color(0xFF3B2A20), Color(0xFFE2782C)];
      case CardBrand.unknown:
        return const [AppColors.deepNavy, AppColors.oceanTeal];
    }
  }
}

CardBrand cardBrandFromKey(String? key) => CardBrand.values.firstWhere(
      (b) => b.name == key,
      orElse: () => CardBrand.unknown,
    );

/// Detects the card network from the leading digits (IIN ranges).
CardBrand detectCardBrand(String input) {
  final d = input.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return CardBrand.unknown;
  if (d.startsWith('4')) return CardBrand.visa;
  if (d.startsWith('34') || d.startsWith('37')) return CardBrand.amex;
  if (d.length >= 2) {
    final p2 = int.parse(d.substring(0, 2));
    if (p2 >= 51 && p2 <= 55) return CardBrand.mastercard;
    if (p2 == 65) return CardBrand.discover;
  }
  if (d.length >= 3) {
    final p3 = int.parse(d.substring(0, 3));
    if (p3 >= 644 && p3 <= 649) return CardBrand.discover;
  }
  if (d.length >= 4) {
    final p4 = int.parse(d.substring(0, 4));
    if (p4 >= 2221 && p4 <= 2720) return CardBrand.mastercard;
    if (p4 == 6011) return CardBrand.discover;
  }
  return CardBrand.unknown;
}

List<int> _groups(CardBrand brand) =>
    brand == CardBrand.amex ? const [4, 6, 5] : const [4, 4, 4, 4];

/// Groups digits as "4242 4242 4242 4242" (or 4-6-5 for Amex).
String formatCardNumber(String digits, CardBrand brand) {
  final buf = StringBuffer();
  var i = 0;
  for (final g in _groups(brand)) {
    if (i >= digits.length) break;
    if (buf.isNotEmpty) buf.write(' ');
    buf.write(digits.substring(i, math.min(i + g, digits.length)));
    i += g;
  }
  return buf.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// Input formatters
// ─────────────────────────────────────────────────────────────────────────────

/// Keeps digits only, caps length by brand and inserts spaces while typing.
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final brand = detectCardBrand(digits);
    final capped = digits.length > brand.numberLength ? digits.substring(0, brand.numberLength) : digits;
    final formatted = formatCardNumber(capped, brand);

    // Keep the caret next to the same digit, so editing mid-number works.
    final cursor = newValue.selection.baseOffset.clamp(0, raw.length);
    var digitsBeforeCursor = raw.substring(0, cursor).replaceAll(RegExp(r'\D'), '').length;
    digitsBeforeCursor = math.min(digitsBeforeCursor, capped.length);

    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < digitsBeforeCursor) {
      if (formatted[offset] != ' ') seen++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Formats expiry as MM/YY, auto-inserting the slash and rejecting bad months.
class ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return const TextEditingValue();

    // "5" -> "05" so the month is always two digits.
    if (int.parse(d[0]) > 1) d = '0$d';
    if (d.length > 4) d = d.substring(0, 4);

    if (d.length >= 2) {
      final month = int.parse(d.substring(0, 2));
      if (month < 1 || month > 12) return oldValue;
    }

    final growing = newValue.text.length > oldValue.text.length;
    String text;
    if (d.length > 2) {
      text = '${d.substring(0, 2)}/${d.substring(2)}';
    } else if (d.length == 2 && growing) {
      text = '$d/';
    } else {
      text = d;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Allows letters, spaces and the punctuation found in names.
final List<TextInputFormatter> cardHolderFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z .'\-]")),
  LengthLimitingTextInputFormatter(26),
];

// ─────────────────────────────────────────────────────────────────────────────
// The preview card
// ─────────────────────────────────────────────────────────────────────────────

/// A styled bank-card mockup that mirrors whatever the user types.
/// Flips to the back (CVV side) when [showBack] is true or the card is tapped.
class CreditCardPreview extends StatelessWidget {
  final String holder;
  final String number;
  final String expiry;
  final String cvv;
  final CardBrand brand;
  final bool showBack;
  final VoidCallback? onTap;

  const CreditCardPreview({
    super.key,
    required this.holder,
    required this.number,
    required this.expiry,
    required this.cvv,
    required this.brand,
    this.showBack = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.586, // ISO/IEC 7810 ID-1 card proportions
        child: LayoutBuilder(builder: (context, c) {
          final s = c.maxWidth / 340;
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: showBack ? math.pi : 0),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeInOutCubic,
            builder: (context, angle, _) {
              final isBack = angle > math.pi / 2;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(angle),
                child: isBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _face(s, _back(s)),
                      )
                    : _face(s, _front(s)),
              );
            },
          );
        }),
      ),
    );
  }

  // Shared card body: gradient, shadow and decorative shapes.
  Widget _face(double s, Widget content) {
    final colors = brand.gradient;
    final radius = BorderRadius.circular(22 * s);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: colors.last.withOpacity(.38), blurRadius: 26 * s, offset: Offset(0, 14 * s)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(right: -60 * s, top: -70 * s, child: _circle(200 * s, .09)),
            Positioned(left: -70 * s, bottom: -110 * s, child: _circle(230 * s, .07)),
            Positioned.fill(child: content),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
      );

  Widget _front(double s) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > brand.numberLength ? digits.substring(0, brand.numberLength) : digits;
    final padded = capped + '•' * (brand.numberLength - capped.length);
    final display = formatCardNumber(padded, brand);

    final hasHolder = holder.trim().isNotEmpty;
    final hasExpiry = expiry.isNotEmpty;

    return Padding(
      padding: EdgeInsets.all(22 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ZenjiGO',
                style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w800, fontSize: 16 * s, letterSpacing: .4),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(key: ValueKey(brand), child: _brandMark(s)),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _chip(s),
              SizedBox(width: 10 * s),
              Icon(Icons.contactless_rounded, color: Colors.white.withOpacity(.85), size: 26 * s),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              display,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white.withOpacity(capped.isEmpty ? .7 : 1),
                fontSize: 22 * s,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.2 * s,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: const [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
              ),
            ),
          ),
          SizedBox(height: 16 * s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('CARD HOLDER', s),
                    SizedBox(height: 3 * s),
                    Text(
                      hasHolder ? holder.trim().toUpperCase() : 'YOUR NAME',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(hasHolder ? 1 : .55),
                        fontSize: 14 * s,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1 * s,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12 * s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('VALID THRU', s),
                  SizedBox(height: 3 * s),
                  Text(
                    hasExpiry ? expiry : 'MM/YY',
                    style: TextStyle(
                      color: Colors.white.withOpacity(hasExpiry ? 1 : .55),
                      fontSize: 14 * s,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1 * s,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _back(double s) {
    final masked = '•' * cvv.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 26 * s),
        Container(height: 44 * s, color: Colors.black.withOpacity(.82)),
        SizedBox(height: 22 * s),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 22 * s),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 38 * s,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.85),
                    borderRadius: BorderRadius.circular(6 * s),
                  ),
                  child: CustomPaint(painter: _SignatureLinesPainter()),
                ),
              ),
              SizedBox(width: 10 * s),
              Container(
                width: 62 * s,
                height: 38 * s,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6 * s)),
                child: Text(
                  masked.isEmpty ? '•••' : masked,
                  style: TextStyle(
                    color: masked.isEmpty ? Colors.black26 : Colors.black87,
                    fontSize: 16 * s,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2 * s,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 6 * s, right: 22 * s),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('CVV', style: TextStyle(color: Colors.white70, fontSize: 10 * s, letterSpacing: 1.2)),
          ),
        ),
        const Spacer(),
        Padding(
          padding: EdgeInsets.fromLTRB(22 * s, 0, 22 * s, 18 * s),
          child: Row(
            children: [
              Icon(Icons.lock_rounded, size: 13 * s, color: Colors.white60),
              SizedBox(width: 6 * s),
              Expanded(
                child: Text(
                  'Preview only. Your CVV is never saved.',
                  style: TextStyle(color: Colors.white60, fontSize: 10.5 * s),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text, double s) => Text(
        text,
        style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 9 * s, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      );

  Widget _chip(double s) => Container(
        width: 42 * s,
        height: 32 * s,
        padding: EdgeInsets.symmetric(vertical: 6 * s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6 * s),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7E2A0), Color(0xFFD6A93F)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            3,
            (_) => Container(height: 1.2 * s, color: Colors.black.withOpacity(.22)),
          ),
        ),
      );

  Widget _brandMark(double s) {
    switch (brand) {
      case CardBrand.visa:
        return Text(
          'VISA',
          style: TextStyle(color: Colors.white, fontSize: 22 * s, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 1),
        );
      case CardBrand.mastercard:
        return SizedBox(
          width: 44 * s,
          height: 28 * s,
          child: Stack(
            children: [
              Positioned(left: 0, child: _dot(28 * s, const Color(0xFFEB001B))),
              Positioned(right: 0, child: _dot(28 * s, const Color(0xFFF79E1B).withOpacity(.92))),
            ],
          ),
        );
      case CardBrand.amex:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 3 * s),
          decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.4), borderRadius: BorderRadius.circular(4 * s)),
          child: Text('AMEX', style: TextStyle(color: Colors.white, fontSize: 13 * s, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
        );
      case CardBrand.discover:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('DISCOVER', style: TextStyle(color: Colors.white, fontSize: 13 * s, fontWeight: FontWeight.w800, letterSpacing: .8)),
            SizedBox(width: 5 * s),
            _dot(14 * s, const Color(0xFFFFB347)),
          ],
        );
      case CardBrand.unknown:
        return Icon(Icons.credit_card_rounded, color: Colors.white.withOpacity(.75), size: 28 * s);
    }
  }

  Widget _dot(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _SignatureLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(.12)
      ..strokeWidth = 1;
    for (double y = 8; y < size.height; y += 8) {
      canvas.drawLine(Offset(6, y), Offset(size.width - 6, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
