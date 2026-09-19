import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ride_model.dart';
import '../../providers/app_provider.dart';
import '../ride/ride_details_screen.dart';

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<AppProvider>().rideHistory;
    return Scaffold(
      appBar: AppBar(title: const Text('Ride History')),
      body: rides.isEmpty
          ? const Center(child: Text('No rides yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rides.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ride = rides[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      child: Icon(ride.rideType == 'boda' ? Icons.two_wheeler : Icons.local_taxi),
                    ),
                    title: Text(
                      '${ride.fromAddress} → ${ride.toAddress}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        '${ride.status.toUpperCase()} · TZS ${ride.estimatedFare.toStringAsFixed(0)}\n${ride.createdAt}',
                      ),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RideDetailsScreen(
                          rideType: ride.rideType,
                          from: ride.fromAddress,
                          to: ride.toAddress,
                          fare: ride.estimatedFare,
                          eta: ride.etaMinutes,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
