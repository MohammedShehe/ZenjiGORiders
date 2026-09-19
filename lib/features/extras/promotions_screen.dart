import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import 'parcel_screen.dart';
import 'tour_packages_screen.dart';

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});

  static const offers = [
    {'code': 'ZENJI50', 'desc': '50% off your first 3 rides', 'discount': 2500.0},
    {'code': 'WEEKEND20', 'desc': '20% off weekend airport transfers', 'discount': 3000.0},
    {'code': 'PARCEL10', 'desc': 'TZS 1000 off parcel deliveries', 'discount': 1000.0},
    {'code': 'TOUR15', 'desc': '15% off full-day tour packages', 'discount': 5000.0},
  ];

  void _open(BuildContext context, Map offer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfferDetailsScreen(
          code: offer['code'] as String,
          description: offer['desc'] as String,
          discount: offer['discount'] as double,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(app.t('Promotions & Offers', 'Ofa & Promosheni'))),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: offers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final offer = offers[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(child: Icon(Icons.local_offer)),
              title: Text(offer['code'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(offer['desc'] as String),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, offer),
            ),
          );
        },
      ),
    );
  }
}

class OfferDetailsScreen extends StatelessWidget {
  final String code;
  final String description;
  final double discount;
  const OfferDetailsScreen({
    super.key,
    required this.code,
    required this.description,
    required this.discount,
  });

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    final app = context.read<AppProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(app.t('Offer code copied.', 'Nambari ya ofa imenakiliwa.'))),
    );
  }

  void _applyAndGoHome(BuildContext context) {
    final app = context.read<AppProvider>();
    app.applyPromo(code, discount);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(app.t('Promo $code applied', 'Promo $code imetumika'))),
    );
    // Pop back to MainShell home rather than pushing a standalone HomeScreen
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(app.t('Offer Details', 'Maelezo ya Ofa'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.local_offer, size: 72),
          const SizedBox(height: 18),
          Text(code, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            app.t('Discount: TZS ${discount.toStringAsFixed(0)}', 'Punguzo: TZS ${discount.toStringAsFixed(0)}'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy),
            label: Text(app.t('Copy Code', 'Nakili Nambari')),
          ),
          const SizedBox(height: 14),
          Text(app.t('Choose a service', 'Chagua huduma'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.local_taxi),
            title: Text(app.t('Use for a Ride', 'Tumia kwa Safari')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _applyAndGoHome(context),
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping),
            title: Text(app.t('Use for Parcel Delivery', 'Tumia kwa Kifurushi')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.read<AppProvider>().applyPromo(code, discount);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ParcelScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.tour),
            title: Text(app.t('Use for Tour Package', 'Tumia kwa Ziara')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.read<AppProvider>().applyPromo(code, discount);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TourPackagesScreen()));
            },
          ),
        ],
      ),
    );
  }
}
