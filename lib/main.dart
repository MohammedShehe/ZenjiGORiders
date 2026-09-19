import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'features/splash/splash_screen.dart';
import 'features/payments/payment_methods_screen.dart';
import 'features/wallet/transaction_history_screen.dart';
import 'features/wallet/referral_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ZenjiGOApp());
}

class ZenjiGOApp extends StatelessWidget {
  const ZenjiGOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: Consumer<AppProvider>(
        builder: (context, app, _) {
          return MaterialApp(
            title: 'ZenjiGO Rider',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: app.themeMode,
            locale: app.locale,
            home: const SplashScreen(),
            routes: {
              '/payments': (_) => const PaymentMethodsScreen(),
              '/wallet/transactions': (_) => const TransactionHistoryScreen(),
              '/wallet/referrals': (_) => const ReferralScreen(),
            },
          );
        },
      ),
    );
  }
}
