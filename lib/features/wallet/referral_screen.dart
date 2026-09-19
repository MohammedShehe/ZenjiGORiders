import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_provider.dart';

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  static const _code = 'MO11-ZENJI'; // demo; backend will issue user-specific codes

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(app.t('Refer & Earn', 'Rejelea & Pata'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.card_giftcard, size: 80),
            const SizedBox(height: 20),
            Text(
              app.t('Invite friends to ZenjiGO', 'Alika marafiki kwenye ZenjiGO'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              app.t(
                'Share your referral code. When an eligible friend completes their first ride, rewards can be credited to your wallet.',
                'Shiriki nambari yako. Rafiki anapokamilisha safari ya kwanza, zawadi zinaweza kuongezwa kwenye pochi yako.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey),
              ),
              child: const Text(
                _code,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: _code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(app.t('Referral code copied.', 'Nambari imenakiliwa.'))),
                );
              },
              icon: const Icon(Icons.copy),
              label: Text(app.t('Copy Referral Code', 'Nakili Nambari')),
            ),
            OutlinedButton.icon(
              onPressed: () {
                final text = Uri.encodeComponent(
                  app.t(
                    'Join ZenjiGO with my code $_code and get started on rides in Zanzibar!',
                    'Jiunge na ZenjiGO kwa nambari $_code na anza safari Zanzibar!',
                  ),
                );
                launchUrl(Uri.parse('https://wa.me/?text=$text'));
              },
              icon: const Icon(Icons.share),
              label: Text(app.t('Share Referral', 'Shiriki Rejelea')),
            ),
          ],
        ),
      ),
    );
  }
}
