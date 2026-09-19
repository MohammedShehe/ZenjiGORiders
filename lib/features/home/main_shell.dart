import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_provider.dart';
import 'home_screen.dart';
import '../wallet/wallet_screen.dart';
import '../chat/chat_list_screen.dart';
import '../profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = const [
    HomeScreen(),
    WalletScreen(),
    ChatListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined, app.t('Home', 'Nyumbani'), isDark),
                _navItem(1, Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, app.t('Wallet', 'Pochi'), isDark),
                _navItem(2, Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, app.t('Chat', 'Mazungumzo'), isDark),
                _navItem(3, Icons.person_rounded, Icons.person_outline_rounded, app.t('Profile', 'Wasifu'), isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData active, IconData inactive, String label, bool isDark) {
    final selected = _currentIndex == index;
    final color = selected
        ? (isDark ? AppColors.aquaGreen : AppColors.oceanTeal)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? active : inactive, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
