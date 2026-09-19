class AppConstants {
  static const String appName = 'ZenjiGO';
  static const String orgPhone = '+255 676 891 227';
  static const String orgEmail = 'zenjigo@support.com';
  static const String orgInstagram = 'zenjigo';
  static const String privacyUrl = 'https://zenjigo.com/privacy';
  static const String termsUrl = 'https://zenjigo.com/terms';

  // Default OTP for demo (frontend only)
  static const String demoOtp = '1234';

  // Ride types
  static const List<Map<String, dynamic>> rideTypes = [
    {'id': 'boda', 'name': 'Boda', 'nameSw': 'Boda', 'icon': '🏍️', 'baseFare': 1500, 'perKm': 400},
    {'id': 'bajaji', 'name': 'Bajaji', 'nameSw': 'Bajaji', 'icon': '🛺', 'baseFare': 2500, 'perKm': 600},
    {'id': 'taxi', 'name': 'Taxi', 'nameSw': 'Teksi', 'icon': '🚕', 'baseFare': 5000, 'perKm': 1200},
    {'id': 'airport', 'name': 'Airport', 'nameSw': 'Uwanja', 'icon': '✈️', 'baseFare': 15000, 'perKm': 2000},
    {'id': 'parcel', 'name': 'Parcel', 'nameSw': 'Kifurushi', 'icon': '📦', 'baseFare': 2000, 'perKm': 500},
  ];

  // Payment methods
  static const List<Map<String, dynamic>> paymentMethods = [
    {'id': 'cash', 'name': 'Cash', 'nameSw': 'Fedha Taslimu', 'icon': '💵'},
    {'id': 'momo', 'name': 'Mobile Money', 'nameSw': 'Pesa za Simu', 'icon': '📱'},
    {'id': 'bank', 'name': 'Bank Card', 'nameSw': 'Kadi ya Benki', 'icon': '💳'},
    {'id': 'wallet', 'name': 'ZenjiGO Wallet', 'nameSw': 'Pochi ya ZenjiGO', 'icon': '👛'},
  ];

  static const List<Map<String, String>> mobileProviders = [
    {'id': 'mpesa', 'name': 'M-Pesa', 'code': 'MPESA'},
    {'id': 'tigo', 'name': 'Mix by Yas (Tigo)', 'code': 'TIGO'},
    {'id': 'airtel', 'name': 'Airtel Money', 'code': 'AIRTEL'},
    {'id': 'halopesa', 'name': 'HaloPesa', 'code': 'HALO'},
  ];
}
