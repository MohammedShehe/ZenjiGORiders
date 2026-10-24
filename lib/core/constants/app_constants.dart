import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'ZenjiGO';
  static const String appVersion = '1.0.0';
  static const String orgPhone = '+255 676 891 227';
  static const String orgEmail = 'support@zenjigo.online';
  static const String orgInstagram = 'zenjigo';
  static const String privacyUrl = 'https://zenjigo.com/privacy';
  static const String termsUrl = 'https://zenjigo.com/terms';

  // Ride types
  static const List<Map<String, dynamic>> rideTypes = [
    {'id': 'boda', 'name': 'Boda', 'nameSw': 'Boda', 'icon': Icons.two_wheeler_rounded},
    {'id': 'bajaji', 'name': 'Bajaji', 'nameSw': 'Bajaji', 'icon': Icons.electric_rickshaw_rounded},
    {'id': 'taxi', 'name': 'Taxi', 'nameSw': 'Teksi', 'icon': Icons.local_taxi_rounded},
  ];

  // Payment methods
  static const List<Map<String, dynamic>> paymentMethods = [
    {'id': 'cash', 'name': 'Cash', 'nameSw': 'Fedha Taslimu', 'icon': Icons.payments_rounded},
    {'id': 'momo', 'name': 'Mobile Money', 'nameSw': 'Pesa za Simu', 'icon': Icons.phone_android_rounded},
    {'id': 'bank', 'name': 'Bank Card', 'nameSw': 'Kadi ya Benki', 'icon': Icons.credit_card_rounded},
    {'id': 'wallet', 'name': 'ZenjiGO Wallet', 'nameSw': 'Pochi ya ZenjiGO', 'icon': Icons.account_balance_wallet_rounded},
  ];

  static const List<Map<String, String>> mobileProviders = [
    {'id': 'mpesa', 'name': 'M-Pesa', 'code': 'MPESA'},
    {'id': 'tigo', 'name': 'Mix by Yas (Tigo)', 'code': 'TIGO'},
    {'id': 'airtel', 'name': 'Airtel Money', 'code': 'AIRTEL'},
    {'id': 'halopesa', 'name': 'HaloPesa', 'code': 'HALO'},
  ];
}
