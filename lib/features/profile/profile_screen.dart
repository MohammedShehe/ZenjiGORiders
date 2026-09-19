import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../auth/login_screen.dart';
import '../payments/payment_methods_screen.dart';
import 'edit_profile_screen.dart';
import 'ride_history_screen.dart';
import 'saved_locations_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDark;
    final user = app.user;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.darkBg, AppColors.darkCard]
                        : [AppColors.deepNavy, AppColors.oceanTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white24,
                        child: Text(
                          user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(user?.fullName ?? 'Guest', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                      Text(user?.phone ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _section(app.t('Account', 'Akaunti'), [
                    _tile(Icons.person_outline, app.t('Edit Profile', 'Hariri Wasifu'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())), isDark),
                    _tile(Icons.history, app.t('Ride History', 'Historia ya Safari'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideHistoryScreen())), isDark),
                    _tile(Icons.location_on_outlined, app.t('Saved Locations', 'Mahali Uliyohifadhi'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedLocationsScreen())), isDark),
                    _tile(Icons.payment, app.t('Payment Methods', 'Njia za Malipo'), () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()));
                    }, isDark),
                  ], isDark),
                  _section(app.t('Support', 'Msaada'), [
                    _tile(Icons.support_agent, app.t('Contact Support', 'Wasiliana na Msaada'), () => _showSupport(context, app, isDark), isDark),
                    _tile(Icons.description_outlined, app.t('Terms & Privacy', 'Sheria & Faragha'), () async {
                      await launchUrl(Uri.parse(AppConstants.termsUrl), mode: LaunchMode.externalApplication);
                    }, isDark),
                  ], isDark),
                  _section(app.t('Settings', 'Mipangilio'), [
                    _tile(Icons.language, app.t('Language', 'Lugha'), () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (_) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              title: const Text('English'),
                              trailing: !app.isSwahili ? const Icon(Icons.check) : null,
                              onTap: () {
                                app.setLocale(const Locale('en'));
                                Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              title: const Text('Kiswahili'),
                              trailing: app.isSwahili ? const Icon(Icons.check) : null,
                              onTap: () {
                                app.setLocale(const Locale('sw'));
                                Navigator.pop(context);
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    }, isDark),
                    SwitchListTile(
                      secondary: Icon(Icons.notifications_outlined, color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal),
                      title: Text(app.t('Notifications', 'Arifa')),
                      value: app.notificationsEnabled,
                      onChanged: (v) => app.setNotifications(v),
                      activeColor: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
                    ),
                    SwitchListTile(
                      secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal),
                      title: Text(app.t('Dark Mode', 'Hali ya Giza')),
                      value: isDark,
                      onChanged: (v) => app.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
                      activeColor: isDark ? AppColors.aquaGreen : AppColors.oceanTeal,
                    ),
                  ], isDark),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.error),
                    title: Text(app.t('Logout', 'Toka'), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(app.t('Logout?', 'Toka?')),
                          content: Text(app.t('Are you sure you want to logout?', 'Una uhakika unataka kutoka?')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(app.t('Cancel', 'Ghairi'))),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(app.t('Logout', 'Toka'), style: const TextStyle(color: AppColors.error))),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await app.logout();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (_) => false,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('ZenjiGO v1.0.0', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 12)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap, bool isDark) {
    return ListTile(
      leading: Icon(icon, color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  void _showSupport(BuildContext context, AppProvider app, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(app.t('Contact ZenjiGO', 'Wasiliana na ZenjiGO'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.brightGreen),
              title: Text(AppConstants.orgPhone),
              onTap: () => launchUrl(Uri.parse('tel:${AppConstants.orgPhone.replaceAll(' ', '')}')),
            ),
            ListTile(
              leading: const Icon(Icons.email, color: AppColors.skyBlue),
              title: Text(AppConstants.orgEmail),
              onTap: () => launchUrl(Uri.parse('mailto:${AppConstants.orgEmail}')),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.purple),
              title: Text('@${AppConstants.orgInstagram}'),
              onTap: () => launchUrl(Uri.parse('https://instagram.com/${AppConstants.orgInstagram}')),
            ),
            ListTile(
              leading: Icon(Icons.chat, color: isDark ? AppColors.aquaGreen : AppColors.oceanTeal),
              title: Text(app.t('In-App Chat', 'Mazungumzo Ndani ya Programu')),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
