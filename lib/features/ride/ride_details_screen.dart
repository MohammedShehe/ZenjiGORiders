import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/ride_model.dart';
import '../../providers/app_provider.dart';
import '../chat/chat_detail_screen.dart';
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
  Timer? _driverMoveTimer;
  bool _noDriver = false;
  int _searchSeconds = 0;
  double _driverProgress = 0; // 0..1 toward pickup then destination
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    if (widget.existingRide != null) {
      _ride = widget.existingRide!;
      if (_ride.isActive) _continueLifecycle();
    } else {
      _ride = app.createRide(
        rideType: widget.rideType ?? 'boda',
        fromAddress: widget.from ?? app.currentAddress,
        toAddress: widget.to ?? '',
        estimatedFare: widget.fare ?? 5000,
        etaMinutes: widget.eta ?? 15,
        fromLat: widget.fromLat,
        fromLng: widget.fromLng,
        toLat: widget.toLat,
        toLng: widget.toLng,
        paymentMethod: widget.paymentMethod,
        promoCode: widget.promoCode,
        discount: widget.discount,
      );
      _startSearch();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _driverMoveTimer?.cancel();
    super.dispose();
  }

  void _startSearch() {
    _searchSeconds = 0;
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _searchSeconds++);
      if (_searchSeconds >= 2 && _ride.status == 'searching') {
        // Found driver
        t.cancel();
        final driver = DriverModel(
          id: 'd_live_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Juma Hassan',
          phone: '+255712345678',
          vehicleNumber: 'T 789 XYZ',
          vehicleType: _ride.rideType,
          rating: 4.9,
          totalRides: 342,
          lat: _ride.fromLat + 0.008,
          lng: _ride.fromLng + 0.006,
        );
        _ride = _ride.copyWith(status: 'accepted', driver: driver);
        context.read<AppProvider>().updateActiveRide(_ride);
        context.read<AppProvider>().ensureDriverChat(driver);
        setState(() {});
        _scheduleNext('arriving', const Duration(seconds: 3));
      } else if (_searchSeconds >= 25 && _ride.status == 'searching') {
        // No driver timeout
        t.cancel();
        setState(() => _noDriver = true);
      }
    });
  }

  void _continueLifecycle() {
    if (_ride.status == 'accepted') {
      _scheduleNext('arriving', const Duration(seconds: 2));
    } else if (_ride.status == 'arriving') {
      _startDriverApproach();
    } else if (_ride.status == 'arrived') {
      // wait for user confirm
    } else if (_ride.status == 'started') {
      _startTripProgress();
    }
  }

  void _scheduleNext(String nextStatus, Duration delay) {
    _statusTimer?.cancel();
    _statusTimer = Timer(delay, () {
      if (!mounted) return;
      if (nextStatus == 'arriving') {
        _ride = _ride.copyWith(status: 'arriving');
        context.read<AppProvider>().updateActiveRide(_ride);
        setState(() {});
        _startDriverApproach();
      } else if (nextStatus == 'arrived') {
        _ride = _ride.copyWith(status: 'arrived');
        context.read<AppProvider>().updateActiveRide(_ride);
        setState(() {});
      }
    });
  }

  void _startDriverApproach() {
    _driverProgress = 0;
    _driverMoveTimer?.cancel();
    _driverMoveTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (!mounted || _ride.status != 'arriving') {
        t.cancel();
        return;
      }
      setState(() {
        _driverProgress = (_driverProgress + 0.05).clamp(0.0, 1.0);
        if (_ride.driver != null) {
          final d = _ride.driver!;
          final lat = d.lat + (_ride.fromLat - d.lat) * _driverProgress;
          final lng = d.lng + (_ride.fromLng - d.lng) * _driverProgress;
          _ride = _ride.copyWith(driver: d.copyWith(lat: lat, lng: lng));
        }
      });
      if (_driverProgress >= 1.0) {
        t.cancel();
        _ride = _ride.copyWith(status: 'arrived');
        context.read<AppProvider>().updateActiveRide(_ride);
        setState(() {});
      }
    });
  }

  void _confirmPickup() {
    _ride = _ride.copyWith(status: 'started', startedAt: DateTime.now());
    context.read<AppProvider>().updateActiveRide(_ride);
    setState(() {});
    _startTripProgress();
  }

  void _startTripProgress() {
    _driverProgress = 0;
    _driverMoveTimer?.cancel();
    _driverMoveTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!mounted || _ride.status != 'started') {
        t.cancel();
        return;
      }
      setState(() {
        _driverProgress = (_driverProgress + 0.04).clamp(0.0, 1.0);
        if (_ride.driver != null) {
          final lat = _ride.fromLat + (_ride.toLat - _ride.fromLat) * _driverProgress;
          final lng = _ride.fromLng + (_ride.toLng - _ride.fromLng) * _driverProgress;
          _ride = _ride.copyWith(driver: _ride.driver!.copyWith(lat: lat, lng: lng));
        }
      });
      if (_driverProgress >= 1.0) {
        t.cancel();
        _onDestinationReached();
      }
    });
  }

  void _onDestinationReached() {
    // Show rating sheet then complete
    _showRatingAndComplete();
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
                      label: Text(v == 0 ? app.t('No tip', 'Hakuna tip') : 'TZS ${v.toInt()}'),
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
    feedbackCtrl.dispose();
    if (!mounted) return;

    final r = (result?['rating'] as int?) ?? 5;
    final fb = result?['feedback'] as String?;
    final tp = (result?['tip'] as double?) ?? 0;

    app.completeActiveRide(finalFare: _ride.estimatedFare, rating: r, feedback: fb, tip: tp);

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
    manual.dispose();
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
      _driverMoveTimer?.cancel();
      app.cancelActiveRide(reason: result);
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
    manual.dispose();
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
    final type = AppConstants.rideTypes.firstWhere(
      (r) => r['id'] == _ride.rideType,
      orElse: () => AppConstants.rideTypes[0],
    );
    final pickup = LatLng(_ride.fromLat, _ride.fromLng);
    final dest = LatLng(_ride.toLat, _ride.toLng);
    final driverPos = _ride.driver != null
        ? LatLng(_ride.driver!.lat, _ride.driver!.lng)
        : null;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: pickup,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.zenjigo.riders',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: pickup,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.person_pin_circle, color: AppColors.brightGreen, size: 36),
                  ),
                  Marker(
                    point: dest,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: AppColors.sunsetOrange, size: 36),
                  ),
                  if (driverPos != null)
                    Marker(
                      point: driverPos,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.oceanTeal,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                        ),
                        child: const Icon(Icons.two_wheeler, color: Colors.white, size: 22),
                      ),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        // Keep active ride in provider; just leave screen
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  if (_ride.tripPin != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: Text(
                        app.t('PIN: ${_ride.tripPin}', 'PIN: ${_ride.tripPin}'),
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, -4))],
              ),
              child: _noDriver
                  ? _buildNoDriver(app)
                  : _ride.status == 'searching'
                      ? _buildSearching(app)
                      : _buildActivePanel(app, type, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearching(AppProvider app) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(_statusLabel(app)),
        const SizedBox(height: 8),
        Text(
          app.t('Searching for ${_searchSeconds}s…', 'Inatafuta kwa ${_searchSeconds}s…'),
          style: TextStyle(fontSize: 12, color: app.isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _cancelRide(app),
          child: Text(app.t('Cancel search', 'Ghairi utafutaji'), style: const TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }

  Widget _buildNoDriver(AppProvider app) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.search_off, size: 48, color: AppColors.sunsetOrange),
        const SizedBox(height: 12),
        Text(
          app.t('No drivers available nearby', 'Hakuna madereva karibu'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          app.t('Try again, change ride type, or cancel.', 'Jaribu tena, badilisha aina, au ghairi.'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  context.read<AppProvider>().cancelActiveRide(reason: 'No driver');
                  Navigator.pop(context);
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

  Widget _buildActivePanel(AppProvider app, Map<String, dynamic> type, bool isDark) {
    final driver = _ride.driver!;
    final discount = _ride.discount ?? 0;
    final fare = _ride.estimatedFare - discount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.brightGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _statusLabel(app),
            style: const TextStyle(color: AppColors.brightGreen, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              child: Text(driver.name[0], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.sunsetOrange, size: 16),
                      Text(' ${driver.rating} · ${driver.totalRides} ${app.t('rides', 'safari')}'),
                    ],
                  ),
                  Text(
                    '${driver.vehicleNumber} · ${type['name']}',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('TZS ${fare.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (discount > 0)
                  Text(
                    '-${discount.toStringAsFixed(0)} promo',
                    style: const TextStyle(fontSize: 11, color: AppColors.brightGreen),
                  ),
                Text(
                  (_ride.paymentMethod ?? 'cash').toUpperCase(),
                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ],
            ),
          ],
        ),
        if (_ride.status == 'arrived') ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmPickup,
              icon: const Icon(Icons.check_circle),
              label: Text(app.t('Confirm pickup · Start trip', 'Thibitisha kuchukuliwa · Anza safari')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brightGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            app.t('Share your PIN ${_ride.tripPin} with the driver', 'Mpe dereva PIN ${_ride.tripPin}'),
            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ],
        if (_ride.status == 'started') ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _driverProgress,
            backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade200,
            color: AppColors.brightGreen,
          ),
          const SizedBox(height: 6),
          Text(
            app.t('${(_driverProgress * 100).toInt()}% to destination', '${(_driverProgress * 100).toInt()}% kufika'),
            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:${driver.phone}')),
                icon: const Icon(Icons.phone),
                label: Text(app.t('Call', 'Piga')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final conv = app.ensureDriverChat(driver);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatDetailScreen(conversation: conv)),
                  );
                },
                icon: const Icon(Icons.chat),
                label: Text(app.t('Chat', 'Chat')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final text = Uri.encodeComponent(
                    app.t(
                      "I'm on a ZenjiGO ride to ${_ride.toAddress}. Track me!",
                      'Niko kwenye safari ya ZenjiGO kwenda ${_ride.toAddress}. Nifuate!',
                    ),
                  );
                  launchUrl(Uri.parse('https://wa.me/?text=$text'));
                },
                icon: const Icon(Icons.share),
                label: Text(app.t('Share', 'Shiriki')),
              ),
            ),
          ],
        ),
        if (_ride.status != 'started') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _cancelRide(app),
                  child: Text(app.t('Cancel Ride', 'Ghairi Safari'), style: const TextStyle(color: AppColors.error)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _reportDriver(app),
                  child: Text(
                    app.t('Report', 'Ripoti'),
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
