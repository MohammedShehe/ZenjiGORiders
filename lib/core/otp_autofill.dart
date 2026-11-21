import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:sms_autofill/sms_autofill.dart';

/// Android SMS Retriever: fills the OTP automatically when the SMS carries this app's 11-character hash
/// (the backend adds it from OTP_ANDROID_APP_HASH_RIDER / OTP_ANDROID_APP_HASH_DRIVER). No SMS permission needed.
class OtpAutofill {
  static StreamSubscription<String>? _sub;
  static final RegExp _sixDigits = RegExp(r'(?<!\d)(\d{6})(?!\d)');

  /// Starts waiting for the next OTP SMS (valid ~5 minutes). Safe to call again on "Resend".
  static Future<void> listen(void Function(String code) onCode) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await stop();
      await SmsAutoFill().listenForCode(smsCodeRegexPattern: r'\d{6}');
      _sub = SmsAutoFill().code.listen((value) {
        final m = _sixDigits.firstMatch(value);
        if (m != null) onCode(m.group(1)!);
      });
      if (kDebugMode) {
        final hash = await SmsAutoFill().getAppSignature;
        debugPrint('[OTP] This build\'s SMS app hash: $hash  (set it in OTP_ANDROID_APP_HASH for debug builds)');
      }
    } catch (e) {
      debugPrint('[OTP] autofill unavailable: $e');
    }
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await SmsAutoFill().unregisterListener();
    } catch (_) {}
  }
}
