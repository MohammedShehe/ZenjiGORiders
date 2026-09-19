import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../home/home_screen.dart';
import 'parcel_screen.dart';
import 'tour_packages_screen.dart';

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});

  static const offers = [
    {'code': 'ZENJI50', 'desc': '50% off your first 3 rides'},
    {'code': 'WEEKEND20', 'desc': '20% off weekend airport transfers'},
    {'code': 'PARCEL10', 'desc': 'TZS 1000 off parcel deliveries'},
    {'code': 'TOUR15', 'desc': '15% off full-day tour packages'},
  ];

  void _open(BuildContext context, String code, String description) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfferDetailsScreen(code: code, description: description),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promotions & Offers')),
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
              title: Text(offer['code']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(offer['desc']!),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, offer['code']!, offer['desc']!),
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
  const OfferDetailsScreen({super.key, required this.code, required this.description});

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer code copied.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offer Details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.local_offer, size: 72),
          const SizedBox(height: 18),
          Text(code, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center),
          const SizedBox(height: 22),
          OutlinedButton.icon(onPressed: () => _copy(context), icon: const Icon(Icons.copy), label: const Text('Copy Code')),
          const SizedBox(height: 14),
          const Text('Choose a service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.local_taxi),
            title: const Text('Use for a Ride'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping),
            title: const Text('Use for Parcel Delivery'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParcelScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.tour),
            title: const Text('Use for Tour Package'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TourPackagesScreen())),
          ),
        ],
      ),
    );
  }
}
