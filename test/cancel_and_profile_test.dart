import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/data/offline_mock_api.dart';
import 'package:mini_projects/models/travel_models.dart';
import 'package:mini_projects/providers/auth_provider.dart';
import 'package:mini_projects/providers/booking_provider.dart';
import 'package:mini_projects/repositories/auth_repository.dart';
import 'package:mini_projects/repositories/booking_repository.dart';
import 'package:mini_projects/services/user_profile_store.dart';

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

void main() {
  test('cancelling a round trip cancels both legs and frees the seats', () async {
    final api = MockApi();
    final repo = MockBookingRepository(api);
    final provider = BookingProvider(repo);
    final out = (await api.searchFlights('BKK', 'CNX', DateTime(2026, 11, 20))).first;
    final back = (await api.searchFlights('CNX', 'BKK', DateTime(2026, 11, 23))).first;

    final created = await provider.create(
      userId: 'u1',
      flight: out,
      cabinClass: CabinClass.economy,
      passengers: [_passenger],
      seats: const ['3A'],
      paymentMethod: PaymentMethod.promptPay,
      returnFlight: back,
      returnSeats: const ['4C'],
    );
    // Mock mode marks bookings paid; make them cancellable like real ones.
    provider.bookings = [
      for (final b in provider.bookings) b.withPaymentStatus(PaymentStatus.pending),
    ];

    await provider.cancel(provider.bookings.firstWhere((b) => b.id == created[1].id));

    expect(provider.bookings.every((b) => b.status == BookingStatus.cancelled), isTrue);
    expect(await repo.takenSeats(out), isEmpty);
    expect(await repo.takenSeats(back), isEmpty);
  });

  test('paid bookings cannot be cancelled from the app', () {
    final booking = BookingEntity(
      id: 'NF1',
      userId: 'u1',
      flight: FlightEntity(
        id: 'f',
        airline: 'Thai Airways',
        flightNumber: 'TG100',
        departure: const AirportEntity(code: 'BKK', cityEn: '', cityTh: '', nameEn: '', nameTh: ''),
        arrival: const AirportEntity(code: 'CNX', cityEn: '', cityTh: '', nameEn: '', nameTh: ''),
        departureTime: DateTime(2026, 11, 20, 8),
        arrivalTime: DateTime(2026, 11, 20, 9),
        basePrice: 1000,
        availableSeats: 10,
      ),
      cabinClass: CabinClass.economy,
      passengers: [_passenger],
      seats: const ['1A'],
      fare: const FareBreakdown(fare: 1, tax: 0, service: 0, seatFee: 0),
      paymentMethod: PaymentMethod.promptPay,
      status: BookingStatus.upcoming,
      createdAt: DateTime(2026),
    );
    expect(booking.canCancel, isTrue);
    expect(booking.withPaymentStatus(PaymentStatus.paid).canCancel, isFalse);
    expect(booking.withStatus(BookingStatus.cancelled).canCancel, isFalse);
  });

  test('profile edits are stored and the name shows up for the user', () async {
    final auth = AuthProvider(MockAuthRepository(MockApi()));
    await auth.login('demo@neonflight.app', 'secret1');
    final uid = auth.currentUser!.id;

    await ProfileStore.save(uid, {'name': 'Anong S.', 'phone': '0812345678'});
    await ProfileStore.save(uid, {
      'passport': {'number': 'AA1234567', 'nationality': 'Thai', 'expiry': '2031-01-01'},
    });
    auth.updateName('Anong S.');

    final data = await ProfileStore.load(uid);
    expect(data['phone'], '0812345678');
    expect((data['passport'] as Map)['number'], 'AA1234567');
    expect(auth.currentUser!.name, 'Anong S.');
  });
}
