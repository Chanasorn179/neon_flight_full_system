import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/data/fares.dart';
import 'package:mini_projects/data/mock_api.dart';
import 'package:mini_projects/data/thai_airports.dart';
import 'package:mini_projects/models/entities.dart';
import 'package:mini_projects/providers/booking_provider.dart';

AirportEntity airport(String code) => thaiAirports.firstWhere((a) => a.code == code);

void main() {
  test('every bookable airport has coordinates', () {
    for (final a in thaiAirports) {
      expect(airportCoordinates.containsKey(a.code), isTrue, reason: a.code);
    }
  });

  test('airport tax follows AOT rates', () {
    expect(passengerServiceCharge(airport('BKK'), airport('CNX')), 130);
    expect(passengerServiceCharge(airport('BKK'), airport('SIN')), 1120);
    expect(passengerServiceCharge(airport('UTH'), airport('SIN')), 730);
  });

  test('block times and fares are in a realistic range', () {
    final km = distanceKm('BKK', 'CNX')!;
    expect(km, closeTo(596, 10));
    expect(blockTime(km).inMinutes, inInclusiveRange(65, 85));

    double fare(String airline) => economyFare(
          airlineCode: airline,
          km: km,
          international: false,
          daysAhead: 30,
          hour: 12,
          weekday: DateTime.tuesday,
          jitter: 0,
        );
    // Low-cost BKK-CNX ~1,200-2,000; Thai Airways from ~4,700 incl. tax.
    expect(fare('FD'), inInclusiveRange(1100, 2000));
    expect(fare('TG'), inInclusiveRange(3800, 5200));
    expect(fare('FD') % 100, 90);
  });

  test('last-minute seats cost more than seats bought ahead', () {
    double fare(int days) => economyFare(
          airlineCode: 'FD',
          km: 600,
          international: false,
          daysAhead: days,
          hour: 12,
          weekday: DateTime.tuesday,
          jitter: 0,
        );
    expect(fare(2), greaterThan(fare(20)));
    expect(fare(20), greaterThan(fare(60)));
  });

  test('payment total = fare + airport tax + seat fee, no invented fees', () async {
    final flight = (await MockApi().searchFlights('BKK', 'CNX', DateTime.now().add(const Duration(days: 30)))).first;
    final fare = BookingProvider.fareFor(flight, CabinClass.economy, 2, 2);
    expect(fare.tax, 260);
    expect(fare.service, 0);
    expect(fare.seatFee, 380);
    expect(fare.total, flight.price(CabinClass.economy) * 2 + 260 + 380);
  });
}
