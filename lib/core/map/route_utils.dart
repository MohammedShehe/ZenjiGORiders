import 'dart:async';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

/// Small, allocation-friendly geo helpers shared by the map screens.
class GeoUtils {
  static const double _earthRadius = 6371000.0;

  static double _rad(double deg) => deg * math.pi / 180.0;
  static double _deg(double rad) => rad * 180.0 / math.pi;

  /// Great-circle distance in metres.
  static double distanceMeters(gmaps.LatLng a, gmaps.LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthRadius * math.asin(math.min(1.0, math.sqrt(h.toDouble())));
  }

  /// Initial bearing from [a] to [b] in degrees (0..360, 0 = north).
  static double bearing(gmaps.LatLng a, gmaps.LatLng b) {
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (_deg(math.atan2(y, x)) + 360.0) % 360.0;
  }

  static gmaps.LatLng lerp(gmaps.LatLng a, gmaps.LatLng b, double t) =>
      gmaps.LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);

  /// Shortest-arc interpolation between two compass angles.
  static double lerpAngle(double from, double to, double t) {
    var diff = ((to - from + 540.0) % 360.0) - 180.0;
    return (from + diff * t + 360.0) % 360.0;
  }

  static gmaps.LatLngBounds? boundsOf(Iterable<gmaps.LatLng> pts) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in pts) {
      minLat = minLat == null ? p.latitude : math.min(minLat, p.latitude);
      maxLat = maxLat == null ? p.latitude : math.max(maxLat, p.latitude);
      minLng = minLng == null ? p.longitude : math.min(minLng, p.longitude);
      maxLng = maxLng == null ? p.longitude : math.max(maxLng, p.longitude);
    }
    if (minLat == null || maxLat == null || minLng == null || maxLng == null) return null;
    // Avoid a zero-area box (identical points) which makes the camera zoom to max.
    if ((maxLat - minLat).abs() < 0.0004) {
      minLat -= 0.0004;
      maxLat += 0.0004;
    }
    if ((maxLng - minLng).abs() < 0.0004) {
      minLng -= 0.0004;
      maxLng += 0.0004;
    }
    return gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat, minLng),
      northeast: gmaps.LatLng(maxLat, maxLng),
    );
  }

  /// Douglas-Peucker simplification, tolerance in degrees (~1e-5 ≈ 1.1 m).
  /// Keeps long routes light for the map plugin without visibly changing the shape.
  static List<gmaps.LatLng> simplify(List<gmaps.LatLng> pts, {double tolerance = 0.000012, int maxPoints = 1200}) {
    if (pts.length <= maxPoints) return pts;
    final keep = List<bool>.filled(pts.length, false);
    keep[0] = true;
    keep[pts.length - 1] = true;
    final stack = <List<int>>[
      [0, pts.length - 1]
    ];
    while (stack.isNotEmpty) {
      final range = stack.removeLast();
      final start = range[0];
      final end = range[1];
      double maxDist = 0;
      int index = -1;
      for (var i = start + 1; i < end; i++) {
        final d = _perpendicular(pts[i], pts[start], pts[end]);
        if (d > maxDist) {
          maxDist = d;
          index = i;
        }
      }
      if (index != -1 && maxDist > tolerance) {
        keep[index] = true;
        stack.add([start, index]);
        stack.add([index, end]);
      }
    }
    final out = <gmaps.LatLng>[];
    for (var i = 0; i < pts.length; i++) {
      if (keep[i]) out.add(pts[i]);
    }
    return out;
  }

  static double _perpendicular(gmaps.LatLng p, gmaps.LatLng a, gmaps.LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    if (dx == 0 && dy == 0) {
      return math.sqrt(math.pow(p.longitude - a.longitude, 2) + math.pow(p.latitude - a.latitude, 2));
    }
    final t = ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) / (dx * dx + dy * dy);
    final tc = t.clamp(0.0, 1.0).toDouble();
    final cx = a.longitude + tc * dx;
    final cy = a.latitude + tc * dy;
    return math.sqrt(math.pow(p.longitude - cx, 2) + math.pow(p.latitude - cy, 2));
  }
}

class RouteSnap {
  final int segment;
  final gmaps.LatLng point;
  final double distanceAlong; // metres from the start of the route
  final double offset; // metres between the query point and the snapped point
  const RouteSnap(this.segment, this.point, this.distanceAlong, this.offset);
}

