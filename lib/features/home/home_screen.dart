import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' as places;
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/api/rider_api.dart';
import '../../providers/app_provider.dart';
import '../../models/user_model.dart';
import '../ride/ride_details_screen.dart';
import '../extras/parcel_screen.dart';
import '../extras/tour_packages_screen.dart';
import '../extras/promotions_screen.dart';
import '../payments/payment_methods_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  String? _selectedRideType;
  bool _searching = false;
  double? _estimatedFare;
  int? _eta;
  String _paymentMethod = 'cash';
  double? _toLat;
  double? _toLng;

  final List<LatLng> _nearbyDrivers = [];
  gmaps.GoogleMapController? _googleMapController;
  Timer? _nearbyTimer;
  bool _locationLoading = false;
  bool _placesLoading = false;
  int _placesRequest = 0;
  List<Map<String, dynamic>> _placeSuggestions = [];
  // Uses the same Android-restricted key already configured in AndroidManifest.xml.
  // Override at build time for a separate platform-specific key: --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
  // In Google Cloud Console, enable Places API (New) and restrict this key to this app.
  static const String _placesApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyBX93zeEULXrhxlvkNefmoFcYDGizvvSpU',
  );
  late final places.FlutterGooglePlacesSdk _placesClient =
      places.FlutterGooglePlacesSdk(_placesApiKey, useNewApi: true);

  @override
  void dispose() {
    _nearbyTimer?.cancel();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppProvider>();
      if (app.currentAddress.isNotEmpty) _fromCtrl.text = app.currentAddress;
      _loadCurrentLocation();
    });
  }

  Future<void> _loadCurrentLocation() async {
    if (_locationLoading) return;
    setState(() => _locationLoading = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Enable location services to use your real pickup location.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required to set your pickup.');
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;
      var pickupAddress = 'Current Location (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})';
      try {
        // Use the platform geocoder; this avoids calling the Geocoding REST API
        // with a website HTTP-referrer key (mobile REST requests have no Referer).
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude)
            .timeout(const Duration(seconds: 6));
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final address = [
            p.street, p.subLocality, p.locality, p.administrativeArea, p.country,
          ].whereType<String>().map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().join(', ');
          if (address.isNotEmpty) pickupAddress = address;
        }
      } catch (_) {
        // GPS coordinates remain valid even if reverse geocoding is temporarily unavailable.
      }
      if (!mounted) return;
      context.read<AppProvider>().setCurrentLocation(lat: pos.latitude, lng: pos.longitude, address: pickupAddress);
      _fromCtrl.text = pickupAddress;
      _googleMapController?.animateCamera(gmaps.CameraUpdate.newLatLng(
        gmaps.LatLng(pos.latitude, pos.longitude),
      ));
      await _refreshNearbyDrivers();
      _nearbyTimer ??= Timer.periodic(const Duration(seconds: 15), (_) => _refreshNearbyDrivers());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => _locationLoading = false); }
  }

  Future<void> _refreshNearbyDrivers() async {
    final app = context.read<AppProvider>();
    if (app.currentLat == 0 || app.currentLng == 0) return;
    try {
      final drivers = await RiderApi.nearbyDrivers(app.currentLat, app.currentLng);
      if (!mounted) return;
      final points = <LatLng>[];
      for (final item in drivers) {
        if (item is! Map) continue;
        final data = Map<String, dynamic>.from(item);
        final lat = double.tryParse((data['lat'] ?? data['latitude'] ?? '').toString());
        final lng = double.tryParse((data['lng'] ?? data['longitude'] ?? '').toString());
        if (lat != null && lng != null && lat != 0 && lng != 0) points.add(LatLng(lat, lng));
      }
      setState(() {
        _nearbyDrivers
          ..clear()
          ..addAll(points);
      });
    } catch (_) {
      // Keep last server-provided driver locations during transient network errors.
    }
  }

  Future<void> _searchPlaces(String query) async {
    final q = query.trim();
    final requestId = ++_placesRequest;
    setState(() {
      _toLat = null;
      _toLng = null;
      _estimatedFare = null;
      _eta = null;
      _placesLoading = false;
      _placeSuggestions = [];
    });
    if (q.length < 3) return;
    if (_placesApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Google Places key is missing. Configure a native Android/iOS Places API key.'),
      ));
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || requestId != _placesRequest) return;
    setState(() => _placesLoading = true);
    try {
      // Native SDK requests carry the app identity, unlike REST calls that
      // send an empty HTTP Referer and are rejected by website-restricted keys.
      final response = await _placesClient.findAutocompletePredictions(
        q,
        countries: const ['tz'],
      );
      final normalized = <Map<String, dynamic>>[];
      for (final prediction in response.predictions) {
        if (prediction.placeId.isEmpty || prediction.fullText.isEmpty) continue;
        normalized.add({
          'place_id': prediction.placeId,
          'description': prediction.fullText,
          'structured_formatting': {
            'main_text': prediction.primaryText,
            'secondary_text': prediction.secondaryText,
          },
        });
      }
      if (!mounted || requestId != _placesRequest) return;
      setState(() => _placeSuggestions = normalized);
    } catch (e) {
      if (mounted && requestId == _placesRequest) {
        setState(() => _placeSuggestions = []);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Google Places search unavailable: ${e.toString().replaceFirst('Exception: ', '')}'),
        ));
      }
    } finally {
      if (mounted && requestId == _placesRequest) setState(() => _placesLoading = false);
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> place) async {
    final placeId = (place['place_id'] ?? '').toString();
    if (placeId.isEmpty) return;
    setState(() { _placesLoading = true; _placeSuggestions = []; });
    try {
      if (_placesApiKey.isEmpty) {
        throw Exception('Google Places key is missing. Configure a native Android/iOS Places API key.');
      }
      final response = await _placesClient.fetchPlace(
        placeId,
        fields: const [places.PlaceField.Id, places.PlaceField.Address, places.PlaceField.Location, places.PlaceField.Name],
      );
      final result = response.place;
      final location = result?.latLng;
      if (result == null || location == null) {
        throw Exception('Google Places returned no coordinates for this destination.');
      }
      final lat = location.lat;
      final lng = location.lng;
      if (!mounted) return;
      setState(() {
        _toCtrl.text = (result.address ?? place['description'] ?? '').toString();
        _toLat = lat;
        _toLng = lng;
        _estimatedFare = null;
        _eta = null;
      });
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _placesLoading = false);
    }
  }

  void _selectRide(String rideType) {
    setState(() {
      _selectedRideType = rideType;
      _estimatedFare = null;
      _eta = null;
    });
  }

  Future<void> _requestRide() async {
    final app = context.read<AppProvider>();
    if (_toCtrl.text.isEmpty || _selectedRideType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(app.t('Select destination and ride type', 'Chagua mahali na aina ya usafiri'))),
      );
      return;
    }
    // Wallet balance check
    if (_paymentMethod == 'wallet') {
      if (_estimatedFare == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Get a live quote before booking with your wallet.')));
        return;
      }
      final fare = (_estimatedFare! - app.pendingDiscount).clamp(0, double.infinity).toDouble();
      if (!app.hasSufficientWallet(fare)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(app.t('Insufficient wallet balance', 'Salio la pochi haitoshi'))),
        );
        return;
      }
    }
    if (app.currentLat == 0 || app.currentLng == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A real pickup location is required. Enable location services and retry.')));
      return;
    }
    if (_toLat == null || _toLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a destination from Google Places suggestions so real map coordinates can be used.')));
      return;
    }

    setState(() => _searching = true);
    // Optional live quote for better fare display
    try {
      final q = await RiderApi.quote(
        rideType: _selectedRideType == 'airport' ? 'taxi' : (_selectedRideType ?? 'boda'),
        pickupLat: app.currentLat,
        pickupLng: app.currentLng,
        destinationLat: _toLat!,
        destinationLng: _toLng!,
      );
      final quoteFare = q['fare'] ?? q['estimatedFare'] ?? q['total'] ?? q['amount'];
      if (quoteFare != null) _estimatedFare = double.tryParse(quoteFare.toString()) ?? _estimatedFare;
      final quoteDuration = q['durationMin'] ?? q['estimatedDurationMin'];
      if (quoteDuration != null) _eta = int.tryParse(quoteDuration.toString()) ?? _eta;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get a live fare quote: ${e.toString().replaceFirst('Exception: ', '')}')));
      if (mounted) setState(() => _searching = false);
      return;
    }
    if (!mounted) return;
    setState(() => _searching = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RideDetailsScreen(
          rideType: _selectedRideType!,
          from: _fromCtrl.text,
          to: _toCtrl.text,
          fare: _estimatedFare,
          eta: _eta,
          fromLat: app.currentLat,
          fromLng: app.currentLng,
          toLat: _toLat,
          toLng: _toLng,
          paymentMethod: _paymentMethod,
          promoCode: app.pendingPromoCode,
          discount: app.pendingDiscount,
        ),
      ),
    );
  }

  void _pickPaymentMethod() async {
    final app = context.read<AppProvider>();
    final methods = app.user?.paymentMethods ?? const <PaymentMethodModel>[];
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) {
        final accent = app.isDark ? AppColors.aquaGreen : AppColors.oceanTeal;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 14),
              Text(app.t('Choose payment method', 'Chagua njia ya malipo'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.payments_rounded, size: 20)),
                title: Text(app.t('Cash', 'Fedha taslimu')),
                subtitle: Text(app.t('Pay the driver after the ride', 'Lipa dereva baada ya safari')),
                trailing: _paymentMethod == 'cash' ? Icon(Icons.check_circle, color: accent) : null,
                onTap: () => Navigator.pop(ctx, 'cash'),
              ),
              if (app.walletBalance > 0)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet_rounded)),
                  title: Text(app.t('ZenjiGO Wallet', 'Pochi ya ZenjiGO')),
                  subtitle: Text('TZS ${app.walletBalance.toStringAsFixed(0)} available'),
                  trailing: _paymentMethod == 'wallet' ? Icon(Icons.check_circle, color: accent) : null,
                  onTap: () => Navigator.pop(ctx, 'wallet'),
                ),
              ...methods.map((m) {
                final isCard = m.type == 'bank';
                final label = isCard ? app.t('Bank Card', 'Kadi ya benki') : (m.provider ?? app.t('Mobile Money', 'Pesa ya simu'));
                final detail = isCard ? '•••• ${m.cardLast4 ?? ''}' : (m.accountNumber ?? '');
                return ListTile(
                  leading: CircleAvatar(child: Icon(isCard ? Icons.credit_card_rounded : Icons.phone_android_rounded)),
                  title: Text(label),
                  subtitle: Text(detail),
                  trailing: _paymentMethod == m.type ? Icon(Icons.check_circle, color: accent) : null,
                  onTap: () => Navigator.pop(ctx, m.type),
                );
              }),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()));
                },
                icon: const Icon(Icons.add_card_rounded),
                label: Text(app.t('Add / manage payment methods', 'Ongeza / simamia njia za malipo')),
              ),
            ]),
          ),
        );
      },
    );
    if (selected != null) setState(() => _paymentMethod = selected);
  }
  void _pickSavedDestination() async {
    final app = context.read<AppProvider>();
    final locs = app.user?.savedLocations ?? [];
    if (locs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(app.t('No saved locations', 'Hakuna maeneo yaliyohifadhiwa'))),
      );
      return;
    }
    final picked = await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(app.t('Saved places', 'Maeneo yaliyohifadhiwa'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...locs.map((l) => ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: Text(l.label),
                  subtitle: Text(l.address),
                  onTap: () => Navigator.pop(ctx, l),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _toCtrl.text = picked.address;
        _toLat = picked.lat;
        _toLng = picked.lng;
        _estimatedFare = null;
        _eta = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Google Maps SDK map, using the same Google Maps platform key as the web project.
          gmaps.GoogleMap(
            onMapCreated: (controller) {
              _googleMapController = controller;
              final app = context.read<AppProvider>();
              if (app.currentLat != 0 && app.currentLng != 0) {
                controller.animateCamera(gmaps.CameraUpdate.newLatLng(
                  gmaps.LatLng(app.currentLat, app.currentLng),
                ));
              }
            },
            initialCameraPosition: gmaps.CameraPosition(
              target: app.currentLat != 0 && app.currentLng != 0
                  ? gmaps.LatLng(app.currentLat, app.currentLng)
                  : const gmaps.LatLng(-6.1659, 39.2026),
              zoom: 14,
            ),
            myLocationEnabled: app.currentLat != 0 && app.currentLng != 0,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            compassEnabled: true,
            markers: {
              if (app.currentLat != 0 && app.currentLng != 0)
                gmaps.Marker(
                  markerId: const gmaps.MarkerId('rider-pickup'),
                  position: gmaps.LatLng(app.currentLat, app.currentLng),
                  infoWindow: const gmaps.InfoWindow(title: 'Your pickup'),
                ),
              ..._nearbyDrivers.asMap().entries.map((entry) => gmaps.Marker(
                    markerId: gmaps.MarkerId('driver-${entry.key}'),
                    position: gmaps.LatLng(entry.value.latitude, entry.value.longitude),
                    icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen),
                    infoWindow: const gmaps.InfoWindow(title: 'Nearby driver'),
                  )),
              if (_toLat != null && _toLng != null)
                gmaps.Marker(
                  markerId: const gmaps.MarkerId('destination'),
                  position: gmaps.LatLng(_toLat!, _toLng!),
                  icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueOrange),
                  infoWindow: const gmaps.InfoWindow(title: 'Destination'),
                ),
            },
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  // Search card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface.withOpacity(0.95) : AppColors.lightSurface.withOpacity(0.97),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        _searchRow(Icons.my_location, app.t('From', 'Kutoka'), _fromCtrl, isDark, true),
                        Divider(height: 16, color: isDark ? AppColors.darkCard : Colors.grey.shade200),
                        _searchRow(Icons.location_on, app.t('Where to?', 'Unakwenda wapi?'), _toCtrl, isDark, false,
                            onChanged: (v) => _searchPlaces(v)),
                        if (_placesLoading) const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                        if (_placeSuggestions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            constraints: const BoxConstraints(maxHeight: 190),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppColors.darkSurface : Colors.grey.shade200),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: _placeSuggestions.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final place = _placeSuggestions[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.location_on_outlined),
                                  title: Text((place['structured_formatting'] is Map
                                      ? (place['structured_formatting']['main_text'] ?? place['description'])
                                      : place['description']).toString()),
                                  subtitle: Text((place['structured_formatting'] is Map
                                      ? (place['structured_formatting']['secondary_text'] ?? '')
                                      : '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  onTap: () => _selectPlace(place),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: -0.15, end: 0),

                  // Quick extras
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _chip(Icons.inventory_2_rounded, app.t('Parcel', 'Kifurushi'), () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ParcelScreen()));
                        }, isDark),
                        _chip(Icons.beach_access_rounded, app.t('Tours', 'Ziara'), () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TourPackagesScreen()));
                        }, isDark),
                        _chip(Icons.local_offer_rounded, app.t('Offers', 'Ofa'), () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PromotionsScreen()));
                        }, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom sheet - ride options
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(maxHeight: size.height * 0.42),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Text(app.t('Choose a ride', 'Chagua usafiri'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (_estimatedFare != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.aquaGreen : AppColors.oceanTeal).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'TZS ${_estimatedFare!.toStringAsFixed(0)} · ${_eta} min',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: AppConstants.rideTypes.length,
                      itemBuilder: (_, i) {
                        final r = AppConstants.rideTypes[i];
                        final selected = _selectedRideType == r['id'];
                        return GestureDetector(
                          onTap: () => _selectRide((r['id'] ?? '').toString()),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? (isDark ? AppColors.aquaGreen.withOpacity(0.15) : AppColors.oceanTeal.withOpacity(0.1))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: selected
                                  ? Border.all(color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal, width: 1.5)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  r['icon'] as IconData,
                                  size: 28,
                                  color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (app.isSwahili ? r['nameSw'] : r['name']).toString(),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                      Text(
                                        'Get live quote',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected) Icon(Icons.check_circle, color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickPaymentMethod,
                            icon: const Icon(Icons.payment, size: 18),
                            label: Text(
                              AppConstants.paymentMethods.firstWhere((m) => m['id'] == _paymentMethod, orElse: () => AppConstants.paymentMethods[0])['name'].toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _pickSavedDestination,
                          icon: const Icon(Icons.bookmark_border, size: 18),
                          label: Text(app.t('Saved', 'Imehifadhiwa')),
                        ),
                      ],
                    ),
                  ),
                  if (app.pendingPromoCode != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                      child: Row(
                        children: [
                          Icon(Icons.local_offer, size: 16, color: AppColors.brightGreen),
                          const SizedBox(width: 6),
                          Expanded(child: Text(app.t('Promo ${app.pendingPromoCode} (-${app.pendingDiscount.toStringAsFixed(0)})', 'Promo ${app.pendingPromoCode} (-${app.pendingDiscount.toStringAsFixed(0)})'), style: const TextStyle(fontSize: 12, color: AppColors.brightGreen))),
                          TextButton(onPressed: () { app.clearPromo(); setState(() {}); }, child: Text(app.t('Clear', 'Futa'), style: const TextStyle(fontSize: 12))),
                        ],
                      ),
                    ),
                  // Active ride banner
                  if (app.activeRide != null && app.activeRide!.isActive)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Material(
                        color: AppColors.oceanTeal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(existingRide: app.activeRide)));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_car, color: AppColors.oceanTeal),
                                const SizedBox(width: 10),
                                Expanded(child: Text(app.t('Active ride · ${app.activeRide!.status}', 'Safari hai · ${app.activeRide!.status}'), style: const TextStyle(fontWeight: FontWeight.w600))),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _searching ? null : _requestRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brightGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _searching
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text(app.t('Request Ride', 'Omba Safari'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchRow(IconData icon, String hint, TextEditingController ctrl, bool isDark, bool readOnly, {ValueChanged<String>? onChanged}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: ctrl,
            readOnly: readOnly,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal),
        label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        onPressed: onTap,
        backgroundColor: isDark ? AppColors.darkSurface.withOpacity(0.9) : AppColors.lightSurface.withOpacity(0.95),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 2,
        shadowColor: Colors.black26,
      ),
    );
  }
}
