import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/ride_model.dart';
import '../core/constants/app_constants.dart';

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

  // Current location (mock or real)
  double _currentLat = -6.1659;
  double _currentLng = 39.2026;
  String _currentAddress = 'Current Location';
  bool _locationGranted = false;

  double get currentLat => _currentLat;
  double get currentLng => _currentLng;
  String get currentAddress => _currentAddress;
  bool get locationGranted => _locationGranted;

  final _uuid = const Uuid();

  AppProvider() {
    _loadPrefs();
    _initDemoData();
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
    if (_isAuthenticated && _user == null) {
      _user = UserModel(
        id: 'u1',
        fullName: 'Guest Rider',
        phone: '+255700000000',
        island: 'Unguja',
        region: 'Zanzibar Urban/West (Mjini Magharibi)',
        district: 'West (Magharibi)',
        ward: 'Mwanakwerekwe',
        walletBalance: 15000,
        savedLocations: [
          SavedLocationModel(
            id: 'home',
            label: 'Home',
            address: 'Mwanakwerekwe, West',
            island: 'Unguja',
            region: 'Zanzibar Urban/West (Mjini Magharibi)',
            district: 'West (Magharibi)',
            ward: 'Mwanakwerekwe',
            lat: -6.1659,
            lng: 39.2026,
          ),
          SavedLocationModel(
            id: 'work',
            label: 'Work',
            address: 'Stone Town, Mjini',
            island: 'Unguja',
            region: 'Zanzibar Urban/West (Mjini Magharibi)',
            district: 'Urban (Mjini)',
            ward: 'Shangani',
            lat: -6.1650,
            lng: 39.1910,
          ),
        ],
        paymentMethods: [
          PaymentMethodModel(id: 'cash1', type: 'cash', isDefault: true),
          PaymentMethodModel(
            id: 'wallet1',
            type: 'wallet',
            provider: 'ZenjiGO',
            isDefault: false,
          ),
        ],
      );
    }
    notifyListeners();
  }

  void _initDemoData() {
    _conversations = [
      ChatConversation(
        id: 'support',
        title: 'ZenjiGO Support',
        isSupport: true,
        isPinned: true,
        messages: [
          ChatMessage(
            id: '1',
            senderId: 'support',
            text: 'Karibu ZenjiGO! How can we help you today?',
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ],
      ),
    ];

    _rideHistory = [
      RideModel(
        id: 'r1',
        rideType: 'boda',
        fromAddress: 'Stone Town, Mjini',
        toAddress: 'Nungwi Beach',
        fromLat: -6.1650,
        fromLng: 39.1910,
        toLat: -5.7260,
        toLng: 39.2930,
        estimatedFare: 8500,
        finalFare: 8500,
        etaMinutes: 45,
        status: 'completed',
        paymentMethod: 'cash',
        rating: 5,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        completedAt: DateTime.now().subtract(const Duration(days: 2)),
        driver: DriverModel(
          id: 'd1',
          name: 'Juma Ali',
          phone: '+255712345678',
          vehicleNumber: 'T 123 ABC',
          vehicleType: 'Boda',
          rating: 4.9,
        ),
      ),
      RideModel(
        id: 'r2',
        rideType: 'taxi',
        fromAddress: 'Airport (ZNZ)',
        toAddress: 'Paje Beach',
        fromLat: -6.2220,
        fromLng: 39.2250,
        toLat: -6.2650,
        toLng: 39.5350,
        estimatedFare: 25000,
        finalFare: 25000,
        etaMinutes: 55,
        status: 'completed',
        paymentMethod: 'momo',
        rating: 4,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        completedAt: DateTime.now().subtract(const Duration(days: 5)),
        driver: DriverModel(
          id: 'd2',
          name: 'Fatma Said',
          phone: '+255754321098',
          vehicleNumber: 'T 456 DEF',
          vehicleType: 'Taxi',
          rating: 4.7,
        ),
      ),
    ];

    _transactions = [
      TransactionModel(
        id: 't1',
        type: 'topup',
        title: 'Wallet Top-up (M-Pesa)',
        amount: 20000,
        paymentMethod: 'momo',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      TransactionModel(
        id: 't2',
        type: 'ride',
        title: 'Ride: Stone Town → Nungwi',
        amount: -8500,
        paymentMethod: 'cash',
        reference: 'r1',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
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
    notifyListeners();
  }

  Future<void> logout() async {
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

  RideModel createRide({
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
  }) {
    final pin = (1000 + DateTime.now().millisecond % 9000).toString();
    final ride = RideModel(
      id: _uuid.v4(),
      rideType: rideType,
      fromAddress: fromAddress,
      toAddress: toAddress,
      fromLat: fromLat ?? _currentLat,
      fromLng: fromLng ?? _currentLng,
      toLat: toLat ?? _currentLat,
      toLng: toLng ?? _currentLng,
      estimatedFare: estimatedFare,
      etaMinutes: etaMinutes,
      status: 'searching',
      paymentMethod: paymentMethod ?? 'cash',
      promoCode: promoCode ?? _pendingPromoCode,
      discount: discount ?? _pendingDiscount,
      tripPin: pin,
    );
    _activeRide = ride;
    _pendingPromoCode = null;
    _pendingDiscount = 0;
    notifyListeners();
    return ride;
  }

  void cancelActiveRide({String? reason}) {
    if (_activeRide == null) return;
    final cancelled = _activeRide!.copyWith(
      status: 'cancelled',
      cancelReason: reason,
      completedAt: DateTime.now(),
    );
    _rideHistory.insert(0, cancelled);
    _activeRide = null;
    notifyListeners();
  }

  void completeActiveRide({
    double? finalFare,
    int? rating,
    String? feedback,
    double? tip,
  }) {
    if (_activeRide == null) return;
    final fare = finalFare ?? _activeRide!.estimatedFare;
    final discount = _activeRide!.discount ?? 0;
    final tipAmount = tip ?? 0;
    final total = (fare - discount + tipAmount).clamp(0, double.infinity);

    final completed = _activeRide!.copyWith(
      status: 'completed',
      finalFare: fare,
      completedAt: DateTime.now(),
      rating: rating,
      feedback: feedback,
      tip: tip,
    );
    _rideHistory.insert(0, completed);

    // Charge wallet if payment is wallet
    if (completed.paymentMethod == 'wallet' && _user != null) {
      final newBal = (_user!.walletBalance - total).clamp(0, double.infinity);
      _user = _user!.copyWith(walletBalance: newBal.toDouble());
    }

    _transactions.insert(
      0,
      TransactionModel(
        id: _uuid.v4(),
        type: 'ride',
        title: 'Ride: ${completed.fromAddress} → ${completed.toAddress}',
        amount: -total.toDouble(),
        paymentMethod: completed.paymentMethod,
        reference: completed.id,
      ),
    );

    if (tipAmount > 0) {
      _transactions.insert(
        0,
        TransactionModel(
          id: _uuid.v4(),
          type: 'tip',
          title: 'Tip to ${completed.driver?.name ?? 'Driver'}',
          amount: -tipAmount,
          paymentMethod: completed.paymentMethod,
          reference: completed.id,
        ),
      );
    }

    _activeRide = null;
    notifyListeners();
  }

  void addToHistory(RideModel ride) {
    _rideHistory.insert(0, ride);
    notifyListeners();
  }

  // ─── Promo ─────────────────────────────────────────────────────
  void applyPromo(String code, double discount) {
    _pendingPromoCode = code;
    _pendingDiscount = discount;
    notifyListeners();
  }

  void clearPromo() {
    _pendingPromoCode = null;
    _pendingDiscount = 0;
    notifyListeners();
  }

  // ─── Payment methods ───────────────────────────────────────────
  void addPaymentMethod(PaymentMethodModel method) {
    if (_user == null) return;
    final methods = List<PaymentMethodModel>.from(_user!.paymentMethods);
    final shouldDefault = method.isDefault || methods.isEmpty;
    final normalized = PaymentMethodModel(
      id: method.id,
      type: method.type,
      provider: method.provider,
      accountNumber: method.accountNumber,
      cardLast4: method.cardLast4,
      expiry: method.expiry,
      isDefault: shouldDefault,
    );
    if (shouldDefault) {
      for (var i = 0; i < methods.length; i++) {
        final old = methods[i];
        methods[i] = PaymentMethodModel(
          id: old.id,
          type: old.type,
          provider: old.provider,
          accountNumber: old.accountNumber,
          cardLast4: old.cardLast4,
          expiry: old.expiry,
          isDefault: false,
        );
      }
    }
    methods.add(normalized);
    _user = _user!.copyWith(paymentMethods: methods);
    notifyListeners();
  }

  void removePaymentMethod(String id) {
    if (_user == null) return;
    final methods = _user!.paymentMethods.where((m) => m.id != id).toList();
    if (methods.isNotEmpty && !methods.any((m) => m.isDefault)) {
      final first = methods.first;
      methods[0] = PaymentMethodModel(
        id: first.id,
        type: first.type,
        provider: first.provider,
        accountNumber: first.accountNumber,
        cardLast4: first.cardLast4,
        expiry: first.expiry,
        isDefault: true,
      );
    }
    _user = _user!.copyWith(paymentMethods: methods);
    notifyListeners();
  }

  void setDefaultPaymentMethod(String id) {
    if (_user == null) return;
    final methods = _user!.paymentMethods.map((m) {
      return PaymentMethodModel(
        id: m.id,
        type: m.type,
        provider: m.provider,
        accountNumber: m.accountNumber,
        cardLast4: m.cardLast4,
        expiry: m.expiry,
        isDefault: m.id == id,
      );
    }).toList();
    _user = _user!.copyWith(paymentMethods: methods);
    notifyListeners();
  }

  PaymentMethodModel? get defaultPaymentMethod {
    if (_user == null || _user!.paymentMethods.isEmpty) return null;
    return _user!.paymentMethods.firstWhere(
      (m) => m.isDefault,
      orElse: () => _user!.paymentMethods.first,
    );
  }

  // ─── Saved locations ───────────────────────────────────────────
  void addSavedLocation(SavedLocationModel location) {
    if (_user == null) return;
    final locations = List<SavedLocationModel>.from(_user!.savedLocations)
      ..add(location);
    _user = _user!.copyWith(savedLocations: locations);
    notifyListeners();
  }

  void removeSavedLocation(String id) {
    if (_user == null) return;
    _user = _user!.copyWith(
      savedLocations: _user!.savedLocations.where((l) => l.id != id).toList(),
    );
    notifyListeners();
  }

  // ─── Chat ──────────────────────────────────────────────────────
  void deleteConversation(String id) {
    _conversations.removeWhere((c) => c.id == id);
    notifyListeners();
  }

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

  ChatConversation ensureDriverChat(DriverModel driver) {
    final existing = _conversations.where((c) => c.id == driver.id).toList();
    if (existing.isNotEmpty) return existing.first;
    final conv = ChatConversation(
      id: driver.id,
      title: driver.name,
      messages: [
        ChatMessage(
          id: _uuid.v4(),
          senderId: 'driver',
          text: 'Habari! I am ${driver.name}, your driver. See you soon!',
        ),
      ],
    );
    _conversations.insert(0, conv);
    notifyListeners();
    return conv;
  }

  // ─── Wallet / Transactions ─────────────────────────────────────
  void addTransaction(TransactionModel tx) {
    _transactions.insert(0, tx);
    notifyListeners();
  }

  bool topUpWallet({
    required double amount,
    required String paymentMethod,
    String? provider,
  }) {
    if (_user == null || amount <= 0) return false;
    _user = _user!.copyWith(walletBalance: _user!.walletBalance + amount);
    _transactions.insert(
      0,
      TransactionModel(
        id: _uuid.v4(),
        type: 'topup',
        title: 'Wallet Top-up${provider != null ? ' ($provider)' : ''}',
        amount: amount,
        paymentMethod: paymentMethod,
      ),
    );
    notifyListeners();
    return true;
  }

  bool hasSufficientWallet(double amount) {
    return walletBalance >= amount;
  }

  String t(String en, String sw) => isSwahili ? sw : en;
}
