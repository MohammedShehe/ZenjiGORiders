import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Shared visual identity layer used behind every screen.
/// Keeps the existing product flows intact while giving the whole app a
/// consistent Zanzibar coastal atmosphere.
class BeachAtmosphere extends StatelessWidget {
  final Widget child;
  final bool showImage;
  final double imageOpacity;

  const BeachAtmosphere({
    super.key,
    required this.child,
    this.showImage = true,
    this.imageOpacity = 0.16,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color(0xFF06283A),
                      Color(0xFF0B3448),
                      Color(0xFF123A3E),
                    ]
                  : const [
                      Color(0xFFFDF7E9),
                      Color(0xFFEAF9F6),
                      Color(0xFFDDF5F4),
                    ],
            ),
          ),
        ),
        if (showImage)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: imageOpacity,
                child: Image.asset(
                  'assets/images/zanzibar_beach_hero.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? [Colors.black.withOpacity(0.16), Colors.transparent, Colors.black.withOpacity(0.12)]
                      : [Colors.white.withOpacity(0.28), Colors.transparent, Colors.white.withOpacity(0.12)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -70,
          child: IgnorePointer(
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark ? AppColors.aquaGreen.withOpacity(0.10) : AppColors.oceanTeal.withOpacity(0.10),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -110,
          left: -80,
          child: IgnorePointer(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sand.withOpacity(dark ? 0.08 : 0.20),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class BeachSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const BeachSectionTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: dark ? AppColors.offWhite : AppColors.deepNavy,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 13,
              color: dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
