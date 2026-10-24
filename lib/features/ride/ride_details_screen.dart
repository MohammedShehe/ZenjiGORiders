import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/map/map_markers.dart';
import '../../core/map/map_motion.dart';
import '../../core/map/map_style.dart';
import '../../core/map/map_widgets.dart';
import '../../core/map/route_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/money.dart';
import '../../core/utils/directions_service.dart';
import '../../core/utils/tanzania_time.dart';
import '../../models/ride_model.dart';
import '../../core/api/rider_api.dart';
import '../../providers/app_provider.dart';
import '../chat/chat_list_screen.dart';
import 'ride_receipt_screen.dart';

/// Live booking / active-ride screen.
/// Status flow: searching → accepted → arriving → arrived → started → completed
class RideDetailsScreen extends StatefulWidget {
  final RideModel? existingRide; // if resuming active ride
  final String? rideType;
  final String? from;
  final String? to;
  final double? fare;
  final int? eta;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;
  final String? paymentMethod;
  final String? promoCode;
  final double? discount;

  const RideDetailsScreen({
    super.key,
    this.existingRide,
    this.rideType,
    this.from,
    this.to,
    this.fare,
    this.eta,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
    this.paymentMethod,
    this.promoCode,
    this.discount,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  late RideModel _ride;
  Timer? _statusTimer;
  Timer? _pulseTimer;
  bool _noDriver = false;
  int _searchSeconds = 0;
  gmaps.GoogleMapController? _mapCtrl;

  // --- live map state -------------------------------------------------------------
  final MovingPoint _driver = MovingPoint();
  final ValueNotifier<double> _pulse = ValueNotifier<double>(0);
  MapMarkerSet? _markerSet;
  RouteResult? _tripRoute; // pickup -> destination
  RouteTracker? _tripTracker;
  RouteTracker? _guideTracker;
  String _guideKey = '';
  DateTime _guideFetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _guideSeq = 0;
  List<gmaps.LatLng> _remaining = const [];
  List<gmaps.LatLng> _travelled = const [];
  double _remainingMeters = 0;
  double _avgSpeed = 6.5; // m/s, refined from the route
  bool _autoFollow = true;
  gmaps.LatLng? _lastFitDriver;
  String _lastFitStatus = '';
  double _panelH = 0;

  bool get _inTrip => _ride.status == 'started' || _ride.status == 'in_progress';
  bool get _hasDriverFix => _ride.driver != null && _ride.driver!.lat != 0 && _ride.driver!.lng != 0;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    if (widget.existingRide != null) {
      _ride = widget.existingRide!;
      _loadTripRoute();
      if (_ride.isActive) _continueLifecycle();
    } else {
      // Temporary placeholder until API returns
      _ride = RideModel(
        id: 'pending',
        rideType: widget.rideType ?? 'boda',
        fromAddress: widget.from ?? app.currentAddress,
        toAddress: widget.to ?? '',
        fromLat: widget.fromLat ?? app.currentLat,
        fromLng: widget.fromLng ?? app.currentLng,
        toLat: widget.toLat ?? app.currentLat,
        toLng: widget.toLng ?? app.currentLng,
        estimatedFare: widget.fare ?? 0,
        etaMinutes: widget.eta ?? 0,
        status: 'searching',
        paymentMethod: widget.paymentMethod ?? 'cash',
      );
      _loadTripRoute();
      _bookLive();
    }
    _syncPulse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_markerSet == null) {
      MapMarkers.load(View.of(context).devicePixelRatio).then((set) {
        if (mounted) setState(() => _markerSet = set);
      });
    }
  }

