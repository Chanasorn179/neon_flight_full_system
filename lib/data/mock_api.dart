import 'dart:math';
import '../models/entities.dart';

class MockApi {
  MockApi() {
    _seedBookingHistory();
  }

  final _random = Random(42);
  final List<UserEntity> _users = [
    const UserEntity(
      id: 'u1',
      name: 'Aero Traveler',
      email: 'demo@neonflight.app',
    ),
  ];
  final List<BookingEntity> _bookings = [];

  final airports = const [
    AirportEntity(
      code: 'BKK',
      cityEn: 'Bangkok',
      cityTh: 'กรุงเทพฯ',
      nameEn: 'Suvarnabhumi',
      nameTh: 'สุวรรณภูมิ',
    ),
    AirportEntity(
      code: 'CNX',
      cityEn: 'Chiang Mai',
      cityTh: 'เชียงใหม่',
      nameEn: 'Chiang Mai',
      nameTh: 'เชียงใหม่',
    ),
    AirportEntity(
      code: 'HKT',
      cityEn: 'Phuket',
      cityTh: 'ภูเก็ต',
      nameEn: 'Phuket',
      nameTh: 'ภูเก็ต',
    ),
    AirportEntity(
      code: 'NRT',
      cityEn: 'Tokyo',
      cityTh: 'โตเกียว',
      nameEn: 'Narita',
      nameTh: 'นาริตะ',
    ),
    AirportEntity(
      code: 'ICN',
      cityEn: 'Seoul',
      cityTh: 'โซล',
      nameEn: 'Incheon',
      nameTh: 'อินชอน',
    ),
    AirportEntity(
      code: 'SIN',
      cityEn: 'Singapore',
      cityTh: 'สิงคโปร์',
      nameEn: 'Changi',
      nameTh: 'ชางงี',
    ),
  ];

  void _seedBookingHistory() {
    final now = DateTime.now();
    final passenger = PassengerEntity(
      title: 'Mr.',
      firstName: 'Aero',
      lastName: 'Traveler',
      birthDate: DateTime(1995, 6, 18),
      nationality: 'Thai',
      passportNumber: 'AA1234567',
      passportExpiry: DateTime(now.year + 4, 6, 18),
      phone: '0812345678',
      email: 'demo@neonflight.app',
    );

    _bookings.addAll([
      _historyBooking(
        id: 'NF260801',
        from: airports[0],
        to: airports[3],
        departureTime: now.add(const Duration(days: 12, hours: 3)),
        duration: const Duration(hours: 6, minutes: 10),
        flightNumber: 'NF120',
        airline: 'Neon Air',
        cabinClass: CabinClass.business,
        seats: const ['4A'],
        passenger: passenger,
        status: BookingStatus.upcoming,
        fare: const FareBreakdown(
          fare: 12800,
          tax: 700,
          service: 150,
          seatFee: 200,
        ),
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      _historyBooking(
        id: 'NF260614',
        from: airports[0],
        to: airports[1],
        departureTime: now.subtract(const Duration(days: 34, hours: 2)),
        duration: const Duration(hours: 1, minutes: 15),
        flightNumber: 'NF126',
        airline: 'Neon Air',
        cabinClass: CabinClass.economy,
        seats: const ['18C'],
        passenger: passenger,
        status: BookingStatus.completed,
        fare: const FareBreakdown(
          fare: 2350,
          tax: 700,
          service: 150,
          seatFee: 200,
        ),
        createdAt: now.subtract(const Duration(days: 58)),
      ),
      _historyBooking(
        id: 'NF260327',
        from: airports[0],
        to: airports[2],
        departureTime: now.subtract(const Duration(days: 105)),
        duration: const Duration(hours: 1, minutes: 25),
        flightNumber: 'SJ421',
        airline: 'SkyJet',
        cabinClass: CabinClass.premiumEconomy,
        seats: const ['9F'],
        passenger: passenger,
        status: BookingStatus.completed,
        fare: const FareBreakdown(
          fare: 3890,
          tax: 700,
          service: 150,
          seatFee: 200,
        ),
        createdAt: now.subtract(const Duration(days: 127)),
      ),
      _historyBooking(
        id: 'NF260722',
        from: airports[0],
        to: airports[4],
        departureTime: now.add(const Duration(days: 21, hours: 5)),
        duration: const Duration(hours: 5, minutes: 30),
        flightNumber: 'SJ424',
        airline: 'SkyJet',
        cabinClass: CabinClass.economy,
        seats: const ['22A'],
        passenger: passenger,
        status: BookingStatus.cancelled,
        fare: const FareBreakdown(
          fare: 6400,
          tax: 700,
          service: 150,
          seatFee: 200,
        ),
        createdAt: now.subtract(const Duration(days: 16)),
      ),
    ]);
  }

  BookingEntity _historyBooking({
    required String id,
    required AirportEntity from,
    required AirportEntity to,
    required DateTime departureTime,
    required Duration duration,
    required String flightNumber,
    required String airline,
    required CabinClass cabinClass,
    required List<String> seats,
    required PassengerEntity passenger,
    required BookingStatus status,
    required FareBreakdown fare,
    required DateTime createdAt,
  }) {
    return BookingEntity(
      id: id,
      userId: 'u1',
      flight: FlightEntity(
        id: 'history_$id',
        airline: airline,
        flightNumber: flightNumber,
        departure: from,
        arrival: to,
        departureTime: departureTime,
        arrivalTime: departureTime.add(duration),
        basePrice: fare.fare,
        availableSeats: 0,
      ),
      cabinClass: cabinClass,
      passengers: [passenger],
      seats: seats,
      fare: fare,
      paymentMethod: PaymentMethod.promptPay,
      status: status,
      createdAt: createdAt,
    );
  }

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
    return List.generate(5, (i) {
      final startHour = 6 + i * 3;
      final depTime = DateTime(
        date.year,
        date.month,
        date.day,
        startHour.clamp(0, 23).toInt(),
        i.isEven ? 10 : 35,
      );
      final duration = Duration(
        hours: 2 + _random.nextInt(4),
        minutes: _random.nextBool() ? 15 : 45,
      );
      return FlightEntity(
        id: '$from${to}_${date.millisecondsSinceEpoch}_$i',
        airline: i.isEven ? 'Neon Air' : 'SkyJet',
        flightNumber: i.isEven ? 'NF${120 + i}' : 'SJ${420 + i}',
        departure: dep,
        arrival: arr,
        departureTime: depTime,
        arrivalTime: depTime.add(duration),
        basePrice: 1600 + i * 430.0 + _random.nextInt(300),
        availableSeats: 3 + _random.nextInt(18),
      );
    });
  }

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
