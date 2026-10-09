import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Driving distance and time between two points.
class RoadRoute {
  const RoadRoute({required this.distanceKm, required this.duration});

  final double distanceKm;
  final Duration duration;
}

typedef RoadRouteLookup =
    Future<RoadRoute?> Function(
      double fromLat,
      double fromLng,
      double toLat,
      double toLng,
    );

/// Real road distance from the OSRM routing engine (OpenStreetMap data).
/// Returns null when offline or the service has no route, so callers can
/// fall back to the straight-line distance.
class RoadDistanceService {
  RoadDistanceService._();

  static const _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  /// Tests replace the network lookup with a fixed answer.
  @visibleForTesting
  static RoadRouteLookup? debugLookup;

  static Future<RoadRoute?> drive({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final override = debugLookup;
    if (override != null) return override(fromLat, fromLng, toLat, toLng);

    // OSRM takes lon,lat pairs.
    final uri = Uri.parse(
      '$_baseUrl/$fromLng,$fromLat;$toLng,$toLat?overview=false',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return parse(response.body);
    } catch (_) {
      return null;
    }
  }

  /// Reads the first route of an OSRM `route` response.
  @visibleForTesting
  static RoadRoute? parse(String body) {
    final json = jsonDecode(body);
    if (json is! Map || json['code'] != 'Ok') return null;
    final routes = json['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final route = routes.first as Map;
    final meters = (route['distance'] as num?)?.toDouble();
    final seconds = (route['duration'] as num?)?.toDouble();
    if (meters == null || seconds == null) return null;
    return RoadRoute(
      distanceKm: meters / 1000,
      duration: Duration(seconds: seconds.round()),
    );
  }
}
