import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/data/offline_mock_api.dart';
import 'package:mini_projects/data/thai_airlines.dart';

void main() {
  final api = MockApi();
  final date = DateTime(2026, 11, 1);

  test('airports come from the statistics dataset, busiest first', () {
    expect(api.airports.first.code, 'BKK');
    expect(api.airports.where((a) => a.isDomestic).length, greaterThan(20));
    expect(api.airports.map((a) => a.code), containsAll(['NRT', 'ICN', 'SIN']));
  });

  test('every mock flight is operated by a Thai airline', () async {
    for (final route in [
      ['BKK', 'CNX'],
      ['DMK', 'HKT'],
      ['CNX', 'HKT'],
      ['BKK', 'NRT'],
    ]) {
      final flights = await api.searchFlights(route[0], route[1], date);
      expect(flights, isNotEmpty, reason: route.join('-'));
      for (final f in flights) {
        final airline = airlineForFlight(f.airline, f.flightNumber);
        expect(airline, isNotNull, reason: f.flightNumber);
      }
    }
  });

  test('domestic-only airlines are not offered on international routes', () async {
    final flights = await api.searchFlights('BKK', 'NRT', date);
    final codes = flights.map((f) => f.flightNumber.substring(0, 2)).toSet();
    expect(codes.intersection({'PG', 'DD'}), isEmpty);
  });
}
