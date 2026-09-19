import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_model.dart';
import '../../providers/app_provider.dart';

class RideReceiptScreen extends StatelessWidget {
  final RideModel ride;

  const RideReceiptScreen({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;
    final discount = ride.discount ?? 0;
    final tip = ride.tip ?? 0;
    final base = ride.finalFare ?? ride.estimatedFare;
    final total = (base - discount + tip).clamp(0, double.infinity);

    return Scaffold(
      appBar: AppBar(
        title: Text(app.t('Trip Receipt', 'Risiti ya Safari')),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.brightGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.brightGreen, size: 56),
                  const SizedBox(height: 8),
                  Text(
                    app.t('Trip completed', 'Safari imekamilika'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (ride.rating != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < ride.rating! ? Icons.star : Icons.star_border,
                          color: AppColors.sunsetOrange,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _row(app.t('From', 'Kutoka'), ride.fromAddress, isDark),
            _row(app.t('To', 'Kwenda'), ride.toAddress, isDark),
            _row(app.t('Ride type', 'Aina'), ride.rideType.toUpperCase(), isDark),
            if (ride.driver != null) _row(app.t('Driver', 'Dereva'), ride.driver!.name, isDark),
            _row(app.t('Payment', 'Malipo'), (ride.paymentMethod ?? 'cash').toUpperCase(), isDark),
            const Divider(height: 28),
            _row(app.t('Fare', 'Nauli'), 'TZS ${base.toStringAsFixed(0)}', isDark),
            if (discount > 0) _row(app.t('Promo discount', 'Punguzo'), '- TZS ${discount.toStringAsFixed(0)}', isDark, valueColor: AppColors.brightGreen),
            if (tip > 0) _row(app.t('Tip', 'Tip'), 'TZS ${tip.toStringAsFixed(0)}', isDark),
            const Divider(height: 28),
            _row(app.t('Total', 'Jumla'), 'TZS ${total.toStringAsFixed(0)}', isDark, bold: true),
            if (ride.promoCode != null) ...[
              const SizedBox(height: 8),
              Text(
                app.t('Promo: ${ride.promoCode}', 'Promo: ${ride.promoCode}'),
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ],
            if (ride.feedback != null && ride.feedback!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(app.t('Your feedback', 'Maoni yako'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(ride.feedback!),
            ],
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brightGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(app.t('Back to Home', 'Rudi Nyumbani')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, bool isDark, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
