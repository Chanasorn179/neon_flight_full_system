import '../models/entities.dart';

// Keep in sync with AIRLINES in tool/build_airport_data.py (Firestore seed).
const thaiAirlines = <AirlineEntity>[
  AirlineEntity(
    code: 'TG',
    nameEn: 'Thai Airways',
    nameTh: 'การบินไทย',
    hubs: ['BKK'],
    international: true,
    color: 0xFF5C2D91,
  ),
  AirlineEntity(
    code: 'FD',
    nameEn: 'Thai AirAsia',
    nameTh: 'ไทยแอร์เอเชีย',
    hubs: ['DMK', 'BKK'],
    international: true,
    color: 0xFFE4002B,
  ),
  AirlineEntity(
    code: 'PG',
    nameEn: 'Bangkok Airways',
    nameTh: 'บางกอกแอร์เวย์ส',
    hubs: ['BKK', 'USM'],
    international: false,
    color: 0xFF00549F,
  ),
  AirlineEntity(
    code: 'VZ',
    nameEn: 'Thai Vietjet',
    nameTh: 'ไทยเวียตเจ็ท',
    hubs: ['BKK'],
    international: true,
    color: 0xFFD6001C,
  ),
  AirlineEntity(
    code: 'SL',
    nameEn: 'Thai Lion Air',
    nameTh: 'ไทยไลอ้อนแอร์',
    hubs: ['DMK'],
    international: true,
    color: 0xFFB5121B,
  ),
  AirlineEntity(
    code: 'DD',
    nameEn: 'Nok Air',
    nameTh: 'นกแอร์',
    hubs: ['DMK'],
    international: false,
    color: 0xFFF2A900,
  ),
  AirlineEntity(
    code: 'XJ',
    nameEn: 'Thai AirAsia X',
    nameTh: 'ไทยแอร์เอเชีย เอ็กซ์',
    hubs: ['DMK'],
    international: true,
    color: 0xFFC8102E,
  ),
];

AirlineEntity? airlineForFlight(String airlineName, String flightNumber) {
  final prefix = flightNumber.length >= 2 ? flightNumber.substring(0, 2) : '';
  for (final airline in thaiAirlines) {
    if (airline.code == prefix || airline.nameEn == airlineName) return airline;
  }
  return null;
}

/// Airlines that plausibly operate [from] → [to] in the demo schedule.
/// Not a real route map: flights from Bangkok use the carriers based at that
/// airport; other domestic pairs fall back to the widest domestic networks.
List<AirlineEntity> airlinesForRoute(AirportEntity from, AirportEntity to) {
  final international = !from.isDomestic || !to.isDomestic;
  bool servesEnd(AirlineEntity a) =>
      a.hubs.contains(from.code) || a.hubs.contains(to.code);

  var matches = thaiAirlines
      .where((a) => a.international || !international)
      .where((a) => international ? a.code != 'PG' : a.code != 'XJ')
      .where(servesEnd)
      .toList();
  if (matches.isEmpty) {
    final fallback = ['FD', 'VZ', 'TG', if (!international) 'PG'];
    matches = thaiAirlines.where((a) => fallback.contains(a.code)).toList();
  }
  return matches;
}
