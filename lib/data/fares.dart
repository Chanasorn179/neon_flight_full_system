import 'dart:math';

import '../models/travel_models.dart';

/// Fare model for the demo schedule, calibrated to real Thai market prices
/// (October 2026): low-cost carriers sell Bangkok–Chiang Mai from roughly
/// THB 1,200–2,000, Thai Airways from about THB 4,700. There is no live fare
/// feed, so prices are estimates — but taxes follow the published rules.

/// Approximate airport coordinates (lat, lon) for distances and the route map.
const airportCoordinates = <String, (double, double)>{
  'BKK': (13.690, 100.750),
  'DMK': (13.913, 100.607),
  'HKT': (8.113, 98.317),
  'CNX': (18.767, 98.963),
  'HDY': (6.933, 100.393),
  'USM': (9.548, 100.062),
  'KBV': (8.099, 98.986),
  'UTP': (12.680, 101.005),
  'CEI': (19.952, 99.883),
  'BFV': (15.229, 103.253),
  'UTH': (17.386, 102.788),
  'NST': (8.540, 99.945),
  'PHS': (16.783, 100.279),
  'URT': (9.133, 99.136),
  'HHQ': (12.636, 99.952),
  'LPT': (18.271, 99.504),
  'MAQ': (16.700, 98.545),
  'LOE': (17.439, 101.722),
  'THS': (17.238, 99.818),
  'UNN': (9.778, 98.585),
  'UBP': (15.251, 104.870),
  'KKC': (16.466, 102.784),
  'TST': (7.509, 99.617),
  'NNT': (18.808, 100.783),
  'CJM': (10.711, 99.362),
  'TDX': (12.274, 102.319),
  'ROI': (16.117, 103.774),
  'SNO': (17.195, 104.119),
  'NAW': (6.520, 101.743),
  'KOP': (17.384, 104.643),
  'BTZ': (5.785, 101.149),
  'NRT': (35.765, 140.386),
  'ICN': (37.460, 126.441),
  'SIN': (1.364, 103.991),
};

/// Great-circle distance in km, or null when a coordinate is unknown.
double? distanceKm(String from, String to) {
  final a = airportCoordinates[from];
  final b = airportCoordinates[to];
  if (a == null || b == null) return null;
  double rad(double d) => d * pi / 180;
  final dLat = rad(b.$1 - a.$1);
  final dLon = rad(b.$2 - a.$2);
  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(a.$1)) * cos(rad(b.$1)) * sin(dLon / 2) * sin(dLon / 2);
  return 6371 * 2 * atan2(sqrt(h), sqrt(1 - h));
}

/// Scheduled block time: taxi/climb overhead plus cruise at ~780 km/h.
Duration blockTime(double km) =>
    Duration(minutes: (30 + km / 780 * 60).round() ~/ 5 * 5);

/// AOT airports charge the higher international PSC.
const _aotAirports = {'BKK', 'DMK', 'CNX', 'CEI', 'HKT', 'HDY'};

/// Passenger service charge (airport tax) per passenger, in THB, included in
/// every Thai ticket. AOT: domestic 130; international departures 1,120
/// (raised from 730 on 20 June 2026). Departures from abroad use an estimate
/// of the foreign airport's charges.
double passengerServiceCharge(AirportEntity from, AirportEntity to) {
  final international = !from.isDomestic || !to.isDomestic;
  if (!from.isDomestic) return 900; // estimate for foreign departure airports
  if (!international) return 130;
  return _aotAirports.contains(from.code) ? 1120 : 730;
}

/// Full-service carriers price higher than low-cost ones.
const _fullService = {'TG', 'PG'};

/// Economy base fare (excluding airport tax) for one passenger.
///
/// [daysAhead] and [hour] add the usual demand pricing: last-minute and
/// peak-hour seats cost more; [jitter] in -1..1 varies flights on a route.
double economyFare({
  required String airlineCode,
  required double km,
  required bool international,
  required int daysAhead,
  required int hour,
  required int weekday,
  required double jitter,
}) {
  final full = _fullService.contains(airlineCode);
  // Per-km curve fitted to observed fares: LCC BKK–CNX (~590 km) ≈ 1,350,
  // TG ≈ 4,400; LCC BKK–SIN ≈ 3,200; LCC BKK–NRT ≈ 9,500.
  double fare = full
      ? 1900 + km * (international ? 5.6 : 4.2)
      : 620 + km * (international ? 2.4 : 1.25);

  final demand = daysAhead <= 3
      ? 1.6
      : daysAhead <= 7
          ? 1.35
          : daysAhead <= 14
              ? 1.15
              : daysAhead > 45
                  ? .9
                  : 1.0;
  final weekend = weekday == DateTime.friday || weekday == DateTime.sunday ? 1.12 : 1.0;
  final peak = (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 20) ? 1.1 : 1.0;
  fare *= demand * weekend * peak * (1 + jitter * .08);

  // Airlines publish prices ending in 90 (e.g. 1,390).
  return ((fare / 100).round() * 100 - 10).toDouble();
}
