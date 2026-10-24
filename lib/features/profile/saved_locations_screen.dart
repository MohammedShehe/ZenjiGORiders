import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/app_provider.dart';
import '../../core/widgets/places_autocomplete_field.dart';

class SavedLocationsScreen extends StatelessWidget {
  const SavedLocationsScreen({super.key});

  IconData _icon(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'work':
        return Icons.work_outline;
      case 'hotel':
        return Icons.hotel_outlined;
      default:
        return Icons.location_on_outlined;
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
      try {
        await context.read<AppProvider>().removeSavedLocation(location.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location removed.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      }
    }
  }

  Future<void> _add(BuildContext context) async {
    // Full-screen page avoids Places suggestions getting stuck inside AlertDialog
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _AddSavedLocationPage()),
    );
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

class _AddSavedLocationPage extends StatefulWidget {
  const _AddSavedLocationPage();
  @override
  State<_AddSavedLocationPage> createState() => _AddSavedLocationPageState();
}

class _AddSavedLocationPageState extends State<_AddSavedLocationPage> {
  final _addressCtrl = TextEditingController();
  String _label = 'Home';
  double? _lat;
  double? _lng;
  String _display = '';
  bool _saving = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_lat == null || _lng == null || _display.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a place from the suggestions first.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final user = context.read<AppProvider>().user;
      await context.read<AppProvider>().addSavedLocation(
        SavedLocationModel(
          id: '',
          label: _label,
          address: _display,
          island: user?.island ?? '',
          region: user?.region ?? '',
          district: user?.district ?? '',
          ward: user?.ward ?? '',
          lat: _lat,
          lng: _lng,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location saved.')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add saved location')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _label,
            decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder()),
            items: const ['Home', 'Work', 'Hotel', 'Other']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _label = v);
            },
          ),
          const SizedBox(height: 16),
          const Text('Search location', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          PlacesAutocompleteField(
            controller: _addressCtrl,
            hint: 'Search in Tanzania…',
            onSelected: (sel) {
              setState(() {
                _lat = sel.lat;
                _lng = sel.lng;
                _display = sel.displayName;
                _addressCtrl.text = sel.displayName;
              });
            },
          ),
          if (_display.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Selected: $_display', style: const TextStyle(color: Colors.green)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save location'),
          ),
        ],
      ),
    );
  }
}
