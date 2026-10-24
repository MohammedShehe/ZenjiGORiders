import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../map/route_utils.dart';

/// Where a [RouteResult] came from. Anything except [straight] follows real roads.
enum RouteSource { routesApi, osrm, straight }

/// A road route plus the trip metrics that come with it.
class RouteResult {
  final List<gmaps.LatLng> points;
  final double distanceMeters;
  final int durationSeconds;
  final RouteSource source;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.source,
  });

  bool get followsRoads => source != RouteSource.straight;
  double get distanceKm => distanceMeters / 1000.0;
  int get durationMinutes => (durationSeconds / 60.0).ceil();

  String get distanceLabel {
    if (distanceMeters <= 0) return '—';
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    final km = distanceMeters / 1000.0;
    return '${km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1)} km';
  }

  String get durationLabel {
    if (durationSeconds <= 0) return '—';
    final m = durationMinutes;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '$h h' : '$h h $r min';
  }
}

/// Road-following routes.
///
/// 1. Google **Routes API** (`routes.googleapis.com/directions/v2:computeRoutes`).
///    Keys that are restricted to an Android / iOS app are only accepted when the request
///    proves the app identity, so we send `X-Android-Package` + `X-Android-Cert`
///    (or `X-Ios-Bundle-Identifier`). Without those headers Google answers 403 and the
///    map used to silently fall back to a straight line.
/// 2. OSRM (OpenStreetMap roads) if Google is unreachable / rejects the key.
/// 3. A straight line, flagged as such via [RouteResult.followsRoads], only as a last resort.
class DirectionsService {
  DirectionsService._();

