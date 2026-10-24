import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../core/utils/money.dart';
import '../../core/utils/tanzania_time.dart';
import '../ride/ride_history_details_screen.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppProvider>().refreshRideHistory();
    });
  }

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
                        '${ride.status.toUpperCase()} · ${formatTzs(ride.finalFare ?? ride.estimatedFare)}\n${TanzaniaTime.format(ride.createdAt)}',
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
