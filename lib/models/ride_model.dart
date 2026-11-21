/// The person actually riding when a ride was booked for someone else ("Book for a friend").
class PassengerInfo {
  final String name;
  final String phone;
  final String? note;
  const PassengerInfo({required this.name, required this.phone, this.note});

  factory PassengerInfo.fromJson(Map<String, dynamic> m) => PassengerInfo(
        name: (m['name'] ?? '').toString(),
        phone: (m['phone'] ?? '').toString(),
        note: (m['note'] == null || m['note'].toString().trim().isEmpty) ? null : m['note'].toString(),
      );

  Map<String, dynamic> toBody() => {
        'bookedForOther': true,
        'passengerName': name,
        'passengerPhone': phone,
        if (note != null) 'passengerNote': note,
      };

  String get firstName => name.trim().split(' ').first;
}

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
  final String paymentStatus; // not_due | pending | awaiting_cash | processing | paid
  final bool reachedDestination;
  final double? amountDue;
  final bool canForceClose; // trip stuck because the driver vanished: rider may end it
  final PassengerInfo? passenger; // set when booked for someone else

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
    this.paymentStatus = 'not_due',
    this.reachedDestination = false,
    this.amountDue,
    this.canForceClose = false,
    this.passenger,
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
    String? paymentStatus,
    bool? reachedDestination,
    double? amountDue,
    double? estimatedFare,
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
    bool? canForceClose,
    bool clearDriver = false,
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
      estimatedFare: estimatedFare ?? this.estimatedFare,
      finalFare: finalFare ?? this.finalFare,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      status: status ?? this.status,
      driver: clearDriver ? null : (driver ?? this.driver),
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
      paymentStatus: paymentStatus ?? this.paymentStatus,
      reachedDestination: reachedDestination ?? this.reachedDestination,
      amountDue: amountDue ?? this.amountDue,
      canForceClose: canForceClose ?? this.canForceClose,
      passenger: passenger,
    );
  }

  static double _num(dynamic v, [double def = 0]) => double.tryParse((v ?? '').toString()) ?? def;
  static bool _flag(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

  /// Builds a ride from the API's ride JSON (used to resume an unfinished ride after a restart).
  factory RideModel.fromServer(Map<String, dynamic> m) {
    DriverModel? driver;
    if (m['driver'] is Map) {
      final d = Map<String, dynamic>.from(m['driver'] as Map);
      driver = DriverModel(
        id: (d['id'] ?? '').toString(),
        name: (d['fullName'] ?? d['name'] ?? 'Driver').toString(),
        phone: (d['phone'] ?? '').toString(),
        photoUrl: (d['photoUrl'] ?? '').toString(),
        vehicleNumber: (d['plateNumber'] ?? '').toString(),
        vehicleType: (d['vehicleType'] ?? m['ride_type'] ?? 'boda').toString(),
        rating: _num(d['rating']),
        totalRides: int.tryParse((d['totalRides'] ?? 0).toString()) ?? 0,
        lat: _num(d['lat']),
        lng: _num(d['lng']),
        vehicleDescription: [d['vehicleColor'], d['vehicleMake'], d['vehicleModel']]
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .join(' '),
      );
    }
    final pin = (m['trip_pin'] ?? m['tripPin'])?.toString();
    return RideModel(
      id: (m['id'] ?? m['ride_code'] ?? '').toString(),
      rideType: (m['ride_type'] ?? m['rideType'] ?? 'boda').toString(),
      fromAddress: (m['pickup_address'] ?? '').toString(),
      toAddress: (m['destination_address'] ?? '').toString(),
      fromLat: _num(m['pickup_lat']),
      fromLng: _num(m['pickup_lng']),
      toLat: _num(m['destination_lat']),
      toLng: _num(m['destination_lng']),
      estimatedFare: _num(m['estimated_fare']),
      finalFare: m['final_fare'] == null ? null : _num(m['final_fare']),
      etaMinutes: int.tryParse((m['estimated_duration_min'] ?? 0).toString()) ?? 0,
      status: (m['status'] ?? 'searching').toString().toLowerCase(),
      driver: driver,
      createdAt: DateTime.tryParse((m['created_at'] ?? '').toString())?.toLocal(),
      paymentMethod: (m['payment_method'] ?? 'cash').toString(),
      cancelReason: m['cancel_reason']?.toString(),
      promoCode: m['promo_code']?.toString(),
      discount: m['discount'] == null ? null : _num(m['discount']),
      tripPin: (pin != null && pin.isNotEmpty) ? pin : null,
      paymentStatus: (m['payment_status'] ?? 'not_due').toString(),
      reachedDestination: _flag(m['reached_destination']),
      amountDue: m['amount_due'] == null ? null : _num(m['amount_due']),
      canForceClose: _flag(m['can_force_close']),
      passenger: m['passenger'] is Map ? PassengerInfo.fromJson(Map<String, dynamic>.from(m['passenger'] as Map)) : null,
    );
  }

  /// Driver reached the drop-off: the rider must now pay.
  bool get awaitingPayment => status == 'started' && reachedDestination && paymentStatus != 'paid';

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
  final String vehicleDescription;

  DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    this.photoUrl = '',
    required this.vehicleNumber,
    required this.vehicleType,
    this.rating = 0,
    this.totalRides = 0,
    this.lat = 0,
    this.lng = 0,
    this.vehicleDescription = '',
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
      vehicleDescription: vehicleDescription,
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
  final bool isMine;

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
    this.isMine = false,
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
  final String lastMessagePreview;
  final int unreadCount;
  final String? rideId;
  final bool messagesLoaded;

  ChatConversation({
    required this.id,
    required this.title,
    this.avatarUrl,
    this.isSupport = false,
    this.isPinned = false,
    this.messages = const [],
    DateTime? lastMessageAt,
    this.lastMessagePreview = '',
    this.unreadCount = 0,
    this.rideId,
    this.messagesLoaded = false,
  }) : lastMessageAt = lastMessageAt ?? DateTime.now();

  ChatConversation copyWith({
    List<ChatMessage>? messages,
    DateTime? lastMessageAt,
    bool? isPinned,
    String? lastMessagePreview,
    int? unreadCount,
    bool? messagesLoaded,
  }) {
    return ChatConversation(
      id: id,
      title: title,
      avatarUrl: avatarUrl,
      isSupport: isSupport,
      isPinned: isPinned ?? this.isPinned,
      messages: messages ?? this.messages,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      unreadCount: unreadCount ?? this.unreadCount,
      rideId: rideId,
      messagesLoaded: messagesLoaded ?? this.messagesLoaded,
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
