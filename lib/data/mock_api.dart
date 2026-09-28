import 'dart:math';
import '../models/entities.dart';
import 'thai_airlines.dart';
import 'thai_airports.dart';

class MockApi {
  final _random = Random(42);
  final List<UserEntity> _users = [
    const UserEntity(
      id: 'u1',
      name: 'Aero Traveler',
      email: 'demo@neonflight.app',
    ),
  ];
  final List<BookingEntity> _bookings = [];

  final List<AirportEntity> airports = thaiAirports;

  List<PromotionEntity> get promotions => const [
    PromotionEntity(
      title: 'Tokyo Business Deal',
      from: 'BKK',
      to: 'NRT',
      cabinClass: CabinClass.business,
      discountPercent: 27,
      seatsLeft: 4,
    ),
    PromotionEntity(
      title: 'Seoul Summer Deal',
      from: 'BKK',
      to: 'ICN',
      cabinClass: CabinClass.economy,
      discountPercent: 22,
      seatsLeft: 7,
    ),
    PromotionEntity(
      title: 'Singapore First Deal',
      from: 'BKK',
      to: 'SIN',
      cabinClass: CabinClass.first,
      discountPercent: 30,
      seatsLeft: 3,
    ),
  ];

  Future<void> _wait() =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  Future<UserEntity> login(String email, String password) async {
    await _wait();
    if (email.trim().isEmpty || password.length < 4) {
      throw Exception('Invalid email or password');
    }
    return _users.firstWhere(
      (u) => u.email == email.trim(),
      orElse: () => UserEntity(
        id: 'u${_users.length + 1}',
        name: email.split('@').first,
        email: email.trim(),
      ),
    );
  }

  Future<UserEntity> register(
    String name,
    String email,
    String password,
  ) async {
    await _wait();
    if (name.trim().isEmpty || !email.contains('@') || password.length < 6) {
      throw Exception('Please check your information');
    }
    final user = UserEntity(
      id: 'u${_users.length + 1}',
      name: name.trim(),
      email: email.trim(),
    );
    _users.add(user);
    return user;
  }

  Future<void> forgotPassword(String email) async {
    await _wait();
    if (!email.contains('@')) throw Exception('Invalid email');
  }

  Future<List<FlightEntity>> searchFlights(
    String from,
    String to,
    DateTime date,
  ) async {
    await _wait();
    final dep = airports.firstWhere((a) => a.code == from);
    final arr = airports.firstWhere((a) => a.code == to);
    final carriers = airlinesForRoute(dep, arr);
    final international = !dep.isDomestic || !arr.isDomestic;

    // Busier airports (by real passenger statistics) get more daily departures.
    final traffic = min(dep.passengers12m, arr.passengers12m);
    final count = international
        ? 4
        : traffic > 5000000
            ? 8
            : traffic > 1000000
                ? 6
                : traffic > 300000
                    ? 4
                    : 2;
    final blockMinutes = _blockMinutes[to] ?? _blockMinutes[from] ?? 75;

    return List.generate(count, (i) {
      final airline = carriers[i % carriers.length];
      final depTime = DateTime(date.year, date.month, date.day, 6)
          .add(Duration(minutes: i * (16 * 60 ~/ count) + _random.nextInt(4) * 10));
      final duration = Duration(minutes: blockMinutes + _random.nextInt(3) * 5);
      final baseFare = international
          ? 3200 + blockMinutes * 18.0
          : 900 + blockMinutes * 14.0;
      final premium = airline.code == 'TG' || airline.code == 'PG' ? 1.35 : 1.0;
      return FlightEntity(
        id: '$from${to}_${date.millisecondsSinceEpoch}_$i',
        airline: airline.nameEn,
        flightNumber: '${airline.code}${100 + _random.nextInt(800)}',
        departure: dep,
        arrival: arr,
        departureTime: depTime,
        arrivalTime: depTime.add(duration),
        basePrice: (baseFare * premium + _random.nextInt(400)).roundToDouble(),
        availableSeats: 3 + _random.nextInt(18),
      );
    });
  }

  /// Rough block times from Bangkok, used only for demo schedules.
  static const _blockMinutes = <String, int>{
    'NRT': 370,
    'ICN': 350,
    'SIN': 145,
    'HKT': 85,
    'USM': 70,
    'KBV': 80,
    'HDY': 85,
    'NAW': 100,
    'BTZ': 105,
    'TST': 85,
    'NST': 75,
    'URT': 70,
    'CNX': 75,
    'CEI': 80,
    'NNT': 75,
    'UTP': 40,
    'HHQ': 40,
  };

  Future<BookingEntity> createBooking(BookingEntity booking) async {
    await _wait();
    _bookings.add(booking);
    return booking;
  }

  Future<List<BookingEntity>> bookings(String userId) async {
    await _wait();
    return _bookings
        .where((b) => b.userId == userId)
        .toList()
        .reversed
        .toList();
  }
}
