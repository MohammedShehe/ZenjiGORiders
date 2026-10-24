/// Tanzania (East Africa Time, UTC+3) helpers — no external timezone package required.
class TanzaniaTime {
  static const int offsetHours = 3;

  static DateTime now() => DateTime.now().toUtc().add(const Duration(hours: offsetHours));

  static DateTime toEat(DateTime dt) {
    final utc = dt.isUtc ? dt : dt.toUtc();
    return utc.add(const Duration(hours: offsetHours));
  }

  static String format(DateTime? dt, {bool withTime = true}) {
    if (dt == null) return '—';
    final e = toEat(dt);
    final y = e.year.toString().padLeft(4, '0');
    final m = e.month.toString().padLeft(2, '0');
    final d = e.day.toString().padLeft(2, '0');
    if (!withTime) return '$y-$m-$d';
    final hh = e.hour.toString().padLeft(2, '0');
    final mm = e.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm EAT';
  }

  static String formatString(String? raw, {bool withTime = true}) {
    if (raw == null || raw.trim().isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw.replaceFirst(' ', 'T'));
      return format(dt, withTime: withTime);
    } catch (_) {
      return raw;
    }
  }
}
