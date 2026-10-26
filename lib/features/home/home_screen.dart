import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' as places;
import '../../core/map/map_markers.dart';
import '../../core/map/map_style.dart';
import '../../core/map/map_widgets.dart';
import '../../core/map/route_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/money.dart';
import '../../core/utils/directions_service.dart';
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

/// A nearby driver shown on the map.
class _NearbyDriver {
  final String id;
  final gmaps.LatLng position;
  final String type;
  const _NearbyDriver(this.id, this.position, this.type);
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  String? _selectedRideType;
  bool _searching = false;
  double? _estimatedFare;
  int? _eta;
  String _paymentMethod = 'cash';
  double? _toLat;
  double? _toLng;

  final List<_NearbyDriver> _nearbyDrivers = [];
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();
  gmaps.GoogleMapController? _googleMapController;
  Timer? _nearbyTimer;
  bool _locationLoading = false;
  bool _placesLoading = false;
  int _placesRequest = 0;
  List<Map<String, dynamic>> _placeSuggestions = [];
  bool _searchingPickup = false;
  Map<String, double?> _fares = {}; // rideType -> price after both locations set
  List<gmaps.LatLng> _routePoints = []; // what is drawn (grows during the reveal animation)
  RouteResult? _route; // full road route + distance / duration
  final RouteReveal _reveal = RouteReveal();
  int _routeSeq = 0;
  MapMarkerSet? _markerSet;
  double _topH = 0;
  double _sheetH = 0;
  // Override at build time with: --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
  static const String _placesApiKey = DirectionsService.defaultKey;
  late final places.FlutterGooglePlacesSdk _placesClient =
      places.FlutterGooglePlacesSdk(_placesApiKey, useNewApi: true);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nearbyTimer?.cancel();
    _reveal.cancel();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No point polling drivers while the app is in the background.
    if (state == AppLifecycleState.resumed) {
      if (_nearbyTimer == null && context.read<AppProvider>().currentLat != 0) {
        _refreshNearbyDrivers();
        _nearbyTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshNearbyDrivers());
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _nearbyTimer?.cancel();
      _nearbyTimer = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_markerSet == null) {
      final ratio = View.of(context).devicePixelRatio;
      MapMarkers.load(ratio).then((set) {
        if (mounted) setState(() => _markerSet = set);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fromFocus.addListener(_onFocusChanged);
    _toFocus.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppProvider>();
      if (app.currentAddress.isNotEmpty) _fromCtrl.text = app.currentAddress;
      final def = app.defaultPaymentMethod;
      if (def != null) {
        setState(() => _paymentMethod = def.type == 'card' ? 'bank' : def.type);
      }
      app.refreshAccountCollections();
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
      // If destination was chosen before GPS fixed, load quotes + road route now
      if (_toLat != null && _toLng != null) {
        await _loadAllQuotes();
      }
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
      final points = <_NearbyDriver>[];
      var n = 0;
      for (final item in drivers) {
        if (item is! Map) continue;
        final data = Map<String, dynamic>.from(item);
        final lat = double.tryParse((data['lat'] ?? data['latitude'] ?? '').toString());
        final lng = double.tryParse((data['lng'] ?? data['longitude'] ?? '').toString());
        if (lat != null && lng != null && lat != 0 && lng != 0) {
          final type = (data['vehicleType'] ?? data['rideType'] ?? data['type'] ?? 'taxi').toString().toLowerCase();
          final id = (data['id'] ?? data['_id'] ?? data['driverId'] ?? 'n$n').toString();
          points.add(_NearbyDriver(id, gmaps.LatLng(lat, lng), type));
          n++;
        }
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

  Future<void> _searchPlaces(String query, {bool forPickup = false}) async {
    final q = query.trim();
    final requestId = ++_placesRequest;
    setState(() {
      _searchingPickup = forPickup;
      if (!forPickup) {
        _toLat = null;
        _toLng = null;
      }
      _clearRouteState();
      _estimatedFare = null;
      _eta = null;
      _fares = {};
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
        final raw = e.toString().replaceFirst('Exception: ', '');
        final clean = (raw.contains('permission') || raw.contains('403') || raw.contains('Autocomplet'))
            ? 'Places search unavailable. Enable Places API (New) for this API key in Google Cloud Console.'
            : (raw.length > 120 ? '${raw.substring(0, 120)}…' : raw);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(clean)));
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
      // Prefer human-readable suggestion name (e.g. "Fuoni Kibondeni"), not Plus Codes
      final main = (place['structured_formatting'] is Map
              ? (place['structured_formatting']['main_text'] ?? '')
              : '')
          .toString();
      final secondary = (place['structured_formatting'] is Map
              ? (place['structured_formatting']['secondary_text'] ?? '')
              : '')
          .toString();
      final suggestedAddress = [main, secondary]
          .where((part) => part.trim().isNotEmpty)
          .join(', ');
      final address = suggestedAddress.isNotEmpty
          ? suggestedAddress
          : (place['description']?.toString() ?? result.address ?? '');
      final app = context.read<AppProvider>();
      setState(() {
        if (_searchingPickup) {
          _fromCtrl.text = address;
          app.setCurrentLocation(lat: lat, lng: lng, address: address);
        } else {
          _toCtrl.text = address;
          _toLat = lat;
          _toLng = lng;
        }
        _placeSuggestions = [];
        _estimatedFare = null;
        _eta = null;
        _fares = {};
        _clearRouteState();
      });
      FocusScope.of(context).unfocus();
      // Quotes + route whenever BOTH pickup and destination are known (any order)
      final hasPickup = context.read<AppProvider>().currentLat != 0;
      final hasDest = _toLat != null && _toLng != null;
      if (hasPickup && hasDest) {
        await _loadAllQuotes(); // also refreshes road route
      } else {
        await _updateRoadRoute();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _placesLoading = false);
    }
  }

  void _clearRouteState() {
    _routeSeq++;
    _reveal.cancel();
    _routePoints = [];
    _route = null;
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAllQuotes() async {
    final app = context.read<AppProvider>();
    if (_toLat == null || _toLng == null || app.currentLat == 0) return;
    // Road route and the three fare quotes are independent: run them together.
    final routeFuture = _updateRoadRoute();
    final pickupLat = app.currentLat, pickupLng = app.currentLng;
    final destLat = _toLat!, destLng = _toLng!;
    final selected = _selectedRideType;

    final results = await Future.wait(AppConstants.rideTypes.map((r) async {
      final id = (r['id'] ?? '').toString();
      try {
        final q = await RiderApi.quote(
          rideType: id,
          pickupLat: pickupLat,
          pickupLng: pickupLng,
          destinationLat: destLat,
          destinationLng: destLng,
        );
        final fare = double.tryParse((q['fare'] ?? q['estimatedFare'] ?? q['price'] ?? q['total'] ?? '').toString());
        final dur = int.tryParse((q['durationMin'] ?? q['estimatedDurationMin'] ?? q['eta'] ?? '').toString());
        return MapEntry(id, (fare, dur));
      } catch (_) {
        return MapEntry<String, (double?, int?)>(id, (null, null));
      }
    }));
    if (!mounted) return;
    // Ignore the answer if the user changed the destination meanwhile.
    if (_toLat != destLat || _toLng != destLng) return;

    final fares = <String, double?>{};
    int? eta = _eta;
    for (final e in results) {
      fares[e.key] = e.value.$1;
      final dur = e.value.$2;
      if (dur != null && (eta == null || e.key == selected)) eta = dur;
    }
    setState(() {
      _fares = fares;
      _eta = eta;
      final sel = _selectedRideType;
      if (sel != null && fares[sel] != null) _estimatedFare = fares[sel];
    });
    await routeFuture;
  }

  Future<void> _updateRoadRoute() async {
    final app = context.read<AppProvider>();
    if (app.currentLat == 0 || app.currentLng == 0 || _toLat == null || _toLng == null) {
      if (mounted) setState(_clearRouteState);
      return;
    }
    final seq = ++_routeSeq;
    final result = await DirectionsService.fetch(
      originLat: app.currentLat,
      originLng: app.currentLng,
      destLat: _toLat!,
      destLng: _toLng!,
      apiKey: _placesApiKey,
    );
    // A newer request (or a cleared destination) supersedes this one.
    if (!mounted || seq != _routeSeq) return;
    setState(() {
      _route = result;
      _eta ??= result.durationMinutes;
    });
    _fitRouteOnMap();
    if (result.followsRoads) {
      // Draw the road route in (cheap: ~14 discrete frames).
      _reveal.start(result.points, (visible) {
        if (!mounted || seq != _routeSeq) return;
        setState(() => _routePoints = visible);
      });
    } else {
      setState(() => _routePoints = result.points);
    }
  }

  Future<void> _fitRouteOnMap() async {
    final ctrl = _googleMapController;
    if (ctrl == null) return;
    final app = context.read<AppProvider>();
    final pts = <gmaps.LatLng>[
      ...?_route?.points,
      if (app.currentLat != 0) gmaps.LatLng(app.currentLat, app.currentLng),
      if (_toLat != null && _toLng != null) gmaps.LatLng(_toLat!, _toLng!),
    ];
    final bounds = GeoUtils.boundsOf(pts);
    if (bounds == null) return;
    try {
      await ctrl.animateCamera(gmaps.CameraUpdate.newLatLngBounds(bounds, 56));
    } catch (_) {
      // Map not laid out yet (can happen right after navigation): centre instead.
      try {
        await ctrl.animateCamera(gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng((bounds.southwest.latitude + bounds.northeast.latitude) / 2,
              (bounds.southwest.longitude + bounds.northeast.longitude) / 2),
          13,
        ));
      } catch (_) {}
    }
  }

  Future<void> _recenterOnMe() async {
    final app = context.read<AppProvider>();
    if (app.currentLat == 0 || app.currentLng == 0) {
      await _loadCurrentLocation();
      return;
    }
    try {
      await _googleMapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(gmaps.LatLng(app.currentLat, app.currentLng), 15.5),
      );
    } catch (_) {}
  }

  void _clearDestination() {
    setState(() {
      _toCtrl.clear();
      _toLat = null;
      _toLng = null;
      _estimatedFare = null;
      _eta = null;
      _fares = {};
      _placeSuggestions = [];
      _clearRouteState();
    });
    _recenterOnMe();
  }

  void _selectRide(String rideType) {
    setState(() {
      _selectedRideType = rideType;
      _estimatedFare = _fares[rideType];
      // keep eta if we already have one from quotes
    });
    // Retry quote for this type if missing
    if (_fares[rideType] == null && _toLat != null) {
      _loadAllQuotes();
    }
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

    final fareLabel = formatTzs(_estimatedFare);
    final etaLabel = _eta != null ? '$_eta min' : '—';
    final rideName = AppConstants.rideTypes
        .firstWhere((r) => r['id'] == _selectedRideType, orElse: () => {'name': _selectedRideType})['name']
        .toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm ride quote'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${_fromCtrl.text}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text('To: ${_toCtrl.text}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Text('$rideName', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text('Fare: $fareLabel', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Est. time: $etaLabel'),
            const SizedBox(height: 6),
            Text('Payment: $_paymentMethod'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request ride')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await Navigator.of(context).push(
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
    // Back from the ride screen (completed, cancelled or dismissed): wipe the previous trip from the
    // booking form and the map so the next booking starts clean.
    if (!mounted) return;
    _resetAfterRide();
  }

  void _resetAfterRide() {
    setState(() {
      _toCtrl.clear();
      _toLat = null;
      _toLng = null;
      _estimatedFare = null;
      _eta = null;
      _fares = {};
      _placeSuggestions = [];
      _searching = false;
      _clearRouteState();
    });
    context.read<AppProvider>().refreshWallet();
    _recenterOnMe();
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
                  subtitle: Text('${formatTzs(app.walletBalance)} available'),
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
    if (picked != null && mounted) {
      setState(() {
        _toCtrl.text = picked.address;
        _toLat = picked.lat;
        _toLng = picked.lng;
        _estimatedFare = null;
        _eta = null;
        _fares = {};
        _placeSuggestions = [];
        _clearRouteState();
      });
      if (context.read<AppProvider>().currentLat != 0) await _loadAllQuotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;
    final mq = MediaQuery.of(context);
    final hasPickup = app.currentLat != 0 && app.currentLng != 0;
    final searchActive = _fromFocus.hasFocus || _toFocus.hasFocus;
    final route = _route;
    final markers = _markerSet;
    final accent = MapUi.accent(isDark);

    return MediaQuery(
      // Large system font sizes must not break the layout on small phones.
      data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2)),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(builder: (context, box) {
          final compact = box.maxHeight < 640 || box.maxWidth < 360;
          final panelWidth = box.maxWidth > 600 ? 520.0 : box.maxWidth;
          final sideGap = box.maxWidth > 600 ? 0.0 : (compact ? 10.0 : 14.0);
          final safeTop = mq.padding.top;
          final mapTopPad = safeTop + 8 + _topH;

          final polylines = <gmaps.Polyline>{
            if (_routePoints.length >= 2 && route != null && route.followsRoads)
              ...MapUi.routeLine(id: 'trip', points: _routePoints, isDark: isDark, width: 6),
            if (_routePoints.length >= 2 && route != null && !route.followsRoads)
              ...MapUi.secondaryLine(id: 'trip', points: _routePoints, isDark: isDark),
          };

          final mapMarkers = <gmaps.Marker>{
            if (hasPickup)
              gmaps.Marker(
                markerId: const gmaps.MarkerId('rider-pickup'),
                position: gmaps.LatLng(app.currentLat, app.currentLng),
                icon: markers?.pickup ?? gmaps.BitmapDescriptor.defaultMarker,
                anchor: const Offset(0.5, 0.5),
                zIndexInt: 3,
                consumeTapEvents: true,
              ),
            if (markers != null)
              for (final d in _nearbyDrivers)
                gmaps.Marker(
                  markerId: gmaps.MarkerId('driver-${d.id}'),
                  position: d.position,
                  icon: markers.nearbyFor(d.type),
                  anchor: const Offset(0.5, 0.5),
                  zIndexInt: 1,
                  consumeTapEvents: true,
                ),
            if (_toLat != null && _toLng != null)
              gmaps.Marker(
                markerId: const gmaps.MarkerId('destination'),
                position: gmaps.LatLng(_toLat!, _toLng!),
                icon: markers?.destination ??
                    gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueOrange),
                anchor: const Offset(0.5, 0.95),
                zIndexInt: 4,
                consumeTapEvents: true,
              ),
          };

          return Stack(
            children: [
              gmaps.GoogleMap(
                style: MapStyles.forBrightness(isDark),
                padding: EdgeInsets.only(top: mapTopPad, bottom: _sheetH, left: 0, right: 0),
                onMapCreated: (controller) {
                  _googleMapController = controller;
                  if (_route != null) {
                    _fitRouteOnMap();
                  } else if (hasPickup) {
                    controller.animateCamera(gmaps.CameraUpdate.newLatLng(
                      gmaps.LatLng(app.currentLat, app.currentLng),
                    ));
                  }
                },
                initialCameraPosition: gmaps.CameraPosition(
                  target: hasPickup
                      ? gmaps.LatLng(app.currentLat, app.currentLng)
                      : const gmaps.LatLng(-6.1659, 39.2026),
                  zoom: 14.5,
                ),
                myLocationEnabled: hasPickup,
                myLocationButtonEnabled: false, // replaced by our own button below
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                buildingsEnabled: false,
                trafficEnabled: false,
                minMaxZoomPreference: const gmaps.MinMaxZoomPreference(8, 20),
                polylines: polylines,
                markers: mapMarkers,
              ),

              // ---------------------------------------------------------- top: search
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: panelWidth),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(sideGap, 8, sideGap, 0),
                      child: SizeReporter(
                        onHeight: (h) {
                          if ((h - _topH).abs() > 1 && mounted) setState(() => _topH = h);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSearchCard(app, isDark, compact, box.maxHeight),
                            if (!searchActive) ...[
                              SizedBox(height: compact ? 8 : 12),
                              SizedBox(
                                height: 38,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  clipBehavior: Clip.none,
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
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.12, end: 0, duration: 250.ms),
                  ),
                ),
              ),

              // ---------------------------------------------------------- map buttons
              Positioned(
                right: sideGap + 2,
                bottom: _sheetH + 12,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: searchActive ? 0 : 1,
                  child: IgnorePointer(
                    ignoring: searchActive,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (route != null) ...[
                          MapCircleButton(
                            icon: Icons.zoom_out_map_rounded,
                            isDark: isDark,
                            tooltip: app.t('Show whole trip', 'Onyesha safari nzima'),
                            onTap: _fitRouteOnMap,
                          ),
                          const SizedBox(height: 10),
                        ],
                        MapCircleButton(
                          icon: _locationLoading ? Icons.hourglass_top_rounded : Icons.my_location_rounded,
                          isDark: isDark,
                          tooltip: app.t('My location', 'Eneo langu'),
                          onTap: _recenterOnMe,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Honest hint if Google *and* OSRM were unreachable.
              if (route != null && !route.followsRoads && !searchActive)
                Positioned(
                  left: sideGap + 2,
                  bottom: _sheetH + 14,
                  child: RouteInfoChip(
                    duration: route.durationLabel,
                    distance: route.distanceLabel,
                    isDark: isDark,
                    approximate: true,
                  ),
                ),

              // ---------------------------------------------------------- bottom sheet
              Align(
                alignment: Alignment.bottomCenter,
                child: IgnorePointer(
                  ignoring: searchActive,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    offset: searchActive ? const Offset(0, 1) : Offset.zero,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: searchActive ? 0 : 1,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: panelWidth,
                          maxHeight: box.maxHeight * (compact ? 0.55 : 0.48),
                        ),
                        child: SizeReporter(
                          onHeight: (h) {
                            if ((h - _sheetH).abs() > 1 && mounted) setState(() => _sheetH = h);
                          },
                          child: _buildRideSheet(app, isDark, compact, accent),
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

  // ------------------------------------------------------------------ search card

  Widget _buildSearchCard(AppProvider app, bool isDark, bool compact, double availableHeight) {
    final muted = MapUi.textSecondary(isDark);
    final accent = MapUi.accent(isDark);
    final suggestionMax = (availableHeight * (compact ? 0.28 : 0.34)).clamp(110.0, 300.0);

    return Container(
      padding: EdgeInsets.fromLTRB(14, compact ? 8 : 10, 6, compact ? 8 : 10),
      decoration: BoxDecoration(
        color: MapUi.panelColor(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _searchRow(
            leading: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: accent, width: 3.5),
              ),
            ),
            hint: app.t('Pickup location', 'Eneo la kuchukuliwa'),
            ctrl: _fromCtrl,
            focus: _fromFocus,
            onChanged: (v) => _searchPlaces(v, forPickup: true),
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: app.t('Use my location', 'Tumia eneo langu'),
              icon: Icon(Icons.gps_fixed_rounded, size: 19, color: accent),
              onPressed: () {
                FocusScope.of(context).unfocus();
                _loadCurrentLocation();
              },
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 12,
                child: Center(child: Container(width: 2, height: 14, color: muted.withValues(alpha: 0.35))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Divider(height: 1, color: muted.withValues(alpha: 0.18))),
              const SizedBox(width: 6),
            ],
          ),
          _searchRow(
            leading: Icon(Icons.location_on_rounded, size: 18, color: AppColors.coral),
            hint: app.t('Where to?', 'Unakwenda wapi?'),
            ctrl: _toCtrl,
            focus: _toFocus,
            onChanged: (v) => _searchPlaces(v, forPickup: false),
            trailing: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _toCtrl,
              builder: (_, v, __) => v.text.isEmpty
                  ? const SizedBox(width: 40, height: 40)
                  : IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: app.t('Clear', 'Futa'),
                      icon: Icon(Icons.close_rounded, size: 19, color: muted),
                      onPressed: _clearDestination,
                    ),
            ),
          ),
          if (_placesLoading)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(minHeight: 2.5, color: accent, backgroundColor: accent.withValues(alpha: 0.15)),
              ),
            ),
          if (_placeSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8, right: 8),
              constraints: BoxConstraints(maxHeight: suggestionMax),
              decoration: BoxDecoration(
                color: MapUi.panelSubtle(isDark),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: _placeSuggestions.length,
                separatorBuilder: (_, __) => Divider(height: 1, indent: 44, color: muted.withValues(alpha: 0.15)),
                itemBuilder: (context, index) {
                  final place = _placeSuggestions[index];
                  final fmt = place['structured_formatting'];
                  final mainText = (fmt is Map ? (fmt['main_text'] ?? place['description']) : place['description']).toString();
                  final secondary = (fmt is Map ? (fmt['secondary_text'] ?? '') : '').toString();
                  return InkWell(
                    onTap: () => _selectPlace(place),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(color: accent.withValues(alpha: 0.13), shape: BoxShape.circle),
                            child: Icon(Icons.place_outlined, size: 17, color: accent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(mainText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                if (secondary.isNotEmpty)
                                  Text(secondary,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchRow({
    required Widget leading,
    required String hint,
    required TextEditingController ctrl,
    required FocusNode focus,
    required ValueChanged<String> onChanged,
    required Widget trailing,
  }) {
    return Row(
      children: [
        SizedBox(width: 12, child: Center(child: leading)),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: ctrl,
            focusNode: focus,
            onChanged: onChanged,
            maxLines: 1,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        trailing,
      ],
    );
  }

  // ------------------------------------------------------------------ bottom sheet

  Widget _buildRideSheet(AppProvider app, bool isDark, bool compact, Color accent) {
    final muted = MapUi.textSecondary(isDark);
    final route = _route;
    final hPad = compact ? 14.0 : 18.0;

    return Container(
      decoration: BoxDecoration(
        color: MapUi.panelColor(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 38, height: 4, decoration: BoxDecoration(color: muted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, compact ? 10 : 14, hPad, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    app.t('Choose a ride', 'Chagua usafiri'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: compact ? 16 : 18, fontWeight: FontWeight.w800),
                  ),
                ),
                if (route != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: accent.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route_rounded, size: 14, color: accent),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '${_eta != null ? '$_eta min' : route.durationLabel} · ${route.distanceLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPad - 4),
              child: Column(
                children: [
                  ...AppConstants.rideTypes.map((r) => _rideTile(app, r, isDark, compact, accent)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickPaymentMethod,
                          style: _smallOutlined(accent, muted),
                          icon: const Icon(Icons.account_balance_wallet_outlined, size: 17),
                          label: Text(
                            AppConstants.paymentMethods
                                .firstWhere((m) => m['id'] == _paymentMethod, orElse: () => AppConstants.paymentMethods[0])['name']
                                .toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickSavedDestination,
                          style: _smallOutlined(accent, muted),
                          icon: const Icon(Icons.bookmark_border_rounded, size: 17),
                          label: Text(app.t('Saved', 'Imehifadhiwa'), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                  if (app.pendingPromoCode != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer, size: 16, color: AppColors.brightGreen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Promo ${app.pendingPromoCode} (-${formatTzs(app.pendingDiscount, withCurrency: false)})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.brightGreen),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              app.clearPromo();
                              setState(() {});
                            },
                            child: Text(app.t('Clear', 'Futa'), style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  if (app.activeRide != null && app.activeRide!.isActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Material(
                        color: accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => RideDetailsScreen(existingRide: app.activeRide)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            child: Row(
                              children: [
                                Icon(Icons.directions_car_filled_rounded, color: accent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    app.t('Active ride · ${app.activeRide!.status}', 'Safari hai · ${app.activeRide!.status}'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 10, hPad, compact ? 12 : 16),
            child: SizedBox(
              width: double.infinity,
              height: compact ? 48 : 52,
              child: ElevatedButton(
                onPressed: _searching ? null : _requestRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brightGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _searching
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(app.t('Request Ride', 'Omba Safari'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _smallOutlined(Color accent, Color muted) => OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: muted.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        minimumSize: const Size(0, 42),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );

  Widget _rideTile(AppProvider app, Map<String, dynamic> r, bool isDark, bool compact, Color accent) {
    final id = (r['id'] ?? '').toString();
    final selected = _selectedRideType == id;
    final muted = MapUi.textSecondary(isDark);
    final fare = _fares[id];
    final hasQuoteContext = _toLat != null && context.read<AppProvider>().currentLat != 0;
    final subtitle = _fares.containsKey(id)
        ? (fare != null ? app.t('Fixed fare', 'Nauli maalum') : app.t('Tap to retry quote', 'Gusa kujaribu tena'))
        : (hasQuoteContext
            ? app.t('Getting quote…', 'Inapata bei…')
            : app.t('Select pickup & destination', 'Chagua eneo la kuchukuliwa na kwenda'));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? accent.withValues(alpha: isDark ? 0.16 : 0.09) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectRide(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 9 : 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? accent : muted.withValues(alpha: 0.2), width: selected ? 1.6 : 1),
            ),
            child: Row(
              children: [
                Container(
                  width: compact ? 38 : 44,
                  height: compact ? 38 : 44,
                  decoration: BoxDecoration(
                    color: selected ? accent : accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(r['icon'] as IconData, size: compact ? 22 : 26, color: selected ? Colors.white : accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (app.isSwahili ? r['nameSw'] : r['name']).toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (fare != null)
                  Text(formatTzs(fare), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))
                else if (_fares.isEmpty && hasQuoteContext)
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap, bool isDark) {
    final accent = MapUi.accent(isDark);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: MapUi.panelColor(isDark),
        elevation: 3,
        shadowColor: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: accent),
                const SizedBox(width: 7),
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
