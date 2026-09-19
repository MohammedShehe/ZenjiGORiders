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
  final int etaMinutes;
  final String status; // searching, accepted, arrived, started, completed, cancelled
  final DriverModel? driver;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? paymentMethod;
  final String? cancelReason;

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
    required this.etaMinutes,
    this.status = 'searching',
    this.driver,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
    this.paymentMethod,
    this.cancelReason,
  }) : createdAt = createdAt ?? DateTime.now();

  RideModel copyWith({
    String? status,
    DriverModel? driver,
    DateTime? startedAt,
    DateTime? completedAt,
    String? cancelReason,
  }) {
    return RideModel(
      id: id,
      rideType: rideType,
      fromAddress: fromAddress,
      toAddress: toAddress,
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
      estimatedFare: estimatedFare,
      etaMinutes: etaMinutes,
      status: status ?? this.status,
      driver: driver ?? this.driver,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      paymentMethod: paymentMethod,
      cancelReason: cancelReason ?? this.cancelReason,
    );
  }
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
}
