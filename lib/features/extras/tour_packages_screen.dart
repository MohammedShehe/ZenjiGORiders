import 'package:flutter/material.dart';
import '../tracking/tracking_screen.dart';

class TourPackagesScreen extends StatelessWidget {
  const TourPackagesScreen({super.key});

  static const packages = [
    {'title': 'Half-Day Stone Town', 'price': 45000, 'hours': 4, 'icon': '🏛️'},
    {'title': 'Full-Day Island Tour', 'price': 90000, 'hours': 8, 'icon': '🏝️'},
    {'title': 'Nungwi Sunset Ride', 'price': 35000, 'hours': 3, 'icon': '🌅'},
    {'title': 'Spice Farm Experience', 'price': 55000, 'hours': 5, 'icon': '🌿'},
    {'title': 'Pemba Island Adventure', 'price': 150000, 'hours': 10, 'icon': '🚤'},
  ];

  Future<void> _configure(BuildContext context, Map<String, Object> package) async {
    final pickup = TextEditingController();
    int tourists = 1;
    TimeOfDay? pickupTime;
    try {
      final result = await showDialog<_TourBooking>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(package['title'] as String),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pickup,
                    decoration: const InputDecoration(
                      labelText: 'Pickup location',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  Row(
                    children: [
                      const Expanded(child: Text('Number of tourists')),
                      IconButton(onPressed: () => setDialogState(() => tourists = (tourists - 1).clamp(1, 50)), icon: const Icon(Icons.remove_circle_outline)),
                      Text('$tourists'),
                      IconButton(onPressed: () => setDialogState(() => tourists = (tourists + 1).clamp(1, 50)), icon: const Icon(Icons.add_circle_outline)),
                    ],
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text(pickupTime == null ? 'Choose pickup time' : 'Pickup at ${pickupTime!.format(dialogContext)}'),
                    onTap: () async {
                      final selected = await showTimePicker(context: dialogContext, initialTime: TimeOfDay.now());
                      if (selected != null) setDialogState(() => pickupTime = selected);
                    },
                  ),
                  const Text('Return time is calculated automatically from the package duration.'),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (pickup.text.trim().isEmpty || pickupTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter pickup location and pickup time.')));
                    return;
                  }
                  Navigator.pop(dialogContext, _TourBooking(pickup.text.trim(), tourists, pickupTime!));
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );

      if (result == null || !context.mounted) return;
      final minutes = (package['hours'] as int) * 60;
      final start = result.time.hour * 60 + result.time.minute;
      final returned = (start + minutes) % (24 * 60);
      final returnTime = TimeOfDay(hour: returned ~/ 60, minute: returned % 60);

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm Tour'),
          content: Text(
            '${package['title']}\n\nPickup: ${result.pickup}\nTourists: ${result.tourists}\nPickup time: ${result.time.format(context)}\nAutomatic return: ${returnTime.format(context)}\nPrice: TZS ${package['price']}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Edit')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm & Track')),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrackingScreen(
              title: 'Tour Tracking',
              from: result.pickup,
              to: package['title'] as String,
              type: 'tour',
              statusLabel: 'Tour assigned',
            ),
          ),
        );
      }
    } finally {
      pickup.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tour Packages')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: packages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final package = packages[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: Text(package['icon'] as String, style: const TextStyle(fontSize: 36)),
              title: Text(package['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${package['hours']} hours · TZS ${package['price']}'),
              trailing: ElevatedButton(onPressed: () => _configure(context, package), child: const Text('Select')),
            ),
          );
        },
      ),
    );
  }
}

class _TourBooking {
  final String pickup;
  final int tourists;
  final TimeOfDay time;
  const _TourBooking(this.pickup, this.tourists, this.time);
}
