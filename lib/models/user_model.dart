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

  // API identifiers and profile fields may arrive as numbers from older
  // backend records. Normalize them before assigning to strongly typed fields.
  static String _stringValue(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return value.toString();
  }

  static String? _nullableStringValue(dynamic value) {
    if (value == null) return null;
    final result = _stringValue(value).trim();
    return result.isEmpty ? null : result;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: _stringValue(json['id'] ?? json['_id'] ?? json['riderId']),
        fullName: _stringValue(json['fullName'] ?? json['full_name'] ?? json['name']),
        phone: _stringValue(json['phone'] ?? json['phoneNumber'] ?? json['phone_number']),
        email: _nullableStringValue(json['email']),
        photoUrl: _nullableStringValue(json['photoUrl'] ?? json['photo_url'] ?? json['avatar']),
        island: _stringValue(json['island']),
        region: _stringValue(json['region'] ?? json['area']),
        district: _stringValue(json['district']),
        ward: _stringValue(json['ward']),
        walletBalance: double.tryParse((json['walletBalance'] ?? json['wallet_balance'] ?? 0).toString()) ?? 0,
        paymentMethods: (json['paymentMethods'] is List ? json['paymentMethods'] as List : const [])
            .whereType<Map>().map((e) => PaymentMethodModel.fromJson(Map<String, dynamic>.from(e))).toList(),
        savedLocations: (json['savedLocations'] is List ? json['savedLocations'] as List : const [])
            .whereType<Map>().map((e) => SavedLocationModel.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
}

class PaymentMethodModel {
  final String id;
  final String type; // cash, momo, bank, wallet
  final String? provider;
  final String? accountNumber;
  final String? cardLast4;
  final String? expiry;
  final String? cardHolder;
  final String? cardBrand; // visa, mastercard, amex, discover, unknown
  final bool isDefault;

  PaymentMethodModel({
    required this.id,
    required this.type,
    this.provider,
    this.accountNumber,
    this.cardLast4,
    this.expiry,
    this.cardHolder,
    this.cardBrand,
    this.isDefault = false,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) => PaymentMethodModel(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        type: (json['type'] ?? 'cash').toString() == 'card' ? 'bank' : (json['type'] ?? 'cash').toString(),
        provider: (json['provider'] ?? json['label'])?.toString(),
        accountNumber: (json['account'] ?? json['accountNumber'])?.toString(),
        cardLast4: (json['last4'] ?? json['cardLast4'])?.toString(),
        expiry: json['expiry']?.toString(),
        cardHolder: (json['label'] ?? json['cardHolder'])?.toString(),
        cardBrand: (json['provider'] ?? json['cardBrand'])?.toString(),
        isDefault: json['isDefault'] == true || json['is_default'] == true,
      );

  PaymentMethodModel copyWith({bool? isDefault}) => PaymentMethodModel(
        id: id,
        type: type,
        provider: provider,
        accountNumber: accountNumber,
        cardLast4: cardLast4,
        expiry: expiry,
        cardHolder: cardHolder,
        cardBrand: cardBrand,
        isDefault: isDefault ?? this.isDefault,
      );
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

  factory SavedLocationModel.fromJson(Map<String, dynamic> json) => SavedLocationModel(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        label: (json['label'] ?? json['name'] ?? 'Place').toString(),
        address: (json['address'] ?? '').toString(),
        island: (json['island'] ?? '').toString(),
        region: (json['region'] ?? '').toString(),
        district: (json['district'] ?? '').toString(),
        ward: (json['ward'] ?? '').toString(),
        lat: double.tryParse((json['lat'] ?? json['latitude'] ?? '').toString()),
        lng: double.tryParse((json['lng'] ?? json['longitude'] ?? '').toString()),
      );

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
