import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_provider.dart';

class TrackingScreen extends StatefulWidget {
  final String title;
  final String from;
  final String to;
  final String type;
  final String statusLabel;

  const TrackingScreen({
    super.key,
    required this.title,
    required this.from,
    required this.to,
    required this.type,
    required this.statusLabel,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Timer? _timer;
  int _progress = 12;
  final LatLng _pickup = const LatLng(-6.1659, 39.2026);
  final LatLng _destination = const LatLng(-6.1700, 39.2100);
  late LatLng _vehicle;

  @override
  void initState() {
    super.initState();
    _vehicle = _pickup;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _progress >= 100) return;
      setState(() {
        _progress = (_progress + 4).clamp(0, 100);
        final t = _progress / 100;
        _vehicle = LatLng(
          _pickup.latitude + (_destination.latitude - _pickup.latitude) * t,
          _pickup.longitude + (_destination.longitude - _pickup.longitude) * t,
        );
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _stage {
    if (_progress < 25) return widget.statusLabel;
    if (_progress < 50) return 'On the way to pickup';
    if (_progress < 90) {
      if (widget.type == 'parcel') return 'Parcel is on the way';
      if (widget.type == 'tour') return 'Tour in progress';
      return 'Trip in progress';
    }
    return _progress < 100 ? 'Arriving at destination' : 'Completed';
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppProvider>().isDark;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: _vehicle, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: dark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.zenjigo.riders',
              ),
              MarkerLayer(
                markers: [
                  Marker(point: _pickup, width: 42, height: 42, child: const Icon(Icons.my_location, color: AppColors.brightGreen, size: 34)),
                  Marker(point: _destination, width: 42, height: 42, child: const Icon(Icons.location_on, color: AppColors.sunsetOrange, size: 38)),
                  Marker(
                    point: _vehicle,
                    width: 48,
                    height: 48,
                    child: CircleAvatar(
                      backgroundColor: dark ? AppColors.aquaGreen : AppColors.oceanTeal,
                      child: Icon(widget.type == 'parcel' ? Icons.local_shipping : Icons.directions_car, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 18)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(_stage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                      Text('$_progress%', style: TextStyle(color: dark ? AppColors.aquaGreen : AppColors.oceanTeal, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: _progress / 100, minHeight: 7, borderRadius: BorderRadius.circular(8)),
                  const SizedBox(height: 18),
                  _point(Icons.my_location, 'Pickup', widget.from, dark),
                  const SizedBox(height: 10),
                  _point(Icons.location_on, 'Destination', widget.to, dark),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tracking link is ready to share.'))),
                          icon: const Icon(Icons.share_location),
                          label: const Text('Share Tracking'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.done),
                          label: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _point(IconData icon, String label, String value, bool dark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: dark ? AppColors.aquaGreen : AppColors.oceanTeal),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
