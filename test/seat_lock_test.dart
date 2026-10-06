import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/data/mock_api.dart';
import 'package:mini_projects/models/entities.dart';
import 'package:mini_projects/providers/flight_provider.dart';
import 'package:mini_projects/repositories/booking_repository.dart';
import 'package:mini_projects/repositories/flight_repository.dart';

final _passenger = PassengerEntity(
  title: 'Mr.',
  firstName: 'Test',
  lastName: 'User',
  birthDate: DateTime(1990),
  nationality: 'Thai',
  passportNumber: 'AA0000000',
  passportExpiry: DateTime(2035),
  phone: '0800000000',
  email: 'test@example.com',
);

BookingEntity _booking(String id, FlightEntity flight, List<String> seats) =>
    BookingEntity(
      id: id,
      userId: 'u1',
      flight: flight,
      cabinClass: CabinClass.economy,
      passengers: [_passenger],
      seats: seats,
      fare: const FareBreakdown(fare: 1, tax: 0, service: 0, seatFee: 0),
      paymentMethod: PaymentMethod.promptPay,
      status: BookingStatus.upcoming,
      createdAt: DateTime(2026),
    );

void main() {
  final date = DateTime(2026, 11, 20, 15, 42); // time of day must not matter

  test('the same route and day always yields the same schedule', () async {
    final a = await MockApi().searchFlights('BKK', 'CNX', date);
    final b = await MockApi().searchFlights('BKK', 'CNX', DateTime(2026, 11, 20));
    expect(a.map((f) => f.scheduleKey), b.map((f) => f.scheduleKey));
  });

  test('a seat cannot be booked twice on the same departure', () async {
    final api = MockApi();
    final repo = MockBookingRepository(api);
    final flight = (await api.searchFlights('BKK', 'CNX', date)).first;

    await repo.create(_booking('NF1', flight, ['12C']));
    expect(await repo.takenSeats(flight), {'12C'});
    await expectLater(
      repo.create(_booking('NF2', flight, ['12C', '12D'])),
      throwsA(isA<SeatTakenException>()),
    );
    await repo.create(_booking('NF3', flight, ['12D']));
    expect(await repo.takenSeats(flight), {'12C', '12D'});
  });

  test('passenger count is capped at 9', () {
    final provider = FlightProvider(MockFlightRepository(MockApi()));
    provider.setPassengers(6, 3);
    expect(provider.passengerCount, 9);
    provider.setPassengers(7, 3);
    expect(provider.passengerCount, 9);
  });
}
