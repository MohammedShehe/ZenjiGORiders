import 'api_client.dart';

class RiderApi {
  /* -------------------- Auth -------------------- */
  static Future<void> sendOtp(
    String phone, {
    required String email,
  }) async {
    // The website only needs the request to succeed; its response fields
    // (target/maskedEmail) are optional and must not be force-cast.
    await ApiClient.data('POST', '/auth/rider/send-otp', body: {
      'phone': phone.toString().trim(),
      'email': email.trim().toLowerCase(),
    }, auth: false);
  }

  static Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String code, {
    required String email,
    String? fullName,
    String? island,
    String? region,
  }) async {
    final d = await ApiClient.data('POST', '/auth/rider/verify-otp', body: {
      'phone': phone,
      'email': email.trim().toLowerCase(),
      'code': code.toString().trim(),
      if (fullName != null && fullName.isNotEmpty) 'fullName': fullName.trim(),
      if (island != null && island.trim().isNotEmpty) 'island': island.trim(),
      if (region != null && region.trim().isNotEmpty) 'region': region.trim(),
    }, auth: false);
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  /* -------------------- Profile -------------------- */
  static Future<Map<String, dynamic>> me() async {
    final d = await ApiClient.data('GET', '/rider/me');
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<Map<String, dynamic>> updateMe(Map<String, dynamic> body) async {
    final d = await ApiClient.data('PATCH', '/rider/me', body: body);
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  /* -------------------- Saved locations -------------------- */
  static Future<List<dynamic>> savedLocations() async {
    final d = await ApiClient.data('GET', '/rider/saved-locations');
    return List<dynamic>.from(d is List ? d : (d is Map && d['savedLocations'] is List ? d['savedLocations'] : (d is Map && d['items'] is List ? d['items'] : [])));
  }

  static Future<Map<String, dynamic>> createSavedLocation(Map<String, dynamic> body) async {
    final d = await ApiClient.data('POST', '/rider/saved-locations', body: body);
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<void> deleteSavedLocation(String id) async {
    await ApiClient.data('DELETE', '/rider/saved-locations/$id');
  }

  /* -------------------- Payment methods -------------------- */
  static Future<List<dynamic>> paymentMethods() async {
    final d = await ApiClient.data('GET', '/rider/payment-methods');
    return List<dynamic>.from(d is List ? d : (d is Map && d['paymentMethods'] is List ? d['paymentMethods'] : (d is Map && d['items'] is List ? d['items'] : [])));
  }

  static Future<Map<String, dynamic>> addPaymentMethod(Map<String, dynamic> body) async {
    final d = await ApiClient.data('POST', '/rider/payment-methods', body: body);
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<void> setDefaultPaymentMethod(String id) async {
    await ApiClient.data('PATCH', '/rider/payment-methods/$id/default');
  }

  static Future<void> deletePaymentMethod(String id) async {
    await ApiClient.data('DELETE', '/rider/payment-methods/$id');
  }

  /* -------------------- Rides -------------------- */
  static Future<Map<String, dynamic>> quote({
    required String rideType,
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final d = await ApiClient.data('POST', '/rider/rides/quote', body: {
      'rideType': rideType,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
    });
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<Map<String, dynamic>> createRide(Map<String, dynamic> body) async {
    final d = await ApiClient.data('POST', '/rider/rides', body: body);
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<Map<String, dynamic>> getRide(String id) async {
    final d = await ApiClient.data('GET', '/rider/rides/$id');
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<Map<String, dynamic>> track(String id) async {
    final d = await ApiClient.data('GET', '/rider/rides/$id/track');
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<List<dynamic>> nearbyDrivers(double lat, double lng, {double radiusKm = 5}) async {
    final d = await ApiClient.data('GET', '/rider/drivers/nearby?lat=$lat&lng=$lng&radius=$radiusKm');
    return List<dynamic>.from(d is List ? d : (d is Map && d['drivers'] is List ? d['drivers'] : []));
  }

  static Future<void> cancelRide(String id, String reason) async {
    await ApiClient.data('POST', '/rider/rides/$id/cancel', body: {'reason': reason});
  }

  static Future<Map<String, dynamic>?> cancelPreview(String id) async {
    try {
      final d = await ApiClient.data('GET', '/rider/rides/$id/cancel-preview');
      return Map<String, dynamic>.from(d is Map ? d : {});
    } catch (_) {
      return null;
    }
  }

  static Future<void> rate(
    String id,
    int stars, {
    String? feedback,
    double? tip,
  }) async {
    await ApiClient.data('POST', '/rider/rides/$id/rating', body: {
      'stars': stars,
      if (feedback != null) 'feedback': feedback,
      if (tip != null) 'tip': tip,
    });
  }

  static Future<List<dynamic>> history() async {
    final d = await ApiClient.data('GET', '/rider/rides');
    return List<dynamic>.from(d is List ? d : (d is Map && d['rides'] is List ? d['rides'] : (d is Map && d['items'] is List ? d['items'] : [])));
  }

  /* -------------------- Wallet -------------------- */
  static Future<Map<String, dynamic>> walletBalance() async {
    final d = await ApiClient.data('GET', '/rider/wallet');
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<List<dynamic>> walletTransactions() async {
    final d = await ApiClient.data('GET', '/rider/wallet/transactions');
    return List<dynamic>.from(d is List ? d : (d is Map && d['transactions'] is List ? d['transactions'] : (d is Map && d['items'] is List ? d['items'] : [])));
  }

  static Future<Map<String, dynamic>> topUp({
    required double amount,
    required String paymentMethod,
    String? phone,
  }) async {
    final d = await ApiClient.data('POST', '/rider/wallet/topup', body: {
      'amount': amount,
      'paymentMethod': paymentMethod,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'provider': 'paygrid',
    });
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<Map<String, dynamic>> topUpStatus(String id) async {
    final d = await ApiClient.data('GET', '/rider/wallet/topup/$id');
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  /* -------------------- Promos -------------------- */
  static Future<List<dynamic>> promos() async {
    final d = await ApiClient.data('GET', '/promos');
    return List<dynamic>.from(d is List ? d : (d is Map && d['promos'] is List ? d['promos'] : (d is Map && d['items'] is List ? d['items'] : [])));
  }

  static Future<Map<String, dynamic>> applyPromo(String code, {String? rideId}) async {
    final d = await ApiClient.data('POST', '/promos/apply', body: {
      'code': code,
      if (rideId != null) 'rideId': rideId,
    });
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  /* -------------------- Parcels & Tours -------------------- */
  static Future<List<dynamic>> parcels() async {
    final d = await ApiClient.data('GET', '/rider/parcels');
    return List<dynamic>.from(d is List ? d : (d is Map && d['parcels'] is List ? d['parcels'] : (d is Map && d['items'] is List ? d['items'] : [])));
  }

  static Future<Map<String, dynamic>> createParcel(Map<String, dynamic> body) async {
    final d = await ApiClient.data('POST', '/rider/parcels', body: body);
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<List<dynamic>> tourPackages() async {
    final d = await ApiClient.data('GET', '/rider/tour-packages');
    return List<dynamic>.from(d is List ? d : (d is Map && d['packages'] is List ? d['packages'] : (d is Map && d['items'] is List ? d['items'] : [])));
  }

  static Future<List<dynamic>> tours() async {
    final d = await ApiClient.data('GET', '/rider/tours');
    return List<dynamic>.from(d is List ? d : (d is Map && d['tours'] is List ? d['tours'] : (d is Map && d['items'] is List ? d['items'] : [])));
  }

  static Future<Map<String, dynamic>> bookTour(Map<String, dynamic> body) async {
    final d = await ApiClient.data('POST', '/rider/tours', body: body);
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  /* -------------------- Chat -------------------- */
  static Future<List<dynamic>> conversations() async {
    final d = await ApiClient.data('GET', '/rider/chat');
    return List<dynamic>.from(d is List ? d : (d is Map && d['conversations'] is List ? d['conversations'] : (d is Map && d['items'] is List ? d['items'] : [])));
  }

  static Future<Map<String, dynamic>> openSupport() async {
    final d = await ApiClient.data('POST', '/rider/chat/support');
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<List<dynamic>> messages(String conversationId) async {
    final d = await ApiClient.data('GET', '/rider/chat/$conversationId/messages');
    return List<dynamic>.from(d is List ? d : (d is Map && d['messages'] is List ? d['messages'] : (d is Map && d['items'] is List ? d['items'] : [])));
  }

  static Future<Map<String, dynamic>> sendMessage(String conversationId, String text) async {
    final d = await ApiClient.data('POST', '/rider/chat/$conversationId/messages', body: {
      'text': text,
    });
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<void> markRead(String conversationId) async {
    await ApiClient.data('POST', '/rider/chat/$conversationId/read');
  }

  /* -------------------- Notifications -------------------- */
  static Future<void> registerFcmToken(String token, {String platform = 'android'}) async {
    await ApiClient.data('POST', '/rider/notifications/token', body: {
      'token': token,
      'platform': platform,
    });
  }

  static Future<List<dynamic>> notifications() async {
    final d = await ApiClient.data('GET', '/rider/notifications');
    return List<dynamic>.from(d is List ? d : (d is Map && d['notifications'] is List ? d['notifications'] : (d is Map && d['items'] is List ? d['items'] : [])));
  }

  static Future<void> markNotificationRead(String id) async {
    await ApiClient.data('PATCH', '/rider/notifications/$id/read');
  }

  /* -------------------- Reports & App info -------------------- */
  static Future<Map<String, dynamic>> reportDriver({
    required String driverId,
    required String reason,
    String? rideId,
    String? details,
  }) async {
    final d = await ApiClient.data('POST', '/rider/reports', body: {
      'driverId': driverId,
      'reason': reason,
      if (rideId != null) 'rideId': rideId,
      if (details != null) 'details': details,
    });
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<Map<String, dynamic>> appVersion() async {
    final d = await ApiClient.data('GET', '/rider/app-version');
    return Map<String, dynamic>.from(d is Map ? d : {});
  }

  static Future<void> sendEmailChangeOtp(String email) async {
    await ApiClient.data('POST', '/rider/email-change/send-otp', body: {'email': email.trim().toLowerCase()});
  }

  static Future<Map<String, dynamic>> verifyEmailChangeOtp(String email, String code) async {
    final d = await ApiClient.data('POST', '/rider/email-change/verify-otp', body: {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
    });
    return Map<String, dynamic>.from(d is Map ? d : {});
  }
}
