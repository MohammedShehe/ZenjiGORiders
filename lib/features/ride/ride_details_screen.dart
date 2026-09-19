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

class RideDetailsScreen extends StatefulWidget {
  final String rideType;
  final String from;
  final String to;
  final double fare;
  final int eta;

  const RideDetailsScreen({
    super.key,
    required this.rideType,
    required this.from,
    required this.to,
    required this.fare,
    required this.eta,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  String _status = 'searching';
  DriverModel? _driver;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _findDriver();
  }

  Future<void> _findDriver() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = 'accepted';
      _driver = DriverModel(
        id: 'd1',
        name: 'Juma Hassan',
        phone: '+255712345678',
        vehicleNumber: 'T 789 XYZ',
        vehicleType: widget.rideType,
        rating: 4.9,
        totalRides: 342,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;
    final type = AppConstants.rideTypes.firstWhere((r) => r['id'] == widget.rideType, orElse: () => AppConstants.rideTypes[0]);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(initialCenter: LatLng(-6.1659, 39.2026), initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.zenjigo.riders',
              ),
              const MarkerLayer(markers: [
                Marker(point: LatLng(-6.1659, 39.2026), width: 40, height: 40, child: Icon(Icons.person_pin_circle, color: AppColors.brightGreen, size: 36)),
                Marker(point: LatLng(-6.1700, 39.2100), width: 40, height: 40, child: Icon(Icons.location_on, color: AppColors.sunsetOrange, size: 36)),
              ]),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CircleAvatar(
                backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
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
              child: _loading
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(app.t('Finding nearby drivers...', 'Inatafuta madereva karibu...')),
                        const SizedBox(height: 20),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Status bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.brightGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            app.t('Driver Accepted · ETA ${widget.eta} min', 'Dereva Amekubali · ETA ${widget.eta} dak'),
                            style: const TextStyle(color: AppColors.brightGreen, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Driver info
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                              child: Text(_driver!.name[0], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_driver!.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: AppColors.sunsetOrange, size: 16),
                                      Text(' ${_driver!.rating} · ${_driver!.totalRides} ${app.t('rides', 'safari')}'),
                                    ],
                                  ),
                                  Text('${_driver!.vehicleNumber} · ${type['name']}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                                ],
                              ),
                            ),
                            Text('TZS ${widget.fare.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => launchUrl(Uri.parse('tel:${_driver!.phone}')),
                                icon: const Icon(Icons.phone),
                                label: Text(app.t('Call', 'Piga')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatDetailScreen(
                                        conversation: ChatConversation(
                                          id: _driver!.id,
                                          title: _driver!.name,
                                          messages: [],
                                        ),
                                      ),
                                    ),
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
                                  // Share via WhatsApp
                                  final text = Uri.encodeComponent('I\'m on a ZenjiGO ride to ${widget.to}. Track me!');
                                  launchUrl(Uri.parse('https://wa.me/?text=$text'));
                                },
                                icon: const Icon(Icons.share),
                                label: Text(app.t('Share', 'Shiriki')),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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
                                child: Text(app.t('Report', 'Ripoti'), style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
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

  Future<void> _cancelRide(AppProvider app) async {
    final reasons = ['Driver taking too long', 'Changed plans', 'Found another ride', 'Driver requested cancellation', 'Other'];
    String? selected;
    final manual = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
        title: Text(app.t('Cancel Ride', 'Ghairi Safari')),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          ...reasons.map((r) => RadioListTile<String>(value: r, groupValue: selected, title: Text(r), onChanged: (v) => set(() => selected = v))),
          if (selected == 'Other') TextField(controller: manual, maxLines: 3, decoration: const InputDecoration(labelText: 'Describe the issue')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.t('Back', 'Rudi'))),
          ElevatedButton(onPressed: selected == null ? null : () { final reason = selected == 'Other' ? manual.text.trim() : selected!; if (selected == 'Other' && reason.isEmpty) return; Navigator.pop(ctx, reason); }, child: Text(app.t('Continue', 'Endelea'))),
        ],
      )),
    );
    manual.dispose();
    if (!mounted || result == null) return;
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(app.t('Confirm cancellation', 'Thibitisha kughairi')),
      content: Text(app.t('Cancel this ride? Reason: $result', 'Ghairi safari hii? Sababu: $result')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(app.t('Keep Ride', 'Endelea na Safari'))), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(app.t('Cancel Ride', 'Ghairi Safari')))],
    ));
    if (confirm == true && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.t('Ride cancelled successfully.', 'Safari imeghairiwa kikamilifu.'))));
    }
  }

  Future<void> _reportDriver(AppProvider app) async {
    final reasons = ['Unsafe driving', 'Rude behaviour', 'Wrong route', 'Vehicle issue', 'Other'];
    String? selected; final manual = TextEditingController();
    final result = await showDialog<String>(context: context, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text(app.t('Report Driver', 'Ripoti Dereva')),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        ...reasons.map((r) => RadioListTile<String>(value: r, groupValue: selected, title: Text(r), onChanged: (v) => set(() => selected = v))),
        if (selected == 'Other') TextField(controller: manual, maxLines: 3, decoration: const InputDecoration(labelText: 'Describe the issue')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.t('Cancel', 'Ghairi'))), ElevatedButton(onPressed: selected == null ? null : () { final reason = selected == 'Other' ? manual.text.trim() : selected!; if (selected == 'Other' && reason.isEmpty) return; Navigator.pop(ctx, reason); }, child: Text(app.t('Submit Report', 'Tuma Ripoti')))],
    )));
    manual.dispose();
    if (!mounted || result == null) return;
    await showDialog(context: context, builder: (_) => AlertDialog(title: Text(app.t('Report submitted', 'Ripoti imetumwa')), content: Text(app.t('Thank you. Your report reason was recorded: $result', 'Asante. Sababu ya ripoti imehifadhiwa: $result')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))]));
  }

}
