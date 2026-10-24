import 'package:flutter/material.dart';
import '../../core/api/rider_api.dart';
import '../../core/utils/money.dart';
import '../../core/utils/tanzania_time.dart';
import '../../core/widgets/places_autocomplete_field.dart';

class TourPackagesScreen extends StatefulWidget {
  const TourPackagesScreen({super.key});

  @override
  State<TourPackagesScreen> createState() => _TourPackagesScreenState();
}

class _TourPackagesScreenState extends State<TourPackagesScreen> {
  bool _loading = true;
  String? _error;
  bool _booking = false;
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    final list = value is List
        ? value
        : value is Map && value['packages'] is List
            ? value['packages'] as List
            : value is Map && value['tours'] is List
                ? value['tours'] as List
                : const [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([RiderApi.tourPackages(), RiderApi.tours()]);
      if (!mounted) return;
      setState(() {
        _packages = _asList(results[0]);
        _bookings = _asList(results[1]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _text(Map<String, dynamic> item, List<String> keys, [String fallback = '—']) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) return value.toString();
    }
    return fallback;
  }

  Future<void> _book(Map<String, dynamic> package) async {
    final id = (package['id'] ?? package['_id'] ?? package['packageId'] ?? '').toString();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This tour package has no booking ID from the server.')),
      );
      return;
    }

    final pickupCtrl = TextEditingController();
    double? pickupLat, pickupLng;
    DateTime? date;
    TimeOfDay? time;
    int tourists = 1;
    final maxTourists = int.tryParse(_text(package, ['max_tourists', 'maxTourists'], '4')) ?? 4;
    final basePrice = double.tryParse(_text(package, ['base_price', 'price', 'fare', 'amount'], '0')) ?? 0;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              final total = basePrice * tourists;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _text(package, ['name', 'title', 'packageName'], 'Book tour'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(_text(package, ['description'], ''), style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 16),
                    const Text('Pickup location', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    PlacesAutocompleteField(
                      controller: pickupCtrl,
                      hint: 'Where should we pick you up?',
                      onSelected: (s) {
                        setLocal(() {
                          pickupCtrl.text = s.displayName;
                          pickupLat = s.lat;
                          pickupLng = s.lng;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: date ?? now.add(const Duration(days: 1)),
                                firstDate: now,
                                lastDate: now.add(const Duration(days: 180)),
                              );
                              if (d != null) setLocal(() => date = d);
                            },
                            icon: const Icon(Icons.calendar_today),
                            label: Text(date == null
                                ? 'Tour date'
                                : '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: ctx,
                                initialTime: time ?? const TimeOfDay(hour: 9, minute: 0),
                              );
                              if (t != null) setLocal(() => time = t);
                            },
                            icon: const Icon(Icons.access_time),
                            label: Text(time == null ? 'Time' : time!.format(ctx)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Tourists'),
                        const Spacer(),
                        IconButton(
                          onPressed: tourists > 1 ? () => setLocal(() => tourists--) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$tourists / $maxTourists', style: const TextStyle(fontWeight: FontWeight.w700)),
                        IconButton(
                          onPressed: tourists < maxTourists ? () => setLocal(() => tourists++) : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Total: ${formatTzs(total)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (pickupCtrl.text.trim().isEmpty || pickupLat == null || date == null || time == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Select pickup from suggestions, date and time.')),
                          );
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Confirm booking'),
                    ),
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (submitted != true || !mounted) return;

    final pickupAt = DateTime(
      date!.year, date!.month, date!.day,
      time!.hour, time!.minute,
    );

    setState(() => _booking = true);
    try {
      await RiderApi.bookTour({
        'packageId': id,
        'tourPackageId': id,
        'tourists': tourists,
        'pickupLocation': pickupCtrl.text.trim(),
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'pickupAt': pickupAt.toIso8601String().replaceFirst('T', ' ').substring(0, 19),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tour booked. Drivers can accept this job with the scheduled date/time.')),
      );
      try {
        final bookings = await RiderApi.tours();
        if (mounted) setState(() => _bookings = _asList(bookings));
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tour Packages'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cloud_off_outlined, size: 42),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('Available packages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      if (_packages.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('No tour packages are currently available.'),
                        )
                      else
                        ..._packages.map((item) {
                          final price = item['base_price'] ?? item['price'] ?? item['fare'] ?? item['amount'];
                          final priceNum = double.tryParse(price?.toString() ?? '');
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              leading: const Icon(Icons.explore_outlined, size: 32),
                              title: Text(_text(item, ['name', 'title', 'packageName']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text([
                                  _text(item, ['description'], ''),
                                  if (priceNum != null) formatTzs(priceNum),
                                ].where((e) => e.toString().trim().isNotEmpty).join('\n')),
                              ),
                              isThreeLine: true,
                              trailing: _booking
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.chevron_right),
                              onTap: _booking ? null : () => _book(item),
                            ),
                          );
                        }),
                      const SizedBox(height: 24),
                      const Text('My tour bookings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      if (_bookings.isEmpty)
                        const Text('No bookings yet.')
                      else
                        ..._bookings.map((b) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.event_available),
                              title: Text(_text(b, ['package_name', 'name', 'booking_code'], 'Tour')),
                              subtitle: Text(
                                'When: ${TanzaniaTime.formatString(_text(b, ['pickup_at', 'pickupAt'], ''))}\n'
                                'Pickup: ${_text(b, ['pickup_location', 'pickupLocation'])}\n'
                                'Status: ${_text(b, ['status'], 'pending')} · ${formatTzs(double.tryParse(_text(b, ['total_amount', 'totalAmount'], '0')))}',
                              ),
                              isThreeLine: true,
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