  /// Pulse rings only run while we are searching for a driver.
  void _syncPulse() {
    final searching = _ride.status == 'searching' && !_noDriver;
    if (searching && _pulseTimer == null) {
      _pulseTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        _pulse.value = PulseCircles.nextPhase(_pulse.value);
      });
    } else if (!searching && _pulseTimer != null) {
      _pulseTimer!.cancel();
      _pulseTimer = null;
    }
  }

  Future<void> _loadTripRoute() async {
    if (_ride.fromLat == 0 || _ride.toLat == 0) return;
    final result = await DirectionsService.fetch(
      originLat: _ride.fromLat,
      originLng: _ride.fromLng,
      destLat: _ride.toLat,
      destLng: _ride.toLng,
    );
    if (!mounted) return;
    setState(() {
      _tripRoute = result;
      _tripTracker = RouteTracker(result.points);
      if (result.durationSeconds > 0 && result.distanceMeters > 0) {
        _avgSpeed = (result.distanceMeters / result.durationSeconds).clamp(3.0, 20.0).toDouble();
      }
    });
    _recomputeGuidance();
    _fitView(force: true);
  }

  /// Called after every poll that may have moved the driver or changed the status.
  void _onRideUpdated() {
    _syncPulse();
    if (!_hasDriverFix) return;
    final d = _ride.driver!;
    final raw = gmaps.LatLng(d.lat, d.lng);

    // Glide along the road: snap to whichever route the driver is following.
    var target = raw;
    final tracker = _guideTracker ?? (_inTrip ? _tripTracker : null);
    if (tracker != null && tracker.isUsable) {
      final snap = tracker.snap(raw);
      if (snap != null && snap.offset < 35) target = snap.point;
    }
    _driver.moveTo(target);
    _refreshGuidance(raw);
    _recomputeGuidance();
    if (_autoFollow) _fitView();
  }

  /// Decides whether the current guidance route still fits the driver or must be re-fetched.
  Future<void> _refreshGuidance(gmaps.LatLng pos) async {
    final key = _inTrip ? 'dest' : 'pickup';
    if (_guideKey.isNotEmpty && _guideKey != key && !(_inTrip && _guideKey == 'trip')) {
      _guideKey = '';
      _guideTracker = null;
    }
    final tLat = _inTrip ? _ride.toLat : _ride.fromLat;
    final tLng = _inTrip ? _ride.toLng : _ride.fromLng;
    if (tLat == 0 || tLng == 0) return;

    // During the trip, the planned pickup->destination route is reused while the driver is on it.
    if (_inTrip && _tripTracker != null && _tripTracker!.isUsable) {
      final snap = _tripTracker!.snap(pos);
      if (snap != null && snap.offset <= 70) {
        if (_guideKey != 'trip') {
          _guideKey = 'trip';
          _guideTracker = _tripTracker;
        }
        return;
      }
    }
    if (_guideKey == key && _guideTracker != null) {
      final snap = _guideTracker!.snap(pos);
      if (snap != null && snap.offset <= 70) return; // still on the guidance route
      if (DateTime.now().difference(_guideFetchedAt).inSeconds < 12) return; // throttle re-routing
    }
    _guideFetchedAt = DateTime.now();
    final seq = ++_guideSeq;
    final result = await DirectionsService.fetch(
      originLat: pos.latitude,
      originLng: pos.longitude,
      destLat: tLat,
      destLng: tLng,
    );
    if (!mounted || seq != _guideSeq) return;
    _guideKey = key;
    _guideTracker = RouteTracker(result.points);
    if (result.durationSeconds > 0 && result.distanceMeters > 0) {
      _avgSpeed = (result.distanceMeters / result.durationSeconds).clamp(3.0, 20.0).toDouble();
    }
    _recomputeGuidance();
  }

  /// Splits the active route into "already driven" and "still to go" and updates ETA numbers.
  void _recomputeGuidance() {
    if (!mounted) return;
    var remaining = const <gmaps.LatLng>[];
    var travelled = const <gmaps.LatLng>[];
    var remainingMeters = 0.0;

    final tracker = _guideTracker ?? (_inTrip ? _tripTracker : null);
    final pos = _hasDriverFix ? gmaps.LatLng(_ride.driver!.lat, _ride.driver!.lng) : null;
    if (tracker != null && tracker.isUsable && pos != null) {
      final snap = tracker.snap(pos);
      if (snap != null) {
        remaining = tracker.sliceFrom(snap.distanceAlong);
        remainingMeters = (tracker.totalMeters - snap.distanceAlong).clamp(0.0, double.infinity).toDouble();
        if (_guideKey == 'trip' || (_inTrip && identical(tracker, _tripTracker))) {
          travelled = [...tracker.points.sublist(0, snap.segment + 1), snap.point];
        }
      }
    } else if (!_hasDriverFix && _tripTracker != null && _tripTracker!.isUsable) {
      remaining = _tripTracker!.points;
      remainingMeters = _tripTracker!.totalMeters;
    }
    setState(() {
      _remaining = remaining;
      _travelled = travelled;
      _remainingMeters = remainingMeters;
    });
  }

  int? get _etaMinutes {
    if (_remainingMeters <= 0) return null;
    return (_remainingMeters / _avgSpeed / 60).ceil().clamp(1, 999);
  }

  Future<void> _fitView({bool force = false}) async {
    final ctrl = _mapCtrl;
    if (ctrl == null) return;
    final pts = <gmaps.LatLng>[];
    final pickup = gmaps.LatLng(_ride.fromLat, _ride.fromLng);
    final dest = gmaps.LatLng(_ride.toLat, _ride.toLng);
    final dpos = _driver.position;

    if (_ride.status == 'searching') {
      if (_tripRoute != null) {
        pts.addAll(_tripRoute!.points);
      } else {
        pts.add(pickup);
      }
    } else if (_inTrip) {
      if (dpos != null) pts.add(dpos);
      pts.add(dest);
    } else {
      if (dpos != null) pts.add(dpos);
      pts.add(pickup);
    }
    if (pts.isEmpty || (pts.first.latitude == 0 && pts.first.longitude == 0)) return;

    // Avoid camera jitter: only re-fit when the driver moved noticeably or the phase changed.
    if (!force && dpos != null && _lastFitDriver != null && _lastFitStatus == _ride.status) {
      if (GeoUtils.distanceMeters(_lastFitDriver!, dpos) < 25) return;
    }
    _lastFitDriver = dpos;
    _lastFitStatus = _ride.status;

    final bounds = GeoUtils.boundsOf(pts);
    if (bounds == null) return;
    try {
      if (pts.length == 1) {
        await ctrl.animateCamera(gmaps.CameraUpdate.newLatLngZoom(pts.first, 15.5));
      } else {
        await ctrl.animateCamera(gmaps.CameraUpdate.newLatLngBounds(bounds, 56));
      }
    } catch (_) {}
  }

  Future<void> _bookLive() async {
    final app = context.read<AppProvider>();
    try {
      final ride = await app.createRide(
        rideType: widget.rideType ?? 'boda',
        fromAddress: widget.from ?? app.currentAddress,
        toAddress: widget.to ?? '',
        estimatedFare: widget.fare ?? 0,
        etaMinutes: widget.eta ?? 0,
        fromLat: widget.fromLat,
        fromLng: widget.fromLng,
        toLat: widget.toLat,
        toLng: widget.toLng,
        paymentMethod: widget.paymentMethod,
        promoCode: widget.promoCode,
        discount: widget.discount,
      );
      if (!mounted) return;
      setState(() => _ride = ride);
      if (_tripRoute == null) _loadTripRoute();
      _startSearch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _pulseTimer?.cancel();
    _driver.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _startSearch() {
    _statusTimer?.cancel();
    _searchSeconds = 0;
    _pollServerRide();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollServerRide());
  }

  Future<void> _pollServerRide() async {
    if (!mounted || _ride.id == 'pending') return;
    try {
      final payload = await RiderApi.getRide(_ride.id);
      final raw = payload['ride'] is Map ? Map<String, dynamic>.from(payload['ride']) : payload;
      final status = (raw['status'] ?? _ride.status).toString().toLowerCase();
      final driverRaw = raw['driver'] is Map ? Map<String, dynamic>.from(raw['driver']) : null;
      DriverModel? driver = _ride.driver;
      if (driverRaw != null) {
        final lat = double.tryParse((driverRaw['lat'] ?? driverRaw['latitude'] ?? '').toString()) ?? driver?.lat ?? 0;
        final lng = double.tryParse((driverRaw['lng'] ?? driverRaw['longitude'] ?? '').toString()) ?? driver?.lng ?? 0;
        driver = DriverModel(
          id: (driverRaw['id'] ?? driverRaw['_id'] ?? driver?.id ?? '').toString(),
          name: (driverRaw['fullName'] ?? driverRaw['name'] ?? driver?.name ?? 'Driver').toString(),
          phone: (driverRaw['phone'] ?? driver?.phone ?? '').toString(),
          photoUrl: (driverRaw['photoUrl'] ?? driverRaw['photo_url'] ?? driver?.photoUrl ?? '').toString(),
          vehicleNumber: (driverRaw['plateNumber'] ?? driverRaw['vehicleNumber'] ?? driver?.vehicleNumber ?? '').toString(),
          vehicleType: (driverRaw['vehicleType'] ?? driverRaw['rideType'] ?? driver?.vehicleType ?? _ride.rideType).toString(),
          rating: double.tryParse((driverRaw['rating'] ?? driver?.rating ?? 0).toString()) ?? 0,
          totalRides: int.tryParse((driverRaw['totalRides'] ?? driver?.totalRides ?? 0).toString()) ?? 0,
          lat: lat,
          lng: lng,
        );
      }
      var next = _ride.copyWith(status: status, driver: driver);
      try {
        final track = await RiderApi.track(_ride.id);
        final lat = double.tryParse((track['driverLat'] ?? track['driver_lat'] ?? '').toString());
        final lng = double.tryParse((track['driverLng'] ?? track['driver_lng'] ?? '').toString());
        if (driver != null && lat != null && lng != null) next = next.copyWith(driver: driver.copyWith(lat: lat, lng: lng));
      } catch (_) { /* Tracking can be unavailable before a driver is assigned. */ }
      if (!mounted) return;
      final wasCompleted = _ride.status == 'completed';
      setState(() {
        _ride = next;
        _searchSeconds += 5;
        _noDriver = false;
      });
      context.read<AppProvider>().updateActiveRide(_ride);
      _onRideUpdated();
      if (status == 'completed' && !wasCompleted && _ride.rating == null) {
        _statusTimer?.cancel();
        await _showRatingAndComplete();
      } else if (status == 'cancelled' || status == 'completed') {
        _statusTimer?.cancel();
      }
    } catch (_) {
      // Keep the current screen responsive during transient network failures; retry next poll.
    }
  }

  void _continueLifecycle() {
    if (_ride.isActive) _startSearch();
  }

  void _confirmPickup() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share your trip PIN with the driver. The driver will start the trip in the app.')),
    );
  }

  Future<void> _showRatingAndComplete() async {
    int rating = 5;
    final feedbackCtrl = TextEditingController();
    double tip = 0;
    final app = context.read<AppProvider>();

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: app.isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  app.t('How was your trip?', 'Safari yako ilikuwa aje?'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _ride.driver?.name ?? 'Driver',
                  style: TextStyle(
                    color: app.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return IconButton(
                      onPressed: () => setSheet(() => rating = i + 1),
                      icon: Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        color: AppColors.sunsetOrange,
                        size: 36,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feedbackCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: app.t('Optional feedback', 'Maoni (si lazima)'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(app.t('Add a tip?', 'Ongeza tip?'), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [0.0, 500.0, 1000.0, 2000.0].map((v) {
                    return ChoiceChip(
                      label: Text(v == 0 ? app.t('No tip', 'Hakuna tip') : formatTzs(v)),
                      selected: tip == v,
                      onSelected: (_) => setSheet(() => tip = v),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, {
                      'rating': rating,
                      'feedback': feedbackCtrl.text.trim(),
                      'tip': tip,
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brightGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(app.t('Submit & Finish', 'Wasilisha & Maliza')),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
    if (!mounted) return;

    final r = (result?['rating'] as int?) ?? 5;
    final fb = result?['feedback'] as String?;
    final tp = (result?['tip'] as double?) ?? 0;

    try {
      await RiderApi.rate(_ride.id, r, feedback: fb?.isNotEmpty == true ? fb : null, tip: tp > 0 ? tp : null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit rating: ${e.toString().replaceFirst('Exception: ', '')}')));
      return;
    }
    await app.completeActiveRide(finalFare: _ride.estimatedFare, rating: r, feedback: fb, tip: tp);

    // Find the completed ride from history
    final completed = app.rideHistory.isNotEmpty ? app.rideHistory.first : _ride.copyWith(
      status: 'completed',
      rating: r,
      feedback: fb,
      tip: tp,
      completedAt: DateTime.now(),
      finalFare: _ride.estimatedFare,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RideReceiptScreen(ride: completed)),
    );
  }

  Future<void> _cancelRide(AppProvider app) async {
    final reasons = [
      app.t('Driver taking too long', 'Dereva anachukua muda mrefu'),
      app.t('Changed plans', 'Nimebadilisha mipango'),
      app.t('Found another ride', 'Nimepata safari nyingine'),
      app.t('Driver requested cancellation', 'Dereva aliomba kughairi'),
      app.t('Other', 'Nyingine'),
    ];
    String? selected;
    final manual = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(app.t('Cancel Ride', 'Ghairi Safari')),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...reasons.map((r) => RadioListTile<String>(
                      value: r,
                      groupValue: selected,
                      title: Text(r),
                      onChanged: (v) => set(() => selected = v),
                    )),
                if (selected == reasons.last)
                  TextField(
                    controller: manual,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: app.t('Describe the issue', 'Eleza tatizo')),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.t('Back', 'Rudi'))),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () {
                      final reason = selected == reasons.last ? manual.text.trim() : selected!;
                      if (selected == reasons.last && reason.isEmpty) return;
                      Navigator.pop(ctx, reason);
                    },
              child: Text(app.t('Continue', 'Endelea')),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(app.t('Confirm cancellation', 'Thibitisha kughairi')),
        content: Text(app.t('Cancel this ride? Reason: $result', 'Ghairi safari hii? Sababu: $result')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(app.t('Keep Ride', 'Endelea na Safari'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(app.t('Cancel Ride', 'Ghairi Safari'))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      _statusTimer?.cancel();
      try {
        await app.cancelActiveRide(reason: result);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not cancel ride: ${e.toString().replaceFirst('Exception: ', '')}')));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(app.t('Ride cancelled successfully.', 'Safari imeghairiwa kikamilifu.'))),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _reportDriver(AppProvider app) async {
    final reasons = [
      app.t('Unsafe driving', 'Uendeshaji usio salama'),
      app.t('Rude behaviour', 'Tabia mbaya'),
      app.t('Wrong route', 'Njia isiyo sahihi'),
      app.t('Vehicle issue', 'Tatizo la gari'),
      app.t('Other', 'Nyingine'),
    ];
    String? selected;
    final manual = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(app.t('Report Driver', 'Ripoti Dereva')),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...reasons.map((r) => RadioListTile<String>(
                      value: r,
                      groupValue: selected,
                      title: Text(r),
                      onChanged: (v) => set(() => selected = v),
                    )),
                if (selected == reasons.last)
                  TextField(controller: manual, maxLines: 3, decoration: InputDecoration(labelText: app.t('Describe', 'Eleza'))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.t('Cancel', 'Ghairi'))),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () {
                      final reason = selected == reasons.last ? manual.text.trim() : selected!;
                      if (selected == reasons.last && reason.isEmpty) return;
                      Navigator.pop(ctx, reason);
                    },
              child: Text(app.t('Submit Report', 'Tuma Ripoti')),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(app.t('Report submitted', 'Ripoti imetumwa')),
        content: Text(app.t('Thank you. Reason: $result', 'Asante. Sababu: $result')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(app.t('Done', 'Maliza')))],
      ),
    );
  }

  void _retrySearch() {
    setState(() {
      _noDriver = false;
      _searchSeconds = 0;
      _ride = _ride.copyWith(status: 'searching');
    });
    _syncPulse();
    context.read<AppProvider>().updateActiveRide(_ride);
    _startSearch();
  }

  String _statusLabel(AppProvider app) {
    switch (_ride.status) {
      case 'searching':
        return app.t('Finding nearby drivers...', 'Inatafuta madereva karibu...');
      case 'accepted':
        return app.t('Driver accepted · ETA ${_ride.etaMinutes} min', 'Dereva amekubali · ETA ${_ride.etaMinutes} dak');
      case 'arriving':
        return app.t('Driver is on the way', 'Dereva yuko njiani');
      case 'arrived':
        return app.t('Driver has arrived', 'Dereva amefika');
      case 'started':
        return app.t('Trip in progress', 'Safari inaendelea');
      default:
        return _ride.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;
    final mq = MediaQuery.of(context);
    final accent = MapUi.accent(isDark);

    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2)),
      child: Scaffold(
        body: LayoutBuilder(builder: (context, box) {
          final compact = box.maxHeight < 640 || box.maxWidth < 360;
          final wide = box.maxWidth > 600;
          final panelWidth = wide ? 520.0 : box.maxWidth;
          final eta = _etaMinutes;

          return Stack(
            children: [
              // Listener: the moment the rider touches the map we stop auto-framing.
              Listener(
                onPointerDown: (_) {
                  if (_autoFollow) setState(() => _autoFollow = false);
                },
                child: _buildMap(isDark, mq.padding.top + 64, _panelH),
              ),

              // ------------------------------------------------------------ top bar
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.all(compact ? 10 : 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MapCircleButton(
                        icon: Icons.arrow_back_rounded,
                        isDark: isDark,
                        tooltip: app.t('Back', 'Rudi'),
                        onTap: () => Navigator.pop(context), // active ride stays in the provider
                      ),
                      const SizedBox(width: 10),
                      if (_ride.tripPin != null && _ride.tripPin!.isNotEmpty)
                        FloatingPill(
                          isDark: isDark,
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pin_outlined, size: 16, color: accent),
                              const SizedBox(width: 6),
                              Text(
                                'PIN ${_ride.tripPin}',
                                style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.4, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      if (_ride.status != 'searching' && eta != null && _hasDriverFix)
                        Flexible(
                          child: FloatingPill(
                            isDark: isDark,
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$eta min',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: compact ? 16 : 18, color: accent),
                                ),
                                Text(
                                  _inTrip ? app.t('to destination', 'hadi unakokwenda') : app.t('to pickup', 'hadi kukuchukua'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: MapUi.textSecondary(isDark)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ------------------------------------------------------------ map buttons
              Positioned(
                right: compact ? 10 : 14,
                bottom: _panelH + 12,
                child: MapCircleButton(
                  icon: _autoFollow ? Icons.navigation_rounded : Icons.near_me_outlined,
                  isDark: isDark,
                  tooltip: app.t('Follow trip', 'Fuata safari'),
                  onTap: () {
                    setState(() => _autoFollow = true);
                    _fitView(force: true);
                  },
                ),
              ),

              // ------------------------------------------------------------ bottom panel
              Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: panelWidth, maxHeight: box.maxHeight * 0.66),
                  child: SizeReporter(
                    onHeight: (h) {
                      if ((h - _panelH).abs() > 1 && mounted) setState(() => _panelH = h);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: MapUi.panelColor(isDark),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 22, offset: const Offset(0, -4))],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: MapUi.textSecondary(isDark).withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Flexible(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(compact ? 14 : 20, 12, compact ? 14 : 20, compact ? 12 : 18),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: KeyedSubtree(
                                    key: ValueKey(_noDriver ? 'nodriver' : (_ride.status == 'searching' || _ride.driver == null ? 'searching' : 'active')),
                                    child: _noDriver
                                        ? _buildNoDriver(app)
                                        : (_ride.status == 'searching' || _ride.driver == null)
                                            ? _buildSearching(app, isDark, accent)
                                            : _buildActivePanel(app, AppConstants.rideTypes.firstWhere(
                                                (r) => r['id'] == _ride.rideType,
                                                orElse: () => AppConstants.rideTypes[0],
                                              ), isDark, compact),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Only the map listens to the animation notifiers, so the rest of the screen is not rebuilt
  /// 15 times per second while the vehicle glides.
  Widget _buildMap(bool isDark, double topPad, double bottomPad) {
    final pickup = gmaps.LatLng(_ride.fromLat, _ride.fromLng);
    final dest = gmaps.LatLng(_ride.toLat, _ride.toLng);
    final set = _markerSet;
    final searching = _ride.status == 'searching' && !_noDriver;
    final hasTrip = _tripRoute != null && _tripRoute!.points.length >= 2;

    return ValueListenableBuilder<double>(
      valueListenable: _pulse,
      builder: (context, phase, _) => ValueListenableBuilder<MovingFrame?>(
        valueListenable: _driver.frame,
        builder: (context, frame, __) {
          final polylines = <gmaps.Polyline>{};
          if (searching || (!_hasDriverFix && hasTrip)) {
            // Preview of the whole trip while we look for a driver.
            if (hasTrip) {
              polylines.addAll(MapUi.routeLine(id: 'trip', points: _tripRoute!.points, isDark: isDark));
            }
          } else if (_inTrip) {
            polylines
              ..addAll(MapUi.travelledLine(id: 'trip', points: _travelled, isDark: isDark))
              ..addAll(MapUi.routeLine(
                id: 'trip',
                points: _remaining.length >= 2 ? _remaining : (hasTrip ? _tripRoute!.points : const []),
                isDark: isDark,
              ));
          } else {
            // Driver is heading to the pickup: bold route to the rider, faint dashed trip beyond.
            if (hasTrip) {
              polylines.addAll(MapUi.secondaryLine(id: 'trip', points: _tripRoute!.points, isDark: isDark));
            }
            polylines.addAll(MapUi.routeLine(id: 'guide', points: _remaining, isDark: isDark, zIndex: 3));
          }

          final markers = <gmaps.Marker>{
            if (_ride.fromLat != 0 && !_inTrip)
              gmaps.Marker(
                markerId: const gmaps.MarkerId('pickup'),
                position: pickup,
                icon: set?.pickup ?? gmaps.BitmapDescriptor.defaultMarker,
                anchor: const Offset(0.5, 0.5),
                zIndexInt: 2,
              ),
            if (_ride.toLat != 0)
              gmaps.Marker(
                markerId: const gmaps.MarkerId('destination'),
                position: dest,
                icon: set?.destination ?? gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueOrange),
                anchor: const Offset(0.5, 0.95),
                zIndexInt: 3,
              ),
            if (frame != null)
              gmaps.Marker(
                markerId: const gmaps.MarkerId('driver'),
                position: frame.position,
                icon: set?.driverArrow ?? gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure),
                rotation: frame.heading,
                flat: true,
                anchor: const Offset(0.5, 0.5),
                zIndexInt: 5,
                infoWindow: gmaps.InfoWindow(title: _ride.driver?.name ?? 'Driver'),
              ),
          };

          return gmaps.GoogleMap(
            style: MapStyles.forBrightness(isDark),
            padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
            onMapCreated: (c) {
              _mapCtrl = c;
              _fitView(force: true);
            },
            initialCameraPosition: gmaps.CameraPosition(target: pickup, zoom: 14.5),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            buildingsEnabled: false,
            trafficEnabled: false,
            polylines: polylines,
            markers: markers,
            circles: searching && _ride.fromLat != 0 ? PulseCircles.build(pickup, phase, isDark) : const <gmaps.Circle>{},
          );
        },
      ),
    );
  }

  Widget _buildSearching(AppProvider app, bool isDark, Color accent) {
    final muted = MapUi.textSecondary(isDark);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(strokeWidth: 3.2, color: accent, backgroundColor: accent.withValues(alpha: 0.15)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_statusLabel(app), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    app.t('Searching for ${_searchSeconds}s…', 'Inatafuta kwa ${_searchSeconds}s…'),
                    style: TextStyle(fontSize: 12.5, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _routeSummary(app, isDark, accent),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => _cancelRide(app),
            child: Text(app.t('Cancel search', 'Ghairi utafutaji'), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  /// From → To summary with the fare, shown while searching.
  Widget _routeSummary(AppProvider app, bool isDark, Color accent) {
    final muted = MapUi.textSecondary(isDark);
    final trip = _tripRoute;
    Widget line(Widget icon, String text) => Row(
          children: [
            SizedBox(width: 16, child: Center(child: icon)),
            const SizedBox(width: 10),
            Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
          ],
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: MapUi.panelSubtle(isDark), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          line(Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 3))), _ride.fromAddress),
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Align(alignment: Alignment.centerLeft, child: Container(width: 2, height: 10, color: muted.withValues(alpha: 0.35))),
          ),
          line(Icon(Icons.location_on_rounded, size: 16, color: AppColors.coral), _ride.toAddress),
          if (trip != null || _ride.estimatedFare > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (trip != null)
                  Expanded(
                    child: Text('${trip.durationLabel} · ${trip.distanceLabel}', style: TextStyle(fontSize: 12.5, color: muted, fontWeight: FontWeight.w600)),
                  )
                else
                  const Spacer(),
                if (_ride.estimatedFare > 0)
                  Text(formatTzs(_ride.estimatedFare), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoDriver(AppProvider app) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.search_off_rounded, size: 46, color: AppColors.sunsetOrange),
        const SizedBox(height: 10),
        Text(
          app.t('No drivers available nearby', 'Hakuna madereva karibu'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          app.t('Try again, change ride type, or cancel.', 'Jaribu tena, badilisha aina, au ghairi.'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await context.read<AppProvider>().cancelActiveRide(reason: 'No driver');
                  if (mounted) Navigator.pop(context);
                },
                child: Text(app.t('Cancel', 'Ghairi')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _retrySearch,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brightGreen, foregroundColor: Colors.white),
                child: Text(app.t('Retry', 'Jaribu tena')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivePanel(AppProvider app, Map<String, dynamic> type, bool isDark, bool compact) {
    final driver = _ride.driver!;
    final discount = _ride.discount ?? 0;
    final fare = _ride.estimatedFare - discount;
    final muted = MapUi.textSecondary(isDark);
    final accent = MapUi.accent(isDark);
    final eta = _etaMinutes;
    final initial = driver.name.trim().isEmpty ? '?' : driver.name.trim()[0].toUpperCase();

    Widget action(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: Material(
            color: MapUi.panelSubtle(isDark),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 21, color: accent),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.brightGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _statusLabel(app),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.brightGreen, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
            const Spacer(),
            if (eta != null && _ride.status != 'arrived')
              Text('~$eta min', style: TextStyle(fontWeight: FontWeight.w800, color: accent, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            CircleAvatar(
              radius: compact ? 24 : 28,
              backgroundColor: accent.withValues(alpha: 0.15),
              foregroundImage: driver.photoUrl.isNotEmpty ? CachedNetworkImageProvider(driver.photoUrl) : null,
              child: Text(initial, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: accent)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.sunsetOrange, size: 16),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '${driver.rating} · ${driver.totalRides} ${app.t('rides', 'safari')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (driver.vehicleNumber.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: muted.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(driver.vehicleNumber, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                        ),
                      if (driver.vehicleNumber.isNotEmpty) const SizedBox(width: 8),
                      Flexible(child: Text('${type['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: muted))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatTzs(fare), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                if (discount > 0)
                  Text('-${formatTzs(discount, withCurrency: false)} promo', style: const TextStyle(fontSize: 11, color: AppColors.brightGreen)),
                Text((_ride.paymentMethod ?? 'cash').toUpperCase(), style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        if (_ride.status == 'arrived') ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmPickup,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(app.t('Confirm pickup · Start trip', 'Thibitisha kuchukuliwa · Anza safari')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brightGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            app.t('Share your PIN ${_ride.tripPin} with the driver', 'Mpe dereva PIN ${_ride.tripPin}'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
        if (_inTrip && _remainingMeters > 0) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: _tripRoute != null && _tripRoute!.distanceMeters > 0
                  ? (1 - _remainingMeters / _tripRoute!.distanceMeters).clamp(0.02, 1.0).toDouble()
                  : null,
              backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade200,
              color: AppColors.brightGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            app.t(
              '${(_remainingMeters / 1000).toStringAsFixed(1)} km to go',
              'Km ${(_remainingMeters / 1000).toStringAsFixed(1)} zimebaki',
            ),
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            action(Icons.call_rounded, app.t('Call', 'Piga'), () => launchUrl(Uri.parse('tel:${driver.phone}'))),
            const SizedBox(width: 8),
            action(Icons.chat_bubble_rounded, app.t('Chat', 'Chat'), () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
            }),
            const SizedBox(width: 8),
            action(Icons.share_location_rounded, app.t('Share', 'Shiriki'), () {
              final text = Uri.encodeComponent(
                app.t(
                  "I'm on a ZenjiGO ride to ${_ride.toAddress}. Track me!",
                  'Niko kwenye safari ya ZenjiGO kwenda ${_ride.toAddress}. Nifuate!',
                ),
              );
              launchUrl(Uri.parse('https://wa.me/?text=$text'));
            }),
          ],
        ),
        if (!_inTrip) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _cancelRide(app),
                  child: Text(app.t('Cancel Ride', 'Ghairi Safari'), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _reportDriver(app),
                  child: Text(app.t('Report', 'Ripoti'), style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
