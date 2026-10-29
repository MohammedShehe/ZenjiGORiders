/// Turns any thrown error into a short, human message (English + Swahili).
/// Rules: network/technical failures are always rewritten; clear sentences that the
/// ZenjiGO server wrote itself (e.g. "Incorrect PIN") are shown as they are.
class FriendlyErrors {
  FriendlyErrors._();

  static bool _isTechnical(String lower) =>
      lower.contains('socketexception') ||
      lower.contains('handshakeexception') ||
      lower.contains('clientexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('connection closed') ||
      lower.contains('network is unreachable') ||
      lower.contains('os error') ||
      lower.contains('formatexception') ||
      lower.contains('type \'') ||
      lower.contains('is not a subtype') ||
      lower.contains('null check') ||
      lower.contains('package:') ||
      lower.contains('dart:') ||
      lower.contains('http://') ||
      lower.contains('https://') ||
      lower.contains('stack');

  static String message(Object error, {bool swahili = false}) {
    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    final lower = raw.toLowerCase();
    String pick(String en, String sw) => swahili ? sw : en;

    if (lower.contains('timed out') || lower.contains('timeoutexception') || lower.contains('took too long')) {
      return pick('The connection is slow. Please try again.', 'Mtandao ni polepole. Tafadhali jaribu tena.');
    }
    if (_isTechnical(lower) || lower.contains('no internet') || lower.contains('network')) {
      return pick(
        'No internet connection. Check your data or Wi‑Fi and try again.',
        'Hakuna muunganisho wa intaneti. Angalia data au Wi‑Fi kisha jaribu tena.',
      );
    }
    if (lower.contains('session expired') || lower.contains('jwt') || lower.contains('invalid token') || lower.contains('unauthorized')) {
      return pick('Your session expired. Please sign in again.', 'Kipindi chako kimekwisha. Tafadhali ingia tena.');
    }

    // Plain-language message from our own server: keep it.
    final looksHuman = raw.isNotEmpty && raw.length <= 200 && RegExp(r'^[A-Za-z]').hasMatch(raw);
    if (looksHuman && !RegExp(r'^(http|request failed|http \d{3})', caseSensitive: false).hasMatch(raw)) {
      return raw;
    }

    final code = RegExp(r'\b(4\d\d|5\d\d)\b').firstMatch(raw)?.group(1);
    switch (code) {
      case '401':
        return pick('Your session expired. Please sign in again.', 'Kipindi chako kimekwisha. Tafadhali ingia tena.');
      case '403':
        return pick('You do not have permission for this action.', 'Huna ruhusa ya kufanya hatua hii.');
      case '404':
        return pick('We could not find that. It may have been removed.', 'Hatukuweza kupata kitu hicho. Huenda kimeondolewa.');
      case '409':
        return pick('That changed in the meantime. Refresh and try again.', 'Hali imebadilika. Onyesha upya kisha jaribu tena.');
      case '422':
        return pick('Some details look incorrect. Please check and try again.', 'Baadhi ya taarifa si sahihi. Tafadhali angalia kisha jaribu tena.');
      case '429':
        return pick('Too many attempts. Wait a moment and try again.', 'Umejaribu mara nyingi. Subiri kidogo kisha jaribu tena.');
    }
    if (code != null && code.startsWith('5')) {
      return pick('Something went wrong on our side. Please try again shortly.', 'Kuna hitilafu upande wetu. Tafadhali jaribu tena baadaye kidogo.');
    }
    return pick('Something went wrong. Please try again.', 'Kuna hitilafu. Tafadhali jaribu tena.');
  }
}