  static const String defaultKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyBX93zeEULXrhxlvkNefmoFcYDGizvvSpU',
  );

  static final Map<String, RouteResult> _cache = {};
  static final Map<String, Future<RouteResult>> _inFlight = {};
  static DateTime? _googleBackoffUntil;
  static Future<Map<String, String>>? _identityHeaders;

  static String _cacheKey(double a, double b, double c, double d) =>
      '${a.toStringAsFixed(4)},${b.toStringAsFixed(4)}->${c.toStringAsFixed(4)},${d.toStringAsFixed(4)}';

  /// Backwards compatible helper: just the polyline.
  static Future<List<gmaps.LatLng>> route({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? apiKey,
  }) async {
    final r = await fetch(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      apiKey: apiKey,
    );
    return r.points;
  }

  /// Full route with distance / duration. Results are cached and concurrent identical
  /// requests share one network call.
  static Future<RouteResult> fetch({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? apiKey,
  }) {
    final ck = _cacheKey(originLat, originLng, destLat, destLng);
    final hit = _cache[ck];
    if (hit != null) return Future.value(hit);
    return _inFlight.putIfAbsent(ck, () async {
      try {
        final result = await _resolve(originLat, originLng, destLat, destLng, apiKey);
        // Only keep real road routes; a straight line should be retried next time.
        if (result.followsRoads) {
          if (_cache.length > 40) _cache.remove(_cache.keys.first);
          _cache[ck] = result;
        }
        return result;
      } finally {
        _inFlight.remove(ck);
      }
    });
  }

  static Future<RouteResult> _resolve(
    double oLat,
    double oLng,
    double dLat,
    double dLng,
    String? apiKey,
  ) async {
    final key = (apiKey != null && apiKey.isNotEmpty) ? apiKey : defaultKey;

    final blocked = _googleBackoffUntil != null && DateTime.now().isBefore(_googleBackoffUntil!);
    if (key.isNotEmpty && !blocked) {
      final g = await _googleRoute(oLat, oLng, dLat, dLng, key);
      if (g != null) return g;
    }
    final o = await _osrmRoute(oLat, oLng, dLat, dLng);
    if (o != null) return o;

    final a = gmaps.LatLng(oLat, oLng);
    final b = gmaps.LatLng(dLat, dLng);
    final d = GeoUtils.distanceMeters(a, b);
    return RouteResult(
      points: [a, b],
      distanceMeters: d,
      durationSeconds: (d / 7.0).round(), // ~25 km/h urban average, only used for the straight fallback
      source: RouteSource.straight,
    );
  }

  // ---------------------------------------------------------------- Google Routes API

  static Future<Map<String, String>> _identity() =>
      _identityHeaders ??= Future.value(<String, String>{});

  static Future<RouteResult?> _googleRoute(
    double oLat,
    double oLng,
    double dLat,
    double dLng,
    String key,
  ) async {
    try {
      final body = jsonEncode({
        'origin': {
          'location': {'latLng': {'latitude': oLat, 'longitude': oLng}},
        },
        'destination': {
          'location': {'latLng': {'latitude': dLat, 'longitude': dLng}},
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_UNAWARE',
        'computeAlternativeRoutes': false,
        'polylineQuality': 'HIGH_QUALITY',
        'polylineEncoding': 'ENCODED_POLYLINE',
        'languageCode': 'en',
        'units': 'METRIC',
        'regionCode': 'TZ',
      });

      final res = await http
          .post(
            Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Goog-Api-Key': key,
              'X-Goog-FieldMask':
                  'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration',
              ...await _identity(),
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('DirectionsService: Routes API ${res.statusCode}: ${_short(res.body)}');
        if (res.statusCode == 401 || res.statusCode == 403) {
          // Key / restriction problem: don't hammer Google, use the fallback for a while.
          _googleBackoffUntil = DateTime.now().add(const Duration(minutes: 3));
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['error'] != null) return null;
      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty || routes.first is! Map) return null;
      final first = routes.first as Map;

      final poly = first['polyline'];
      final encoded = poly is Map ? (poly['encodedPolyline'] ?? poly['points'])?.toString() : null;
      if (encoded == null || encoded.isEmpty) return null;
      final points = decodePolyline(encoded);
      if (points.length < 2) return null;

      final dist = (first['distanceMeters'] as num?)?.toDouble() ?? _pathLength(points);
      final dur = _parseDuration(first['duration']) ?? (dist / 7.0).round();
      return RouteResult(
        points: GeoUtils.simplify(points),
        distanceMeters: dist,
        durationSeconds: dur,
        source: RouteSource.routesApi,
      );
    } catch (e) {
      debugPrint('DirectionsService: Routes API failed ($e)');
      return null;
    }
  }

  // ---------------------------------------------------------------- OSRM fallback

  static Future<RouteResult?> _osrmRoute(double oLat, double oLng, double dLat, double dLng) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$oLng,$oLat;$dLng,$dLat'
        '?overview=full&geometries=polyline&alternatives=false&steps=false',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['code'] != 'Ok') return null;
      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty || routes.first is! Map) return null;
      final first = routes.first as Map;
      final geometry = first['geometry']?.toString();
      if (geometry == null || geometry.isEmpty) return null;
      final points = decodePolyline(geometry);
      if (points.length < 2) return null;
      final dist = (first['distance'] as num?)?.toDouble() ?? _pathLength(points);
      final dur = (first['duration'] as num?)?.round() ?? (dist / 7.0).round();
      return RouteResult(
        points: GeoUtils.simplify(points),
        distanceMeters: dist,
        durationSeconds: dur,
        source: RouteSource.osrm,
      );
    } catch (e) {
      debugPrint('DirectionsService: OSRM failed ($e)');
      return null;
    }
  }

  // ---------------------------------------------------------------- helpers

  static String _short(String s) => s.length > 220 ? '${s.substring(0, 220)}…' : s;

  static int? _parseDuration(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    final m = RegExp(r'^(\d+(?:\.\d+)?)s$').firstMatch(s);
    if (m != null) return double.parse(m.group(1)!).round();
    return int.tryParse(s);
  }

  static double _pathLength(List<gmaps.LatLng> pts) {
    var d = 0.0;
    for (var i = 1; i < pts.length; i++) {
      d += GeoUtils.distanceMeters(pts[i - 1], pts[i]);
    }
    return d;
  }

  /// Google / OSRM polyline decoder (precision 5).
  static List<gmaps.LatLng> decodePolyline(String encoded) {
    final List<gmaps.LatLng> points = [];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      lat += ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      shift = 0;
      result = 0;
      if (index >= encoded.length) break;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      lng += ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      points.add(gmaps.LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
