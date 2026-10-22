import 'package:flutter/material.dart';
import '../../core/api/rider_api.dart';

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
    final list = value is List ? value : value is Map && value['packages'] is List
        ? value['packages'] as List
        : value is Map && value['tours'] is List
            ? value['tours'] as List
            : const [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
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
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _book(Map<String, dynamic> package) async {
    final id = (package['id'] ?? package['_id'] ?? package['packageId'] ?? '').toString();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This tour package has no booking ID from the server.')),
      );
      return;
    }
    setState(() => _booking = true);
    try {
      await RiderApi.bookTour({'packageId': id});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tour booking submitted.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  String _text(Map<String, dynamic> item, List<String> keys, [String fallback = '—']) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) return value.toString();
    }
    return fallback;
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
                          child: Text('No tour packages are currently available from the server.'),
                        )
                      else
                        ..._packages.map((item) {
                          final price = item['price'] ?? item['fare'] ?? item['amount'];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              leading: const Icon(Icons.explore_outlined, size: 32),
                              title: Text(_text(item, ['name', 'title', 'packageName']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text([
                                  _text(item, ['description'], ''),
                                  if (price != null) 'Price: $price',
                                ].where((e) => e.isNotEmpty).join('\n')),
                              ),
                              trailing: _booking
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                  : ElevatedButton(onPressed: () => _book(item), child: const Text('Book')),
                            ),
                          );
                        }),
                      const SizedBox(height: 24),
                      const Text('My bookings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      if (_bookings.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No tour bookings yet.'),
                        )
                      else
                        ..._bookings.map((item) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.event_available_outlined),
                            title: Text(_text(item, ['packageName', 'name', 'title'])),
                            subtitle: Text(_text(item, ['status', 'bookingStatus'])),
                            trailing: Text(_text(item, ['createdAt', 'created_at', 'date'], ''), style: Theme.of(context).textTheme.bodySmall),
                          ),
                        )),
                    ],
                  ),
                ),
    );
  }
}
