class RideModel {
  final String id;
  final String rideType;
  final String fromAddress;
  final String toAddress;
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final double estimatedFare;
  final double? finalFare;
  final int etaMinutes;
  final String status; // searching, accepted, arriving, arrived, started, completed, cancelled
  final DriverModel? driver;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? paymentMethod;
  final String? cancelReason;
  final String? promoCode;
  final double? discount;
  final int? rating;
  final String? feedback;
  final double? tip;
  final String? tripPin;

  RideModel({
    required this.id,
    required this.rideType,
    required this.fromAddress,
    required this.toAddress,
    this.fromLat = -6.1659,
    this.fromLng = 39.2026,
    this.toLat = -6.1659,
    this.toLng = 39.2026,
    required this.estimatedFare,
    this.finalFare,
    required this.etaMinutes,
    this.status = 'searching',
    this.driver,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
    this.paymentMethod,
    this.cancelReason,
    this.promoCode,
    this.discount,
    this.rating,
    this.feedback,
    this.tip,
    this.tripPin,
  }) : createdAt = createdAt ?? DateTime.now();

  RideModel copyWith({
    String? status,
    DriverModel? driver,
    DateTime? startedAt,
    DateTime? completedAt,
    String? cancelReason,
    String? paymentMethod,
    double? finalFare,
    String? promoCode,
    double? discount,
    int? rating,
    String? feedback,
    double? tip,
    String? tripPin,
    int? etaMinutes,
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
  }) {
    return RideModel(
      id: id,
      rideType: rideType,
      fromAddress: fromAddress,
      toAddress: toAddress,
      fromLat: fromLat ?? this.fromLat,
      fromLng: fromLng ?? this.fromLng,
      toLat: toLat ?? this.toLat,
      toLng: toLng ?? this.toLng,
      estimatedFare: estimatedFare,
      finalFare: finalFare ?? this.finalFare,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      status: status ?? this.status,
      driver: driver ?? this.driver,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cancelReason: cancelReason ?? this.cancelReason,
      promoCode: promoCode ?? this.promoCode,
      discount: discount ?? this.discount,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
      tip: tip ?? this.tip,
      tripPin: tripPin ?? this.tripPin,
    );
  }

  bool get isActive =>
      status == 'searching' ||
      status == 'accepted' ||
      status == 'arriving' ||
      status == 'arrived' ||
      status == 'started';

  bool get isTerminal => status == 'completed' || status == 'cancelled';
}

class DriverModel {
  final String id;
  final String name;
  final String phone;
  final String photoUrl;
  final String vehicleNumber;
  final String vehicleType;
  final double rating;
  final int totalRides;
  final double lat;
  final double lng;

  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    this.photoUrl = '',
    required this.vehicleNumber,
    required this.vehicleType,
    this.rating = 4.8,
    this.totalRides = 120,
    this.lat = -6.1659,
    this.lng = 39.2026,
  });

  DriverModel copyWith({double? lat, double? lng}) {
    return DriverModel(
      id: id,
      name: name,
      phone: phone,
      photoUrl: photoUrl,
      vehicleNumber: vehicleNumber,
      vehicleType: vehicleType,
      rating: rating,
      totalRides: totalRides,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId; // 'me', 'driver', 'support'
  final String text;
  final DateTime timestamp;
  final bool isTranslated;
  final String? originalText;
  final String? replyToId;
  final List<String> reactions;
  final bool isDeleted;
  final bool isEdited;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    DateTime? timestamp,
    this.isTranslated = false,
    this.originalText,
    this.replyToId,
    this.reactions = const [],
    this.isDeleted = false,
    this.isEdited = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatConversation {
  final String id;
  final String title;
  final String? avatarUrl;
  final bool isSupport;
  final bool isPinned;
  final List<ChatMessage> messages;
  final DateTime lastMessageAt;

  ChatConversation({
    required this.id,
    required this.title,
    this.avatarUrl,
    this.isSupport = false,
    this.isPinned = false,
    this.messages = const [],
    DateTime? lastMessageAt,
  }) : lastMessageAt = lastMessageAt ?? DateTime.now();

  ChatConversation copyWith({
    List<ChatMessage>? messages,
    DateTime? lastMessageAt,
    bool? isPinned,
  }) {
    return ChatConversation(
      id: id,
      title: title,
      avatarUrl: avatarUrl,
      isSupport: isSupport,
      isPinned: isPinned ?? this.isPinned,
      messages: messages ?? this.messages,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }
}

class TransactionModel {
  final String id;
  final String type; // topup, ride, refund, tip, promo
  final String title;
  final double amount; // positive = credit, negative = debit
  final String? reference;
  final String? paymentMethod;
  final DateTime createdAt;
  final String status; // success, pending, failed

  TransactionModel({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    this.reference,
    this.paymentMethod,
    DateTime? createdAt,
    this.status = 'success',
  }) : createdAt = createdAt ?? DateTime.now();
}
