import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/ride_model.dart';
import '../core/api/api_client.dart';
import '../core/api/rider_api.dart';

class AppProvider extends ChangeNotifier {
  // Theme & Language
  ThemeMode _themeMode = ThemeMode.dark;
  Locale _locale = const Locale('en');
  bool _notificationsEnabled = true;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isSwahili => _locale.languageCode == 'sw';
  bool get notificationsEnabled => _notificationsEnabled;

  // Auth
  bool _isAuthenticated = false;
  bool _onboardingComplete = false;
  UserModel? _user;
  RideModel? _activeRide;

  bool get isAuthenticated => _isAuthenticated;
  bool get onboardingComplete => _onboardingComplete;
  UserModel? get user => _user;
  RideModel? get activeRide => _activeRide;

  // Wallet
  double get walletBalance => _user?.walletBalance ?? 0;

  // Chats
  List<ChatConversation> _conversations = [];
  List<ChatConversation> get conversations => List.unmodifiable(_conversations);

  // Ride history
  List<RideModel> _rideHistory = [];
  List<RideModel> get rideHistory => List.unmodifiable(_rideHistory);

  // Transactions
  List<TransactionModel> _transactions = [];
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);

  // Applied promo for current booking (cleared after booking)
  String? _pendingPromoCode;
  double _pendingDiscount = 0;
  String? get pendingPromoCode => _pendingPromoCode;
  double get pendingDiscount => _pendingDiscount;

  // Location is unknown until the device returns a real GPS fix.
  double _currentLat = 0;
  double _currentLng = 0;
  String _currentAddress = '';
  bool _locationGranted = false;

  double get currentLat => _currentLat;
  double get currentLng => _currentLng;
  String get currentAddress => _currentAddress;
  bool get locationGranted => _locationGranted;


  AppProvider() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('themeMode') ?? 'dark';
    _themeMode = theme == 'light' ? ThemeMode.light : ThemeMode.dark;
    final lang = prefs.getString('locale') ?? 'en';
    _locale = Locale(lang);
    _onboardingComplete = prefs.getBool('onboardingComplete') ?? false;
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    _notificationsEnabled = prefs.getBool('notifications') ?? true;
    _locationGranted = prefs.getBool('locationGranted') ?? false;
    if (_isAuthenticated) {
      try {
        final r = await ApiClient.request('GET', '/rider/me');
        final data = Map<String,dynamic>.from(r['data'] ?? {});
        _user = UserModel.fromJson(data);
        // Load account-owned records from the same endpoints used by the web app.
        await refreshAccountCollections();
        await refreshRideHistory();
        await refreshWallet();
      } catch (_) {
        _isAuthenticated = false;
        await prefs.setBool('isAuthenticated', false);
        await ApiClient.clearTokens();
      }
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);
    notifyListeners();
  }

  Future<void> setNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', enabled);
    try {
      await ApiClient.request('PATCH', '/rider/me', body: {
        'notificationsEnabled': enabled,
        'pushEnabled': enabled,
      });
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setLocationGranted(bool granted) async {
    _locationGranted = granted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('locationGranted', granted);
    notifyListeners();
  }

  void setCurrentLocation({
    required double lat,
    required double lng,
    String? address,
  }) {
    _currentLat = lat;
    _currentLng = lng;
    if (address != null) _currentAddress = address;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    notifyListeners();
  }

  Future<void> login(UserModel user) async {
    _user = user;
    _isAuthenticated = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAuthenticated', true);
    try {
      _user = UserModel.fromJson(await RiderApi.me());
    } catch (_) {
      // Retain the user payload returned by OTP verification if /rider/me is temporarily unavailable.
    }
    await refreshAccountCollections();
    await refreshRideHistory();
    await refreshWallet();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      // Match the web client's authenticated POST /auth/logout contract.
      await ApiClient.request('POST', '/auth/logout');
    } catch (_) {}
    await ApiClient.clearTokens();
    _user = null;
    _isAuthenticated = false;
    _activeRide = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAuthenticated', false);
    notifyListeners();
  }

  void updateUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  void updateWallet(double amount) {
    if (_user != null) {
      _user = _user!.copyWith(walletBalance: amount);
      notifyListeners();
    }
  }

  // ─── Active ride ───────────────────────────────────────────────
  void setActiveRide(RideModel? ride) {
    _activeRide = ride;
    notifyListeners();
  }

  void updateActiveRide(RideModel ride) {
    _activeRide = ride;
    notifyListeners();
  }

  Future<RideModel> createRide({
    required String rideType,
    required String fromAddress,
    required String toAddress,
    required double estimatedFare,
    required int etaMinutes,
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
    String? paymentMethod,
    String? promoCode,
    double? discount,
  }) async {
    final fLat = fromLat ?? _currentLat;
    final fLng = fromLng ?? _currentLng;
    final tLat = toLat;
    final tLng = toLng;
    if (fLat == 0 || fLng == 0 || tLat == null || tLng == null || tLat == 0 || tLng == 0) {
      throw Exception('Choose a real pickup and destination from the map before booking.');
    }
    final pay = paymentMethod ?? 'cash';
    final promo = promoCode ?? _pendingPromoCode;

    Map<String, dynamic> remote = {};
    try {
      // Live quote then create
      final q = await RiderApi.quote(
        rideType: rideType,
        pickupLat: fLat,
        pickupLng: fLng,
        destinationLat: tLat,
        destinationLng: tLng,
      );
      final body = {
        'rideType': rideType,
        'pickupAddress': fromAddress,
        'destinationAddress': toAddress,
        'pickupLat': fLat,
        'pickupLng': fLng,
        'destinationLat': tLat,
        'destinationLng': tLng,
        'paymentMethod': pay,
        if (promo != null) 'promoCode': promo,
      };
      remote = await RiderApi.createRide(body);
      // Prefer server fare if present
      final quotedFare = q['fare'] ?? q['estimatedFare'] ?? q['total'] ?? q['amount'];
      if (quotedFare != null) {
        estimatedFare = double.tryParse(quotedFare.toString()) ?? estimatedFare;
      }
      final quotedDuration = q['durationMin'] ?? q['estimatedDurationMin'];
      if (quotedDuration != null) {
        etaMinutes = int.tryParse(quotedDuration.toString()) ?? etaMinutes;
      }
    } catch (e) {
      // Surface to caller
      rethrow;
    }

    final remoteRide = remote['ride'] is Map
        ? Map<String, dynamic>.from(remote['ride'] as Map)
        : remote;
    final rawId = remoteRide['id'] ?? remoteRide['rideId'] ?? remoteRide['ride_code'];
    if (rawId == null || rawId.toString().trim().isEmpty) {
      throw Exception('The booking API did not return a ride ID. No local ride was created.');
    }
    final id = rawId.toString();
    final rawPin = remoteRide['trip_pin'] ?? remoteRide['tripPin'];
    final pin = rawPin?.toString();
    final ride = RideModel(
      id: id,
      rideType: rideType,
      fromAddress: fromAddress,
      toAddress: toAddress,
      fromLat: fLat,
      fromLng: fLng,
      toLat: tLat,
      toLng: tLng,
      estimatedFare: double.tryParse((remoteRide['fare'] ?? remoteRide['estimated_fare'] ?? remoteRide['estimatedFare'] ?? remoteRide['totalFare'] ?? estimatedFare).toString()) ?? estimatedFare,
      etaMinutes: int.tryParse((remoteRide['durationMin'] ?? remoteRide['estimated_duration_min'] ?? remoteRide['estimatedDurationMin'] ?? etaMinutes).toString()) ?? etaMinutes,
      status: (remoteRide['status'] ?? 'requested').toString(),
      paymentMethod: pay,
      promoCode: promo,
      discount: discount ?? _pendingDiscount,
      tripPin: pin,
    );
    _activeRide = ride;
    _pendingPromoCode = null;
    _pendingDiscount = 0;
    notifyListeners();
    return ride;
  }

  Future<void> refreshAccountCollections() async {
    if (_user == null) return;
    try {
      final results = await Future.wait([
        RiderApi.paymentMethods(),
        RiderApi.savedLocations(),
      ]);
      final methods = results[0]
          .whereType<Map>()
          .map((e) => PaymentMethodModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final locations = results[1]
          .whereType<Map>()
          .map((e) => SavedLocationModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _user = _user!.copyWith(paymentMethods: methods, savedLocations: locations);
      notifyListeners();
    } catch (_) {
      // Preserve the account screen if an optional collection endpoint is unavailable.
    }
  }

  Future<void> refreshRideHistory() async {
    try {
      final list = await RiderApi.history();
      _rideHistory = list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return RideModel(
          id: (m['id'] ?? m['ride_code'] ?? '').toString(),
          rideType: (m['ride_type'] ?? m['rideType'] ?? 'boda').toString(),
          fromAddress: (m['pickup_address'] ?? m['fromAddress'] ?? '').toString(),
          toAddress: (m['destination_address'] ?? m['toAddress'] ?? '').toString(),
          fromLat: double.tryParse((m['pickup_lat'] ?? 0).toString()) ?? 0,
          fromLng: double.tryParse((m['pickup_lng'] ?? 0).toString()) ?? 0,
          toLat: double.tryParse((m['destination_lat'] ?? 0).toString()) ?? 0,
          toLng: double.tryParse((m['destination_lng'] ?? 0).toString()) ?? 0,
          estimatedFare: double.tryParse((m['estimated_fare'] ?? m['final_fare'] ?? 0).toString()) ?? 0,
          finalFare: double.tryParse((m['final_fare'] ?? 0).toString()),
          etaMinutes: int.tryParse((m['estimated_duration_min'] ?? m['estimatedDurationMin'] ?? 0).toString()) ?? 0,
          status: (m['status'] ?? 'unknown').toString(),
          paymentMethod: (m['payment_method'] ?? 'cash').toString(),
          createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) : null,
        );
      }).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshWallet() async {
    try {
      final w = await RiderApi.walletBalance();
      final bal = double.tryParse((w['balance'] ?? w['walletBalance'] ?? walletBalance).toString());
      if (bal != null) updateWallet(bal);
      final txs = await RiderApi.walletTransactions();
      _transactions = txs.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return TransactionModel(
          id: (m['id'] ?? '').toString(),
          type: (m['type'] ?? 'unknown').toString(),
          title: (m['description'] ?? m['type'] ?? 'Transaction').toString(),
          amount: double.tryParse((m['amount'] ?? 0).toString()) ?? 0,
          paymentMethod: (m['payment_method'] ?? '').toString(),
        );
      }).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> cancelActiveRide({String? reason}) async {
    if (_activeRide == null) return;
    await RiderApi.cancelRide(_activeRide!.id, reason ?? 'Cancelled by rider');
    _activeRide = null;
    await refreshRideHistory();
    notifyListeners();
  }

  Future<void> completeActiveRide({
    double? finalFare,
    int? rating,
    String? feedback,
    double? tip,
  }) async {
    // The backend owns the completed ride, fare, wallet, and transaction ledger.
    // Refresh authoritative records rather than synthesizing local completion data.
    _activeRide = null;
    await refreshRideHistory();
    await refreshWallet();
    notifyListeners();
  }

  // ─── Promo ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> promos() async {
    final data = await RiderApi.promos();
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> applyPromo(String code, [double discount = 0]) async {
    try {
      final r = await RiderApi.applyPromo(code);
      _pendingPromoCode = (r['code'] ?? code).toString();
      _pendingDiscount = double.tryParse((r['discount'] ?? discount).toString()) ?? discount;
    } catch (_) {
      _pendingPromoCode = null;
      _pendingDiscount = 0;
      rethrow;
    }
    notifyListeners();
  }

  void clearPromo() {
    _pendingPromoCode = null;
    _pendingDiscount = 0;
    notifyListeners();
  }

  // ─── Payment methods ───────────────────────────────────────────
  Future<void> addPaymentMethod(PaymentMethodModel method) async {
    final body = <String, dynamic>{
      'type': method.type == 'bank' ? 'card' : method.type,
      'label': method.cardHolder ?? method.provider ?? method.type,
      if (method.provider != null) 'provider': method.provider,
      if (method.accountNumber != null) 'account': method.accountNumber,
      if (method.accountNumber != null) 'accountNumber': method.accountNumber,
      if (method.cardLast4 != null) 'last4': method.cardLast4,
      if (method.cardLast4 != null) 'cardLast4': method.cardLast4,
      if (method.expiry != null) 'expiry': method.expiry,
      if (method.cardHolder != null) 'cardHolder': method.cardHolder,
      if (method.cardBrand != null) 'cardBrand': method.cardBrand,
      'isDefault': method.isDefault,
    };
    final result = await RiderApi.addPaymentMethod(body);
    await refreshAccountCollections();
    if (method.isDefault) {
      final id = (result['id'] ?? result['_id'] ?? '').toString();
      if (id.isNotEmpty) {
        try {
          await RiderApi.setDefaultPaymentMethod(id);
          await refreshAccountCollections();
        } catch (_) {}
      }
    }
  }

  Future<void> removePaymentMethod(String id) async {
    await RiderApi.deletePaymentMethod(id);
    await refreshAccountCollections();
  }

  Future<void> setDefaultPaymentMethod(String id) async {
    await RiderApi.setDefaultPaymentMethod(id);
    await refreshAccountCollections();
  }

  PaymentMethodModel? get defaultPaymentMethod {
    if (_user == null || _user!.paymentMethods.isEmpty) return null;
    return _user!.paymentMethods.firstWhere(
      (m) => m.isDefault,
      orElse: () => _user!.paymentMethods.first,
    );
  }

  // ─── Saved locations ───────────────────────────────────────────
  Future<void> addSavedLocation(SavedLocationModel location) async {
    if (location.lat == null || location.lng == null) {
      throw Exception('Select a real map location with latitude and longitude before saving.');
    }
    await RiderApi.createSavedLocation({
      'label': location.label,
      'address': location.address,
      'lat': location.lat,
      'lng': location.lng,
    });
    await refreshAccountCollections();
  }

  Future<void> removeSavedLocation(String id) async {
    await RiderApi.deleteSavedLocation(id);
    await refreshAccountCollections();
  }

  Future<void> refreshConversations() async {
    try {
      final rows = await RiderApi.conversations();
      _conversations = rows.whereType<Map>().map((row) {
        final m = Map<String, dynamic>.from(row);
        final id = (m['id'] ?? m['_id'] ?? m['conversationId'] ?? '').toString();
        final last = m['lastMessage'] is Map ? Map<String, dynamic>.from(m['lastMessage']) : <String, dynamic>{};
        final lastText = (last['text'] ?? m['lastMessageText'] ?? '').toString();
        final messages = lastText.isEmpty ? <ChatMessage>[] : <ChatMessage>[
          ChatMessage(
            id: (last['id'] ?? last['_id'] ?? '').toString(),
            senderId: (last['senderId'] ?? last['sender'] ?? '').toString(),
            text: lastText,
            timestamp: DateTime.tryParse((last['createdAt'] ?? last['created_at'] ?? '').toString()) ?? DateTime.now(),
          ),
        ];
        return ChatConversation(
          id: id,
          title: (m['title'] ?? m['name'] ?? m['driverName'] ?? 'Conversation').toString(),
          isSupport: m['isSupport'] == true || m['type'] == 'support',
          isPinned: m['isPinned'] == true,
          messages: messages,
          lastMessageAt: DateTime.tryParse((m['lastMessageAt'] ?? m['updatedAt'] ?? m['updated_at'] ?? '').toString()) ?? DateTime.now(),
        );
      }).where((c) => c.id.isNotEmpty).toList();
      notifyListeners();
    } catch (_) {
      // Keep existing conversations visible on transient API errors.
    }
  }

  Future<void> refreshConversationMessages(String conversationId) async {
    try {
      final rows = await RiderApi.messages(conversationId);
      final messages = rows.whereType<Map>().map((row) {
        final m = Map<String, dynamic>.from(row);
        return ChatMessage(
          id: (m['id'] ?? m['_id'] ?? '').toString(),
          senderId: (m['senderId'] ?? m['sender'] ?? '').toString(),
          text: (m['text'] ?? m['message'] ?? '').toString(),
          timestamp: DateTime.tryParse((m['createdAt'] ?? m['created_at'] ?? '').toString()) ?? DateTime.now(),
          isEdited: m['isEdited'] == true,
          isDeleted: m['isDeleted'] == true,
        );
      }).toList();
      final idx = _conversations.indexWhere((c) => c.id == conversationId);
      if (idx >= 0) {
        final current = _conversations[idx];
        _conversations[idx] = current.copyWith(messages: messages);
        notifyListeners();
      }
      await RiderApi.markRead(conversationId);
    } catch (_) {}
  }

  Future<void> sendChatMessage(String conversationId, String text) async {
    await RiderApi.sendMessage(conversationId, text);
    await refreshConversationMessages(conversationId);
    await refreshConversations();
  }

  // ─── Chat ──────────────────────────────────────────────────────
  void addOrUpdateConversation(ChatConversation conversation) {
    final idx = _conversations.indexWhere((c) => c.id == conversation.id);
    if (idx >= 0) {
      _conversations[idx] = conversation;
    } else {
      _conversations.insert(0, conversation);
    }
    notifyListeners();
  }

  void addMessage(String conversationId, ChatMessage message) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx < 0) return;
    final conv = _conversations[idx];
    final msgs = List<ChatMessage>.from(conv.messages)..add(message);
    _conversations[idx] = conv.copyWith(
      messages: msgs,
      lastMessageAt: message.timestamp,
    );
    notifyListeners();
  }

  // ─── Wallet / Transactions ─────────────────────────────────────
  Future<bool> topUpWalletLive({
    required double amount,
    required String paymentMethod,
    String? phone,
  }) async {
    try {
      final apiMethod = paymentMethod == 'bank' ? 'card' : paymentMethod;
      final d = await RiderApi.topUp(amount: amount, paymentMethod: apiMethod, phone: phone);
      final bal = double.tryParse((d['balance'] ?? d['walletBalance'] ?? '').toString());
      if (bal != null) updateWallet(bal);
      final paymentId = (d['paymentId'] ?? d['id'] ?? (d['data'] is Map ? d['data']['paymentId'] : null) ?? '').toString();
      if (paymentId.isNotEmpty) unawaited(_pollTopUpStatus(paymentId));
      await refreshWallet();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pollTopUpStatus(String paymentId) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      try {
        final statusData = await RiderApi.topUpStatus(paymentId);
        final status = (statusData['status'] ?? '').toString().toLowerCase();
        if (status == 'success' || status == 'completed' || status == 'paid') {
          await refreshWallet();
          return;
        }
        if (status == 'failed' || status == 'cancelled') return;
      } catch (_) {
        // Keep polling while the payment provider settles asynchronously.
      }
    }
  }

  bool hasSufficientWallet(double amount) {
    return walletBalance >= amount;
  }

  String t(String en, String sw) => isSwahili ? sw : en;
}
