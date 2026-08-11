import 'dart:math';
import '../models/entities.dart';

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
    AirportEntity(
      code: 'DMK',
      cityEn: 'Bangkok',
      cityTh: 'กรุงเทพฯ',
      nameEn: 'Don Mueang',
      nameTh: 'ดอนเมือง',
    ),
  ];

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
