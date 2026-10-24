import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:provider/provider.dart';
import '../../core/map/map_motion.dart';
import '../../core/map/map_style.dart';
import '../../core/map/map_widgets.dart';
import '../../core/map/route_utils.dart';
import '../../core/map/trip_map.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/directions_service.dart';
import '../../providers/app_provider.dart';

/// Simple live-tracking view for parcels / tours: a real styled map, the road route between
/// the two addresses and a vehicle that moves along it.
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
  // Stone Town → Mjini Magharibi fallback so the screen is never empty.
  static const _fallbackFrom = gmaps.LatLng(-6.1659, 39.2026);
  static const _fallbackTo = gmaps.LatLng(-6.1700, 39.2100);

  final MovingPoint _vehicle = MovingPoint();
  Timer? _timer;
  gmaps.LatLng? _from;
  gmaps.LatLng? _to;
  RouteTracker? _tracker;
  int _progress = 12;
  double _panelH = 0;

  @override
  void initState() {
    super.initState();
    _resolvePlaces();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vehicle.dispose();
    super.dispose();
  }

  Future<gmaps.LatLng?> _geocode(String address, gmaps.LatLng? fallback) async {
    final q = address.trim();
    if (q.isEmpty) return fallback;
    try {
      final list = await locationFromAddress('$q, Zanzibar, Tanzania').timeout(const Duration(seconds: 6));
      if (list.isNotEmpty) return gmaps.LatLng(list.first.latitude, list.first.longitude);
    } catch (_) {}
    return fallback;
  }

  Future<void> _resolvePlaces() async {
    final results = await Future.wait([
      _geocode(widget.from, _fallbackFrom),
      _geocode(widget.to, _fallbackTo),
    ]);
    if (!mounted) return;
    setState(() {
      _from = results[0];
      _to = results[1];
    });
  }

  void _onRoute(RouteResult r) {
    _tracker = RouteTracker(r.points);
    _vehicle.moveTo(_tracker!.pointAt(_tracker!.totalMeters * _progress / 100));
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _progress >= 100 || _tracker == null) return;
      setState(() => _progress = (_progress + 4).clamp(0, 100));
      final p = _tracker!.pointAt(_tracker!.totalMeters * _progress / 100);
      _vehicle.moveTo(p);
    });
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
    final accent = MapUi.accent(dark);
    final mq = MediaQuery.of(context);
    final from = _from, to = _to;

    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: FloatingPill(
            isDark: dark,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          leading: Padding(
            padding: const EdgeInsets.all(5),
            child: MapCircleButton(icon: Icons.arrow_back_rounded, isDark: dark, onTap: () => Navigator.pop(context)),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: from == null || to == null
                  ? const Center(child: CircularProgressIndicator())
                  : TripRouteMap(
                      from: from,
                      to: to,
                      isDark: dark,
                      vehicle: _vehicle,
                      onRoute: _onRoute,
                      padding: EdgeInsets.only(top: mq.padding.top + kToolbarHeight, bottom: _panelH),
                    ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 560, maxHeight: mq.size.height * 0.6),
                child: SizeReporter(
                  onHeight: (h) {
                    if ((h - _panelH).abs() > 1 && mounted) setState(() => _panelH = h);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: MapUi.panelColor(dark),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .16), blurRadius: 20)],
                    ),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(_stage, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                                Text('$_progress%', style: TextStyle(color: accent, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(value: _progress / 100, minHeight: 7, color: accent, backgroundColor: accent.withValues(alpha: 0.15)),
                            ),
                            const SizedBox(height: 16),
                            _point(Icons.my_location_rounded, 'Pickup', widget.from, dark),
                            const SizedBox(height: 10),
                            _point(Icons.location_on_rounded, 'Destination', widget.to, dark),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tracking link is ready to share.'))),
                                    icon: const Icon(Icons.share_location_rounded, size: 18),
                                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Share')),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.done_rounded, size: 18),
                                    label: const Text('Close'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _point(IconData icon, String label, String value, bool dark) {
    final muted = MapUi.textSecondary(dark);
    return Row(
      children: [
        Icon(icon, size: 20, color: icon == Icons.location_on_rounded ? AppColors.coral : MapUi.accent(dark)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted)),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
