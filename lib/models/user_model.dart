class UserModel {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? photoUrl;
  final String island;
  final String region;
  final String district;
  final String ward;
  final double walletBalance;
  final List<PaymentMethodModel> paymentMethods;
  final List<SavedLocationModel> savedLocations;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.photoUrl,
    required this.island,
    required this.region,
    required this.district,
    required this.ward,
    this.walletBalance = 0,
    this.paymentMethods = const [],
    this.savedLocations = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  UserModel copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    String? photoUrl,
    String? island,
    String? region,
    String? district,
    String? ward,
    double? walletBalance,
    List<PaymentMethodModel>? paymentMethods,
    List<SavedLocationModel>? savedLocations,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      island: island ?? this.island,
      region: region ?? this.region,
      district: district ?? this.district,
      ward: ward ?? this.ward,
      walletBalance: walletBalance ?? this.walletBalance,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      savedLocations: savedLocations ?? this.savedLocations,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'photoUrl': photoUrl,
        'island': island,
        'region': region,
        'district': district,
        'ward': ward,
        'walletBalance': walletBalance,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] ?? '',
        fullName: json['fullName'] ?? '',
        phone: json['phone'] ?? '',
        email: json['email'],
        photoUrl: json['photoUrl'],
        island: json['island'] ?? '',
        region: json['region'] ?? '',
        district: json['district'] ?? '',
        ward: json['ward'] ?? '',
        walletBalance: (json['walletBalance'] ?? 0).toDouble(),
      );
}

class PaymentMethodModel {
  final String id;
  final String type; // cash, momo, bank, wallet
  final String? provider;
  final String? accountNumber;
  final String? cardLast4;
  final String? expiry;
  final bool isDefault;

  PaymentMethodModel({
    required this.id,
    required this.type,
    this.provider,
    this.accountNumber,
    this.cardLast4,
    this.expiry,
    this.isDefault = false,
  });
}

class SavedLocationModel {
  final String id;
  final String label; // Home, Work, Hotel, Other
  final String address;
  final String island;
  final String region;
  final String district;
  final String ward;
  final double? lat;
  final double? lng;

  SavedLocationModel({
    required this.id,
    required this.label,
    required this.address,
    required this.island,
    required this.region,
    required this.district,
    required this.ward,
    this.lat,
    this.lng,
  });
}
