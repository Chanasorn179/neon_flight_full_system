import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/data/mock_api.dart';
import 'package:mini_projects/models/entities.dart';
import 'package:mini_projects/providers/booking_provider.dart';
import 'package:mini_projects/providers/flight_provider.dart';
import 'package:mini_projects/repositories/booking_repository.dart';
import 'package:mini_projects/repositories/flight_repository.dart';

final _passenger = PassengerEntity(
  title: 'Ms.',
  firstName: 'Anong',
  lastName: 'Sukjai',
  birthDate: DateTime(1998),
  nationality: 'Thai',
  passportNumber: 'AA1234567',
  passportExpiry: DateTime(2031),
  phone: '0812345678',
  email: 'anong@example.com',
);

/// Searches MockApi directly (the app's repository first tries the backend).
class _OfflineFlights implements FlightRepository {
  final api = MockApi();
  @override
  Future<List<AirportEntity>> airports() async => api.airports;
  @override
  Future<List<FlightEntity>> search(String from, String to, DateTime date) =>
      api.searchFlights(from, to, date);
  @override
  List<PromotionEntity> promotions() => api.promotions;
}

void main() {
  test('round trip searches both legs; one way does not', () async {
    final flights = FlightProvider(_OfflineFlights())
      ..setRoute('BKK', 'CNX')
      ..setDeparture(DateTime(2026, 11, 20));

    await flights.search();
    expect(flights.returnResults, isEmpty);

    flights.setTripType(TripType.roundTrip);
    expect(flights.returnDate, DateTime(2026, 11, 23));
    await flights.search();
    expect(flights.results.first.departure.code, 'BKK');
    expect(flights.returnResults, isNotEmpty);
    expect(flights.returnResults.first.departure.code, 'CNX');

    final outbound = flights.results.first;
    expect(
      flights.returnOptionsAfter(outbound).every(
            (f) => f.departureTime.isAfter(outbound.arrivalTime),
          ),
      isTrue,
    );
  });

  test('round trip books two linked legs together', () async {
    final api = MockApi();
    final bookings = BookingProvider(MockBookingRepository(api));
    final out = (await api.searchFlights('BKK', 'CNX', DateTime(2026, 11, 20))).first;
    final back = (await api.searchFlights('CNX', 'BKK', DateTime(2026, 11, 23))).first;

    final created = await bookings.create(
      userId: 'u1',
      flight: out,
      cabinClass: CabinClass.economy,
      passengers: [_passenger],
      seats: const ['3A'],
      paymentMethod: PaymentMethod.promptPay,
      returnFlight: back,
      returnSeats: const ['4C'],
    );

    expect(created, hasLength(2));
    expect(created[0].flight, out);
    expect(created[1].flight, back);
    expect(created[1].id, '${created[0].id}R');
    expect(created.map((b) => b.tripId).toSet(), {created[0].id});
    expect(created[1].seats, ['4C']);
  });
}
