import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Shared background layer used behind every screen.
/// Clean, calm and professional: a soft cool gradient with a faint brand glow at the top.
/// (The old beach photo and decorative circles were removed: they made content harder to read.)
class BeachAtmosphere extends StatelessWidget {
  final Widget child;
  // Kept so existing call sites keep compiling; the photo layer is no longer drawn.
  final bool showImage;
  final double imageOpacity;

  const BeachAtmosphere({
    super.key,
    required this.child,
    this.showImage = false,
    this.imageOpacity = 0,
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
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [Color(0xFF0A2533), Color(0xFF071E2B), Color(0xFF061923)]
                  : const [Color(0xFFF4F8FA), Color(0xFFF8FAFB), Color(0xFFFFFFFF)],
            ),
          ),
        ),
        Positioned(
          top: -140,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.9,
                  colors: [
                    (dark ? AppColors.aquaGreen : AppColors.brightGreen).withValues(alpha: dark ? 0.16 : 0.10),
                    Colors.transparent,
                  ],
                ),
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
          style: GoogleFonts.poppins(
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