/// Pre-computes cumulative distances so a vehicle can be snapped to / moved along a road polyline.
class RouteTracker {
  final List<gmaps.LatLng> points;
  final List<double> _cum;

  RouteTracker(this.points) : _cum = List<double>.filled(points.length, 0) {
    for (var i = 1; i < points.length; i++) {
      _cum[i] = _cum[i - 1] + GeoUtils.distanceMeters(points[i - 1], points[i]);
    }
  }

  bool get isUsable => points.length >= 2;
  double get totalMeters => _cum.isEmpty ? 0 : _cum.last;

  RouteSnap? snap(gmaps.LatLng p) {
    if (!isUsable) return null;
    // Local equirectangular projection — accurate enough at city scale and very cheap.
    final cosLat = math.cos(p.latitude * math.pi / 180.0);
    const mPerDeg = 111320.0;
    double bestOffset = double.infinity;
    int bestSeg = 0;
    double bestT = 0;
    for (var i = 0; i < points.length - 1; i++) {
      final ax = (points[i].longitude - p.longitude) * cosLat * mPerDeg;
      final ay = (points[i].latitude - p.latitude) * mPerDeg;
      final bx = (points[i + 1].longitude - p.longitude) * cosLat * mPerDeg;
      final by = (points[i + 1].latitude - p.latitude) * mPerDeg;
      final dx = bx - ax;
      final dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2);
      t = t.clamp(0.0, 1.0).toDouble();
      final cx = ax + dx * t;
      final cy = ay + dy * t;
      final d = math.sqrt(cx * cx + cy * cy);
      if (d < bestOffset) {
        bestOffset = d;
        bestSeg = i;
        bestT = t;
      }
    }
    final segLen = _cum[bestSeg + 1] - _cum[bestSeg];
    final along = _cum[bestSeg] + segLen * bestT;
    return RouteSnap(bestSeg, GeoUtils.lerp(points[bestSeg], points[bestSeg + 1], bestT), along, bestOffset);
  }

  int _segmentAt(double d) {
    var lo = 0;
    var hi = points.length - 2;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_cum[mid] <= d) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  gmaps.LatLng pointAt(double d) {
    if (!isUsable) return points.isEmpty ? const gmaps.LatLng(0, 0) : points.first;
    final dist = d.clamp(0.0, totalMeters).toDouble();
    final seg = _segmentAt(dist);
    final segLen = _cum[seg + 1] - _cum[seg];
    final t = segLen <= 0 ? 0.0 : (dist - _cum[seg]) / segLen;
    return GeoUtils.lerp(points[seg], points[seg + 1], t);
  }

  double bearingAt(double d) {
    if (!isUsable) return 0;
    final dist = d.clamp(0.0, totalMeters).toDouble();
    final seg = _segmentAt(dist);
    // Look slightly ahead so the heading is stable around vertices.
    final a = pointAt(dist);
    var seg2 = seg;
    while (seg2 < points.length - 2 && GeoUtils.distanceMeters(a, points[seg2 + 1]) < 4) {
      seg2++;
    }
    return GeoUtils.bearing(a, points[seg2 + 1]);
  }

  /// Remaining part of the route starting at [d] metres from the start.
  List<gmaps.LatLng> sliceFrom(double d) {
    if (!isUsable) return points;
    final dist = d.clamp(0.0, totalMeters).toDouble();
    final seg = _segmentAt(dist);
    return <gmaps.LatLng>[pointAt(dist), ...points.sublist(seg + 1)];
  }
}

/// Progressive "draw-in" animation for a polyline. Uses few discrete steps so the
/// map plugin is not flooded with updates (keeps low-end devices smooth).
class RouteReveal {
  Timer? _timer;

  void start(
    List<gmaps.LatLng> full,
    void Function(List<gmaps.LatLng> visible) onFrame, {
    Duration duration = const Duration(milliseconds: 650),
    int steps = 14,
  }) {
    cancel();
    if (full.length < 8) {
      onFrame(full);
      return;
    }
    var step = 0;
    final interval = Duration(milliseconds: (duration.inMilliseconds / steps).round());
    _timer = Timer.periodic(interval, (t) {
      step++;
      if (step >= steps) {
        t.cancel();
        onFrame(full);
        return;
      }
      final eased = 1 - math.pow(1 - step / steps, 3).toDouble(); // ease-out
      final n = math.max(2, (full.length * eased).round());
      onFrame(full.sublist(0, n));
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
