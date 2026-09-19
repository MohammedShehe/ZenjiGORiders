import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  List<ChatConversation> get conversations => _conversations;

  // Ride history
  List<RideModel> _rideHistory = [];
  List<RideModel> get rideHistory => _rideHistory;

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
    if (_isAuthenticated && _user == null) {
      _user = UserModel(
        id: 'u1', fullName: 'Guest Rider', phone: '+255700000000', island: 'Unguja',
        region: 'Zanzibar Urban/West (Mjini Magharibi)', district: 'West (Magharibi)', ward: 'Mwanakwerekwe', walletBalance: 5000,
        savedLocations: [SavedLocationModel(id: 'home', label: 'Home', address: 'Mwanakwerekwe, West', island: 'Unguja', region: 'Zanzibar Urban/West (Mjini Magharibi)', district: 'West (Magharibi)', ward: 'Mwanakwerekwe')],
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

    // Demo ride history
    _rideHistory = [
      RideModel(
        id: 'r1',
        rideType: 'boda',
        fromAddress: 'Stone Town, Mjini',
        toAddress: 'Nungwi Beach',
        estimatedFare: 8500,
        etaMinutes: 45,
        status: 'completed',
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
        estimatedFare: 25000,
        etaMinutes: 55,
        status: 'completed',
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

  void setActiveRide(RideModel? ride) {
    _activeRide = ride;
    notifyListeners();
  }

  void addToHistory(RideModel ride) { _rideHistory.insert(0, ride); notifyListeners(); }

  void addPaymentMethod(PaymentMethodModel method) {
    if (_user == null) return;
    final methods = List<PaymentMethodModel>.from(_user!.paymentMethods);
    methods.add(method);
    _user = _user!.copyWith(paymentMethods: methods);
    notifyListeners();
  }

  void removePaymentMethod(String id) {
    if (_user == null) return;
    _user = _user!.copyWith(paymentMethods: _user!.paymentMethods.where((m) => m.id != id).toList());
    notifyListeners();
  }

  void addSavedLocation(SavedLocationModel location) {
    if (_user == null) return;
    final locations = List<SavedLocationModel>.from(_user!.savedLocations)..add(location);
    _user = _user!.copyWith(savedLocations: locations);
    notifyListeners();
  }

  void removeSavedLocation(String id) {
    if (_user == null) return;
    _user = _user!.copyWith(savedLocations: _user!.savedLocations.where((l) => l.id != id).toList());
    notifyListeners();
  }

  String t(String en, String sw) => isSwahili ? sw : en;
}
