import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/beach_atmosphere.dart';
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
            builder: (context, child) => _MinWidthGuard(
              child: BeachAtmosphere(child: child ?? const SizedBox.shrink()),
            ),
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

/// Keeps the layout at a sane minimum size. When the window (for example a
/// browser window dragged very small) is narrower than [minWidth] or shorter than
/// [minHeight], the app keeps that minimum layout and scrolls, instead of throwing
/// hundreds of RenderFlex overflows. Phones are never this small, and the
/// on-screen keyboard does not shrink these constraints, so they are unaffected.
class _MinWidthGuard extends StatelessWidget {
  final Widget child;
  const _MinWidthGuard({required this.child});

  static const double minWidth = 320;
  static const double minHeight = 480;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) return child;
      final needsX = constraints.maxWidth < minWidth;
      final needsY = constraints.maxHeight < minHeight;
      if (!needsX && !needsY) return child;

      final width = needsX ? minWidth : constraints.maxWidth;
      final height = needsY ? minHeight : constraints.maxHeight;

      Widget content = SizedBox(
        width: width,
        height: height,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(size: Size(width, height)),
          child: child,
        ),
      );
      if (needsY) {
        content = SingleChildScrollView(primary: false, child: content);
      }
      if (needsX) {
        content = SingleChildScrollView(primary: false, scrollDirection: Axis.horizontal, child: content);
      }
      return content;
    });
  }
}
