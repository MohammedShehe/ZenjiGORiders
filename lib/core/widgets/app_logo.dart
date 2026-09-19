import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class AppLogo extends StatelessWidget {
  final double height;
  final bool animated;

  const AppLogo({super.key, this.height = 80, this.animated = false});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final logo = isDark
        ? 'assets/logos/logo_dark.png'
        : 'assets/logos/logo_light.png';

    Widget image = Image.asset(
      logo,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.local_taxi_rounded,
        size: height * 0.8,
        color: Theme.of(context).colorScheme.primary,
      ),
    );

    if (animated) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          );
        },
        child: image,
      );
    }
    return image;
  }
}
