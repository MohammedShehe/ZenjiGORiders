import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/api/rider_api.dart';
import '../../core/utils/tanzania_time.dart';
import '../../core/widgets/places_autocomplete_field.dart';
import '../../providers/app_provider.dart';

class ParcelScreen extends StatefulWidget {
  const ParcelScreen({super.key});
  @override
  State<ParcelScreen> createState() => _ParcelScreenState();
}

class _ParcelScreenState extends State<ParcelScreen> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _receiverCtrl = TextEditingController();
  double? _fromLat, _fromLng, _toLat, _toLng;
  double weight = 1;
  DateTime? _pickupDate;
  TimeOfDay? _pickupTime;
  bool loading = false;
  Map<String, dynamic>? _success;
  List<Map<String, dynamic>> _myParcels = [];

  @override
  void initState() {
    super.initState();
    _loadParcels();
    WidgetsBinding.instance.addPostFrameCallback((_) => _useCurrentPickup());
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _receiverCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadParcels() async {
    try {
      final list = await RiderApi.parcels();
      if (!mounted) return;
      setState(() {
        _myParcels = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (_) {}
  }

  Future<void> _useCurrentPickup() async {
    try {
      final app = context.read<AppProvider>();
      if (app.currentLat != 0 && app.currentAddress.isNotEmpty) {
        setState(() {
          _fromCtrl.text = app.currentAddress;
          _fromLat = app.currentLat;
          _fromLng = app.currentLng;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _fromCtrl.text = 'Current location';
        _fromLat = pos.latitude;
        _fromLng = pos.longitude;
      });
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final now = TanzaniaTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _pickupDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (d != null) setState(() => _pickupDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _pickupTime ?? TimeOfDay.now());
    if (t != null) setState(() => _pickupTime = t);
  }

  void _resetForm() {
    _toCtrl.clear();
    _descCtrl.clear();
    _phoneCtrl.clear();
    _receiverCtrl.clear();
    _toLat = _toLng = null;
    _pickupDate = null;
    _pickupTime = null;
    weight = 1;
    _useCurrentPickup();
  }

  Future<void> _book() async {
    if (_fromLat == null || _toLat == null ||
        _fromCtrl.text.trim().isEmpty || _toCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty ||
        _pickupDate == null || _pickupTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select pickup & delivery, description, phone, date and time.')),
      );
      return;
    }
    final pickupAt = DateTime(
      _pickupDate!.year, _pickupDate!.month, _pickupDate!.day,
      _pickupTime!.hour, _pickupTime!.minute,
    );
    setState(() => loading = true);
    try {
      final result = await RiderApi.createParcel({
        'pickupAddress': _fromCtrl.text.trim(),
        'pickupLat': _fromLat,
        'pickupLng': _fromLng,
        'deliveryAddress': _toCtrl.text.trim(),
        'deliveryLat': _toLat,
        'deliveryLng': _toLng,
        'description': _descCtrl.text.trim(),
        'weightKg': weight,
        'pickupAt': pickupAt.toIso8601String().replaceFirst('T', ' ').substring(0, 19),
        'receiverPhone': _phoneCtrl.text.trim(),
        'receiverName': _receiverCtrl.text.trim(),
      });
      if (!mounted) return;
      _resetForm();
      setState(() {
        _success = {
          'code': (result['code'] ?? result['parcel_code'] ?? result['id'] ?? '').toString(),
          'from': _fromCtrl.text.isEmpty ? 'Pickup set' : _fromCtrl.text,
          'to': 'Delivery set',
          'when': TanzaniaTime.format(pickupAt),
          'rawFrom': result,
        };
        loading = false;
      });
      await _loadParcels();
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parcel booked')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, size: 72, color: Colors.green),
              ),
              const SizedBox(height: 24),
              const Text('Parcel booked successfully', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                'Reference: ${_success!['code']}\nScheduled: ${_success!['when']}\n\nOnline drivers can accept this delivery.',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.4),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => setState(() => _success = null),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Book another parcel'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Back to home'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Send a Parcel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Pickup location', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          PlacesAutocompleteField(
            controller: _fromCtrl,
            hint: 'Search pickup in Tanzania…',
            icon: Icons.my_location,
            onUseCurrentLocation: _useCurrentPickup,
            onSelected: (s) => setState(() {
              _fromCtrl.text = s.displayName;
              _fromLat = s.lat;
              _fromLng = s.lng;
            }),
          ),
          const SizedBox(height: 16),
          const Text('Delivery location', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          PlacesAutocompleteField(
            controller: _toCtrl,
            hint: 'Search delivery in Tanzania…',
            onSelected: (s) => setState(() {
              _toCtrl.text = s.displayName;
              _toLat = s.lat;
              _toLng = s.lng;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'What are you sending?', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _receiverCtrl,
            decoration: const InputDecoration(labelText: 'Receiver name (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Receiver phone', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Text('Weight: ${weight.toStringAsFixed(1)} kg'),
          Slider(value: weight, min: 0.5, max: 30, divisions: 59, onChanged: (v) => setState(() => weight = v)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_pickupDate == null
                      ? 'Pickup date'
                      : TanzaniaTime.format(_pickupDate, withTime: false)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(_pickupTime == null ? 'Pickup time' : _pickupTime!.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: loading ? null : _book,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Book parcel'),
          ),
          const SizedBox(height: 28),
          const Text('My parcels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_myParcels.isEmpty)
            const Text('No parcels yet.')
          else
            ..._myParcels.map((p) {
              final status = (p['status'] ?? 'pending').toString();
              final when = TanzaniaTime.formatString((p['pickup_at'] ?? p['pickupAt'] ?? '').toString());
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text((p['parcel_code'] ?? p['code'] ?? 'Parcel').toString()),
                  subtitle: Text(
                    '${p['pickup_address'] ?? ''} → ${p['delivery_address'] ?? ''}\nWhen: $when · Status: $status',
                  ),
                  isThreeLine: true,
                ),
              );
            }),
        ],
      ),
    );
  }
}
