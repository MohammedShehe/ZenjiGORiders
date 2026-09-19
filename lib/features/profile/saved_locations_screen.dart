import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/app_provider.dart';

class SavedLocationsScreen extends StatelessWidget {
  const SavedLocationsScreen({super.key});

  IconData _icon(String label) {
    switch (label.toLowerCase()) {
      case 'home': return Icons.home_outlined;
      case 'work': return Icons.work_outline;
      case 'hotel': return Icons.hotel_outlined;
      default: return Icons.location_on_outlined;
    }
  }

  Future<void> _remove(BuildContext context, SavedLocationModel location) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove location?'),
        content: Text('Remove ${location.label} from saved locations?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      context.read<AppProvider>().removeSavedLocation(location.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location removed.')));
    }
  }

  Future<void> _add(BuildContext context) async {
    final address = TextEditingController();
    String label = 'Home';
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Add Saved Location'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: label,
                  decoration: const InputDecoration(labelText: 'Label'),
                  items: const ['Home', 'Work', 'Hotel', 'Other']
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) => setDialogState(() => label = value ?? 'Home'),
                ),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (address.text.trim().isNotEmpty) Navigator.pop(dialogContext, true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (saved == true && context.mounted) {
        final user = context.read<AppProvider>().user;
        if (user != null) {
          context.read<AppProvider>().addSavedLocation(
            SavedLocationModel(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              label: label,
              address: address.text.trim(),
              island: user.island,
              region: user.region,
              district: user.district,
              ward: user.ward,
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location saved.')));
        }
      }
    } finally {
      address.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = context.watch<AppProvider>().user?.savedLocations ?? const <SavedLocationModel>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Locations'),
        actions: [IconButton(onPressed: () => _add(context), icon: const Icon(Icons.add_location_alt))],
      ),
      body: locations.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off_outlined, size: 60),
                  const SizedBox(height: 12),
                  const Text('No saved locations.'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _add(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Location'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: locations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final location = locations[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(_icon(location.label))),
                    title: Text(location.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(location.address),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _remove(context, location),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
