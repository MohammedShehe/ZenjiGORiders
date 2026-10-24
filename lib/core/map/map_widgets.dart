import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'map_style.dart';

/// Reports the rendered height of a floating panel so the map can pad itself around it
/// (keeps the route, Google logo and controls visible on every screen size).
class SizeReporter extends StatefulWidget {
  final Widget child;
  final ValueChanged<double> onHeight;
  const SizeReporter({super.key, required this.child, required this.onHeight});

  @override
  State<SizeReporter> createState() => _SizeReporterState();
}

class _SizeReporterState extends State<SizeReporter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) widget.onHeight(box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
        return true;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}

/// Round floating map button (back, re-centre …).
class MapCircleButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final String? tooltip;
  final VoidCallback onTap;
  const MapCircleButton({super.key, required this.icon, required this.isDark, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: MapUi.panelColor(isDark),
        elevation: 4,
        shadowColor: Colors.black38,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, size: 22, color: isDark ? Colors.white : AppColors.deepNavy),
          ),
        ),
      ),
    );
  }
}

/// Rounded floating info pill shown over the map.
class FloatingPill extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final EdgeInsetsGeometry padding;
  const FloatingPill({
    super.key,
    required this.child,
    required this.isDark,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: MapUi.panelColor(isDark),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: isDark ? Colors.white : AppColors.deepNavy),
        child: child,
      ),
    );
  }
}


/// "12 min · 4.3 km" summary shown over the map once a road route is known.
class RouteInfoChip extends StatelessWidget {
  final String duration;
  final String distance;
  final bool isDark;
  final bool approximate;
  const RouteInfoChip({
    super.key,
    required this.duration,
    required this.distance,
    required this.isDark,
    this.approximate = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = MapUi.accent(isDark);
    return FloatingPill(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(approximate ? Icons.near_me_disabled_rounded : Icons.route_rounded, size: 17, color: accent),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              approximate ? '~$distance' : '$duration · $distance',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
