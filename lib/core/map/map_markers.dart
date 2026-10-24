import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../theme/app_colors.dart';

/// Crisp custom map markers drawn once with the canvas (no asset files needed) and cached.
class MapMarkerSet {
  final gmaps.BitmapDescriptor pickup;
  final gmaps.BitmapDescriptor destination;
  final gmaps.BitmapDescriptor driverArrow;
  final Map<String, gmaps.BitmapDescriptor> nearby;

  const MapMarkerSet({
    required this.pickup,
    required this.destination,
    required this.driverArrow,
    required this.nearby,
  });

  gmaps.BitmapDescriptor nearbyFor(String? rideType) => nearby[rideType] ?? nearby['taxi']!;
}

class MapMarkers {
  static final Map<String, Future<MapMarkerSet>> _cache = {};

  /// [ratio] is the device pixel ratio so icons stay sharp on every density.
  static Future<MapMarkerSet> load(double ratio) {
    final r = ratio.clamp(1.0, 3.5).toDouble();
    return _cache.putIfAbsent(r.toStringAsFixed(2), () => _build(r));
  }

  static Future<MapMarkerSet> _build(double ratio) async {
    final pickup = await _render(46, 46, ratio, _paintPickup);
    final dest = await _render(46, 60, ratio, _paintDestination);
    final arrow = await _render(64, 64, ratio, _paintDriverArrow);
    final nearby = <String, gmaps.BitmapDescriptor>{
      'boda': await _render(34, 34, ratio, (c, s) => _paintNearby(c, s, Icons.two_wheeler_rounded)),
      'bajaji': await _render(34, 34, ratio, (c, s) => _paintNearby(c, s, Icons.electric_rickshaw_rounded)),
      'taxi': await _render(34, 34, ratio, (c, s) => _paintNearby(c, s, Icons.local_taxi_rounded)),
    };
    return MapMarkerSet(pickup: pickup, destination: dest, driverArrow: arrow, nearby: nearby);
  }

  static Future<gmaps.BitmapDescriptor> _render(
    double w,
    double h,
    double ratio,
    void Function(Canvas canvas, Size size) paint,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(ratio);
    paint(canvas, Size(w, h));
    final picture = recorder.endRecording();
    final image = await picture.toImage((w * ratio).ceil(), (h * ratio).ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return gmaps.BitmapDescriptor.bytes(data!.buffer.asUint8List(), imagePixelRatio: ratio);
  }

  static void _shadow(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center.translate(0, 2),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );
  }

  static void _paintPickup(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    // soft halo
    canvas.drawCircle(c, 20, Paint()..color = AppColors.oceanTeal.withValues(alpha: 0.16));
    _shadow(canvas, c, 11);
    canvas.drawCircle(c, 11, Paint()..color = Colors.white);
    canvas.drawCircle(c, 6.5, Paint()..color = AppColors.oceanTeal);
  }

  static void _paintDestination(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const r = 15.0;
    final cy = r + 6;
    final tip = Offset(cx, size.height - 3);
    // ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, size.height - 3), width: 16, height: 6),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(cx - 5, cy + r + 4, cx - r, cy + 8, cx - r, cy)
      ..arcToPoint(Offset(cx + r, cy), radius: const Radius.circular(r), clockwise: true)
      ..cubicTo(cx + r, cy + 8, cx + 5, cy + r + 4, tip.dx, tip.dy)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, true);
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, cy - r),
          Offset(cx, tip.dy),
          [const Color(0xFFFFB074), AppColors.coral],
        ),
    );
    canvas.drawCircle(Offset(cx, cy), 6, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx, cy), 2.6, Paint()..color = AppColors.coral);
  }

  static void _paintDriverArrow(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, 30, Paint()..color = AppColors.oceanTeal.withValues(alpha: 0.14));
    _shadow(canvas, c, 20);
    canvas.drawCircle(c, 20, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      17,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx, c.dy - 17),
          Offset(c.dx, c.dy + 17),
          [AppColors.lagoon, AppColors.deepNavy],
        ),
    );
    // navigation chevron pointing "up" (rotated by the Marker.rotation)
    final arrow = Path()
      ..moveTo(c.dx, c.dy - 10)
      ..lineTo(c.dx + 8, c.dy + 8)
      ..lineTo(c.dx, c.dy + 3.5)
      ..lineTo(c.dx - 8, c.dy + 8)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white);
  }

  static void _paintNearby(Canvas canvas, Size size, IconData icon) {
    final c = Offset(size.width / 2, size.height / 2);
    _shadow(canvas, c, 13);
    canvas.drawCircle(c, 14, Paint()..color = Colors.white);
    canvas.drawCircle(c, 11.5, Paint()..color = AppColors.deepNavy);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 15,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }
}

/// Convenience: a pulsing "searching" ring around the pickup drawn with native map circles.
class PulseCircles {
  static Set<gmaps.Circle> build(gmaps.LatLng center, double phase, bool isDark) {
    // phase 0..1 → two staggered rings expanding and fading.
    Set<gmaps.Circle> ring(String id, double p) {
      final eased = Curves.easeOut.transform(p);
      return {
        gmaps.Circle(
          circleId: gmaps.CircleId(id),
          center: center,
          radius: 40 + 260 * eased,
          fillColor: AppColors.oceanTeal.withValues(alpha: 0.20 * (1 - eased)),
          strokeColor: AppColors.oceanTeal.withValues(alpha: 0.55 * (1 - eased)),
          strokeWidth: 2,
          zIndex: 0,
        ),
      };
    }

    return {...ring('pulse-a', phase), ...ring('pulse-b', (phase + 0.5) % 1.0)};
  }

  static double nextPhase(double phase, {double step = 0.045}) => (phase + step) % 1.0;
}
