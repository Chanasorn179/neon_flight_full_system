import 'dart:math';
import '../models/travel_models.dart';
import 'fares.dart';
import 'thai_airlines.dart';
import 'thai_airports.dart';

class MockApi {
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
    final km = distanceKm(from, to) ?? 600;
    final block = blockTime(km);
    final today = DateTime.now();
    final daysAhead = DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;

    // Seeded by route and day so a search always returns the same schedule;
    // seat locks rely on flight numbers being stable.
    final rng = Random(
      '$from$to${date.year}${date.month}${date.day}'
          .codeUnits
          .fold<int>(17, (h, c) => (h * 31 + c) & 0x7fffffff),
    );

    return List.generate(count, (i) {
      final airline = carriers[i % carriers.length];
      final depTime = DateTime(date.year, date.month, date.day, 6)
          .add(Duration(minutes: i * (16 * 60 ~/ count) + rng.nextInt(4) * 10));
      final duration = block + Duration(minutes: rng.nextInt(3) * 5);
      final fare = economyFare(
        airlineCode: airline.code,
        km: km,
        international: international,
        daysAhead: daysAhead,
        hour: depTime.hour,
        weekday: depTime.weekday,
        jitter: rng.nextDouble() * 2 - 1,
      );
      return FlightEntity(
        id: '$from${to}_${date.year}${date.month}${date.day}_$i',
        airline: airline.nameEn,
        flightNumber: '${airline.code}${100 + rng.nextInt(800)}',
        departure: dep,
        arrival: arr,
        departureTime: depTime,
        arrivalTime: depTime.add(duration),
        basePrice: fare,
        availableSeats: 3 + rng.nextInt(18),
      );
    });
  }


  Future<List<BookingEntity>> createBookings(List<BookingEntity> bookings) async {
    await _wait();
    for (final booking in bookings) {
      final clash = takenSeats(booking.flight.scheduleKey)
          .intersection(booking.seats.toSet());
      if (clash.isNotEmpty) throw SeatTakenException(clash);
    }
    _bookings.addAll(bookings);
    return bookings;
  }

  Future<void> cancelBookings(Set<String> ids) async {
    await _wait();
    for (var i = 0; i < _bookings.length; i++) {
      if (ids.contains(_bookings[i].id)) {
        _bookings[i] = _bookings[i].withStatus(BookingStatus.cancelled);
      }
    }
  }

  Set<String> takenSeats(String scheduleKey) => {
        for (final b in _bookings)
          if (b.flight.scheduleKey == scheduleKey &&
              b.status != BookingStatus.cancelled)
            ...b.seats,
      };

  Future<List<BookingEntity>> bookings(String userId) async {
    await _wait();
    return _bookings
        .where((b) => b.userId == userId)
        .toList()
        .reversed
        .toList();
  }
}
