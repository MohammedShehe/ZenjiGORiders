import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ride_model.dart';
import '../../providers/app_provider.dart';

/// Read-only details for a past (completed/cancelled) ride — never starts searching.
class RideHistoryDetailsScreen extends StatelessWidget {
  final RideModel ride;

  const RideHistoryDetailsScreen({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;
    final discount = ride.discount ?? 0;
    final tip = ride.tip ?? 0;
    final base = ride.finalFare ?? ride.estimatedFare;
    final total = (base - discount + tip).clamp(0, double.infinity);
    final isCancelled = ride.status == 'cancelled';

    return Scaffold(
      appBar: AppBar(
        title: Text(isCancelled ? app.t('Cancelled Ride', 'Safari Iliyoghairiwa') : app.t('Ride Details', 'Maelezo ya Safari')),
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 200,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(ride.fromLat, ride.fromLng),
                initialZoom: 13,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate: isDark
                      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                      : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.zenjigo.riders',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(ride.fromLat, ride.fromLng),
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.person_pin_circle, color: AppColors.brightGreen, size: 32),
                    ),
                    Marker(
                      point: LatLng(ride.toLat, ride.toLng),
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.location_on, color: AppColors.sunsetOrange, size: 32),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? AppColors.error.withOpacity(0.15)
                        : AppColors.brightGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ride.status.toUpperCase(),
                    style: TextStyle(
                      color: isCancelled ? AppColors.error : AppColors.brightGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _line(app.t('From', 'Kutoka'), ride.fromAddress),
                _line(app.t('To', 'Kwenda'), ride.toAddress),
                _line(app.t('Type', 'Aina'), ride.rideType.toUpperCase()),
                if (ride.driver != null) ...[
                  _line(app.t('Driver', 'Dereva'), ride.driver!.name),
                  _line(app.t('Vehicle', 'Gari'), '${ride.driver!.vehicleNumber} · ${ride.driver!.vehicleType}'),
                ],
                _line(app.t('Payment', 'Malipo'), (ride.paymentMethod ?? '—').toUpperCase()),
                if (ride.cancelReason != null) _line(app.t('Cancel reason', 'Sababu'), ride.cancelReason!),
                if (ride.rating != null)
                  Row(
                    children: [
                      Text('${app.t('Your rating', 'Ukadiriaji')}: '),
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < ride.rating! ? Icons.star : Icons.star_border,
                          color: AppColors.sunsetOrange,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                const Divider(height: 28),
                _line(app.t('Fare', 'Nauli'), 'TZS ${base.toStringAsFixed(0)}'),
                if (discount > 0) _line(app.t('Discount', 'Punguzo'), '- TZS ${discount.toStringAsFixed(0)}'),
                if (tip > 0) _line(app.t('Tip', 'Tip'), 'TZS ${tip.toStringAsFixed(0)}'),
                _line(app.t('Total', 'Jumla'), 'TZS ${total.toStringAsFixed(0)}', bold: true),
                const SizedBox(height: 8),
                Text(
                  '${app.t('Booked', 'Iliagizwa')}: ${ride.createdAt}',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                if (ride.completedAt != null)
                  Text(
                    '${app.t('Completed', 'Ilikamilika')}: ${ride.completedAt}',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }
}
