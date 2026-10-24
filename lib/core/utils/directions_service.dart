import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

/// Road-following route via Google **Routes API**
/// POST https://routes.googleapis.com/directions/v2:computeRoutes
class DirectionsService {
  static const String _defaultKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyBX93zeEULXrhxlvkNefmoFcYDGizvvSpU',
  );

  static final Map<String, List<gmaps.LatLng>> _cache = {};

  static String _cacheKey(double a, double b, double c, double d) =>
      '${a.toStringAsFixed(5)},${b.toStringAsFixed(5)}->${c.toStringAsFixed(5)},${d.toStringAsFixed(5)}';

  static Future<List<gmaps.LatLng>> route({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? apiKey,
  }) async {
    final key = (apiKey != null && apiKey.isNotEmpty) ? apiKey : _defaultKey;
    final ck = _cacheKey(originLat, originLng, destLat, destLng);
    if (_cache.containsKey(ck)) return List<gmaps.LatLng>.from(_cache[ck]!);

    final straight = <gmaps.LatLng>[
      gmaps.LatLng(originLat, originLng),
      gmaps.LatLng(destLat, destLng),
    ];
    if (key.isEmpty) return straight;

    try {
      final uri = Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
      final body = jsonEncode({
        'origin': {
          'location': {'latLng': {'latitude': originLat, 'longitude': originLng}},
        },
        'destination': {
          'location': {'latLng': {'latitude': destLat, 'longitude': destLng}},
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_UNAWARE',
        'computeAlternativeRoutes': false,
        'languageCode': 'en',
        'units': 'METRIC',
        'regionCode': 'TZ',
      });

      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-Goog-Api-Key': key,
              'X-Goog-FieldMask':
                  'routes.polyline.encodedPolyline,routes.distanceMeters,routes.duration',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return straight;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return straight;
      if (decoded['error'] != null) return straight;

      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) return straight;
      final first = routes.first;
      if (first is! Map) return straight;

      String? encoded;
      final poly = first['polyline'];
      if (poly is Map) {
        encoded = poly['encodedPolyline']?.toString() ?? poly['points']?.toString();
      }

      if (encoded == null || encoded.isEmpty) return straight;
      final points = decodePolyline(encoded);
      if (points.length >= 2) {
        _cache[ck] = points;
        return List<gmaps.LatLng>.from(points);
      }
    } catch (_) {}

    return straight;
  }

  static List<gmaps.LatLng> decodePolyline(String encoded) {
    final List<gmaps.LatLng> points = [];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      points.add(gmaps.LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
