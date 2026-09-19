import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../ride/ride_details_screen.dart';
import '../extras/parcel_screen.dart';
import '../extras/tour_packages_screen.dart';
import '../extras/promotions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fromCtrl = TextEditingController(text: 'Current Location');
  final _toCtrl = TextEditingController();
  String? _selectedRideType;
  bool _searching = false;
  double? _estimatedFare;
  int? _eta;
  String _paymentMethod = 'cash';
  double? _toLat;
  double? _toLng;

  // Zanzibar center
  static const LatLng _zanzibarCenter = LatLng(-6.1659, 39.2026);

  final List<LatLng> _nearbyDrivers = [
    const LatLng(-6.1620, 39.2050),
    const LatLng(-6.1680, 39.1980),
    const LatLng(-6.1600, 39.2100),
    const LatLng(-6.1720, 39.2000),
    const LatLng(-6.1580, 39.1950),
  ];

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppProvider>();
      if (app.currentAddress.isNotEmpty) {
        _fromCtrl.text = app.currentAddress;
      }
    });
  }

  void _selectRide(String id) {
    setState(() {
      _selectedRideType = id;
      if (_toCtrl.text.isNotEmpty) {
        final type = AppConstants.rideTypes.firstWhere((r) => r['id'] == id);
        _estimatedFare = (type['baseFare'] as int) + (type['perKm'] as int) * 8.0;
        _eta = 12 + (id == 'airport' ? 20 : 5);
      }
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
      final fare = (_estimatedFare ?? 5000) - app.pendingDiscount;
      if (!app.hasSufficientWallet(fare)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(app.t('Insufficient wallet balance', 'Salio la pochi haitoshi'))),
        );
        return;
      }
    }
    // Mock destination coords if not set (simple hash of text for demo)
    _toLat ??= -6.1659 + (_toCtrl.text.hashCode % 100) / 5000.0;
    _toLng ??= 39.2026 + (_toCtrl.text.hashCode % 80) / 5000.0;

    setState(() => _searching = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _searching = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RideDetailsScreen(
          rideType: _selectedRideType!,
          from: _fromCtrl.text,
          to: _toCtrl.text,
          fare: _estimatedFare ?? 5000,
          eta: _eta ?? 15,
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
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(app.t('Payment method', 'Njia ya malipo'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ...AppConstants.paymentMethods.map((m) {
                final id = m['id'] as String;
                final disabled = id == 'wallet' && app.walletBalance <= 0;
                return ListTile(
                  leading: Text(m['icon'] as String, style: const TextStyle(fontSize: 24)),
                  title: Text(app.isSwahili ? m['nameSw'] as String : m['name'] as String),
                  subtitle: id == 'wallet' ? Text('TZS ${app.walletBalance.toStringAsFixed(0)}') : null,
                  trailing: _paymentMethod == id ? const Icon(Icons.check, color: AppColors.brightGreen) : null,
                  enabled: !disabled,
                  onTap: disabled ? null : () => Navigator.pop(ctx, id),
                );
              }),
              const SizedBox(height: 8),
            ],
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
        if (_selectedRideType != null) {
          final type = AppConstants.rideTypes.firstWhere((r) => r['id'] == _selectedRideType);
          _estimatedFare = (type['baseFare'] as int) + (type['perKm'] as int) * 8.0;
          _eta = 15;
        }
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
          // Map
          FlutterMap(
            options: MapOptions(
              initialCenter: _zanzibarCenter,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
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
                    point: _zanzibarCenter,
                    width: 40,
                    height: 40,
                    child: Icon(Icons.my_location, color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal, size: 28),
                  ),
                  ..._nearbyDrivers.map((p) => Marker(
                        point: p,
                        width: 36,
                        height: 36,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.brightGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.two_wheeler, color: Colors.white, size: 18),
                        ),
                      )),
                ],
              ),
            ],
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
                      color: isDark ? AppColors.darkSurface.withOpacity(0.95) : Colors.white.withOpacity(0.97),
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
                            onChanged: (v) {
                          if (v.isNotEmpty && _selectedRideType != null) {
                            final type = AppConstants.rideTypes.firstWhere((r) => r['id'] == _selectedRideType);
                            setState(() {
                              _estimatedFare = (type['baseFare'] as int) + (type['perKm'] as int) * 8.0;
                              _eta = 15;
                            });
                          }
                        }),
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
                color: isDark ? AppColors.darkSurface : Colors.white,
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
                          onTap: () => _selectRide(r['id'] as String),
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
                                Text(r['icon'] as String, style: const TextStyle(fontSize: 28)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app.isSwahili ? r['nameSw'] as String : r['name'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                      Text(
                                        'TZS ${r['baseFare']}+',
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
                              AppConstants.paymentMethods.firstWhere((m) => m['id'] == _paymentMethod, orElse: () => AppConstants.paymentMethods[0])['name'] as String,
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
        backgroundColor: isDark ? AppColors.darkSurface.withOpacity(0.9) : Colors.white.withOpacity(0.95),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 2,
        shadowColor: Colors.black26,
      ),
    );
  }
}
