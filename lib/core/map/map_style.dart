import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../theme/app_colors.dart';

/// Clean, low-noise Google Maps styles (light + dark) so routes, pins and vehicles stand out.
/// Note: styles are ignored when a cloud-based Map ID is configured for the map.
class MapStyles {
  static const String light = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f2f5f5"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#5b6f74"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"},{"weight":3}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.neighborhood","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"#d7eede"}]},
  {"featureType":"poi.park","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#e1e7e9"}]},
  {"featureType":"road.local","elementType":"labels","stylers":[{"visibility":"simplified"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#fbe9c8"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#f0d9ad"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#bde5ee"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#6fa3b0"}]}
]''';

  static const String dark = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0d2a37"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8fb1b6"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0a2430"},{"weight":3}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.neighborhood","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"#12392f"}]},
  {"featureType":"poi.park","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1c4252"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#143342"}]},
  {"featureType":"road.local","elementType":"labels","stylers":[{"visibility":"simplified"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#235063"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6074"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1c4252"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#06202c"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4f7f8a"}]}
]''';

  static String forBrightness(bool isDark) => isDark ? dark : light;
}

/// Shared visual constants + polyline builders for map screens.
class MapUi {
  static Color panelColor(bool isDark) => isDark ? const Color(0xFF123846) : Colors.white;
  static Color panelSubtle(bool isDark) => isDark ? const Color(0xFF1B4B5B) : const Color(0xFFF1F6F6);
  static Color accent(bool isDark) => isDark ? AppColors.aquaGreen : AppColors.oceanTeal;
  static Color textSecondary(bool isDark) => isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  static Color routeCore(bool isDark) => isDark ? AppColors.aquaGreen : AppColors.oceanTeal;
  static Color routeCasing(bool isDark) => isDark ? const Color(0xFF06202C) : Colors.white;

  /// Professional two-layer route: a wide casing under a slimmer coloured core with round caps/joins.
  static Set<gmaps.Polyline> routeLine({
    required String id,
    required List<gmaps.LatLng> points,
    required bool isDark,
    int zIndex = 2,
    double width = 6,
  }) {
    if (points.length < 2) return const {};
    return {
      gmaps.Polyline(
        polylineId: gmaps.PolylineId('$id-casing'),
        points: points,
        color: routeCasing(isDark).withValues(alpha: isDark ? 0.9 : 0.95),
        width: (width + 4).round(),
        startCap: gmaps.Cap.roundCap,
        endCap: gmaps.Cap.roundCap,
        jointType: gmaps.JointType.round,
        zIndex: zIndex,
      ),
      gmaps.Polyline(
        polylineId: gmaps.PolylineId('$id-core'),
        points: points,
        color: routeCore(isDark),
        width: width.round(),
        startCap: gmaps.Cap.roundCap,
        endCap: gmaps.Cap.roundCap,
        jointType: gmaps.JointType.round,
        zIndex: zIndex + 1,
      ),
    };
  }

  /// Part of the route the vehicle has already driven: slim, faded, under the live route.
  static Set<gmaps.Polyline> travelledLine({
    required String id,
    required List<gmaps.LatLng> points,
    required bool isDark,
  }) {
    if (points.length < 2) return const {};
    return {
      gmaps.Polyline(
        polylineId: gmaps.PolylineId('$id-travelled'),
        points: points,
        color: (isDark ? Colors.white : AppColors.deepNavy).withValues(alpha: 0.28),
        width: 5,
        startCap: gmaps.Cap.roundCap,
        endCap: gmaps.Cap.roundCap,
        jointType: gmaps.JointType.round,
        zIndex: 2,
      ),
    };
  }

  /// Subtle dashed line for the part of a trip that is not the active leg.
  static Set<gmaps.Polyline> secondaryLine({
    required String id,
    required List<gmaps.LatLng> points,
    required bool isDark,
  }) {
    if (points.length < 2) return const {};
    return {
      gmaps.Polyline(
        polylineId: gmaps.PolylineId('$id-secondary'),
        points: points,
        color: (isDark ? Colors.white : AppColors.deepNavy).withValues(alpha: 0.45),
        width: 4,
        patterns: [gmaps.PatternItem.dash(14), gmaps.PatternItem.gap(10)],
        startCap: gmaps.Cap.roundCap,
        endCap: gmaps.Cap.roundCap,
        jointType: gmaps.JointType.round,
        zIndex: 1,
      ),
    };
  }
}
