/// Formats amounts as "TZS 14,900" with thousands separators.
String formatTzs(num? amount, {bool withCurrency = true}) {
  if (amount == null) return withCurrency ? 'TZS —' : '—';
  final rounded = amount.round();
  final negative = rounded < 0;
  final digits = (negative ? -rounded : rounded).toString();
  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final body = '${negative ? '-' : ''}${buf.toString()}';
  return withCurrency ? 'TZS $body' : body;
}
