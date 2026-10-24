import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'route_utils.dart';

/// Position + heading of a moving vehicle.
@immutable
class MovingFrame {
  final gmaps.LatLng position;
  final double heading;
  const MovingFrame(this.position, this.heading);
}

/// Glides a vehicle marker from its last known position to each new GPS fix
/// (instead of teleporting every few seconds). Runs at ~15 fps which looks smooth
/// on the map while staying cheap on low-end phones, and idles when nothing moves.
class MovingPoint {
  MovingPoint({gmaps.LatLng? start, double heading = 0})
      : frame = ValueNotifier<MovingFrame?>(start == null ? null : MovingFrame(start, heading));

  final ValueNotifier<MovingFrame?> frame;
  Timer? _timer;

  gmaps.LatLng? get position => frame.value?.position;

  /// Smoothly move to [target] (callers pass a road-snapped point when they have one).
  void moveTo(gmaps.LatLng target, {Duration duration = const Duration(milliseconds: 1800)}) {
    final current = frame.value;
    if (current == null) {
      frame.value = MovingFrame(target, 0);
      return;
    }
    final from = current.position;
    final dist = GeoUtils.distanceMeters(from, target);
    if (dist < 1.5) return;
    _timer?.cancel();

    // Large jumps (re-connect, first fix) shouldn't be animated across the map.
    if (dist > 800) {
      frame.value = MovingFrame(target, GeoUtils.bearing(from, target));
      return;
    }

    final targetHeading = dist >= 4 ? GeoUtils.bearing(from, target) : current.heading;
    final startHeading = current.heading;
    const tick = Duration(milliseconds: 66);
    final total = (duration.inMilliseconds / tick.inMilliseconds).round().clamp(2, 60);
    var step = 0;
    _timer = Timer.periodic(tick, (t) {
      step++;
      final p = step / total;
      final eased = p >= 1 ? 1.0 : 1 - (1 - p) * (1 - p); // ease-out quad
      frame.value = MovingFrame(
        GeoUtils.lerp(from, target, eased),
        GeoUtils.lerpAngle(startHeading, targetHeading, (eased * 1.6).clamp(0.0, 1.0)),
      );
      if (step >= total) t.cancel();
    });
  }

  void dispose() {
    _timer?.cancel();
    frame.dispose();
  }
}
