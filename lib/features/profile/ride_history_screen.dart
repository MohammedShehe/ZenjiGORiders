import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../ride/ride_history_details_screen.dart';

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final rides = app.rideHistory;
    return Scaffold(
      appBar: AppBar(title: Text(app.t('Ride History', 'Historia ya Safari'))),
      body: rides.isEmpty
          ? Center(child: Text(app.t('No rides yet.', 'Hakuna safari bado.')))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rides.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ride = rides[index];
                final isCancelled = ride.status == 'cancelled';
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: isCancelled
                          ? Colors.red.withOpacity(0.15)
                          : Colors.green.withOpacity(0.15),
                      child: Icon(
                        ride.rideType == 'boda' ? Icons.two_wheeler : Icons.local_taxi,
                        color: isCancelled ? Colors.red : Colors.green,
                      ),
                    ),
                    title: Text(
                      '${ride.fromAddress} → ${ride.toAddress}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        '${ride.status.toUpperCase()} · TZS ${(ride.finalFare ?? ride.estimatedFare).toStringAsFixed(0)}\n${ride.createdAt.toLocal().toString().split('.').first}',
                      ),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RideHistoryDetailsScreen(ride: ride),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
