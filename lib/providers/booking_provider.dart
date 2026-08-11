import 'package:flutter/foundation.dart';
import '../models/entities.dart';
import '../repositories/booking_repository.dart';
import '../services/firebase_service.dart';

class BookingProvider extends ChangeNotifier {
  BookingProvider(this.repository);
  final BookingRepository repository;
  List<BookingEntity> bookings = [];
  final List<TransferBookingEntity> transferBookings = [];
  bool loading = false;

  Future<BookingEntity> create({
    required String userId,
    required FlightEntity flight,
    required CabinClass cabinClass,
    required List<PassengerEntity> passengers,
    required List<String> seats,
    required PaymentMethod paymentMethod,
  }) async {
    final fare = FareBreakdown(
      fare: flight.price(cabinClass) * passengers.length,
      tax: 700 * passengers.length.toDouble(),
      service: 150 * passengers.length.toDouble(),
      seatFee: seats.length * cabinClass.seatFee,
    );
    final booking = BookingEntity(
      id: 'NF${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      userId: userId,
      flight: flight,
      cabinClass: cabinClass,
      passengers: passengers,
      seats: seats,
      fare: fare,
      paymentMethod: paymentMethod,
      status: BookingStatus.upcoming,
      createdAt: DateTime.now(),
    );

    final created = await repository.create(booking);
    await FirebaseService.saveBooking(_bookingToMap(created), created.id);
    bookings.insert(0, created);
    notifyListeners();
    return created;
  }

  void addTransferBooking(TransferBookingEntity booking) {
    final existingIndex = transferBookings.indexWhere(
      (item) =>
          item.userId == booking.userId &&
          item.airportCode == booking.airportCode &&
          item.flightDepartureTime == booking.flightDepartureTime,
    );

    if (existingIndex == -1) {
      transferBookings.insert(0, booking);
    } else {
      transferBookings[existingIndex] = booking;
    }
    notifyListeners();
  }

  TransferBookingEntity? transferBookingFor({
    required String userId,
    required String airportCode,
    required DateTime flightDepartureTime,
  }) {
    for (final booking in transferBookings) {
      if (booking.userId == userId &&
          booking.airportCode == airportCode &&
          booking.flightDepartureTime == flightDepartureTime) {
        return booking;
      }
    }
    return null;
  }

  Future<void> load(String userId) async {
    loading = true;
    notifyListeners();
    try {
      if (FirebaseService.enabled) {
        final cloud = await FirebaseService.bookingsForUser(userId);
        bookings = cloud.map(_bookingFromMap).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        bookings = await repository.forUser(userId);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}


Map<String, dynamic> _bookingToMap(BookingEntity b) => {
  'id': b.id,
  'userId': b.userId,
  'flight': {
    'id': b.flight.id, 'airline': b.flight.airline, 'flightNumber': b.flight.flightNumber,
    'departureCode': b.flight.departure.code, 'arrivalCode': b.flight.arrival.code,
    'departureTime': b.flight.departureTime.toIso8601String(),
    'arrivalTime': b.flight.arrivalTime.toIso8601String(),
  },
  'cabinClass': b.cabinClass.name,
  'passengers': b.passengers.map((p) => {
    'title': p.title, 'firstName': p.firstName, 'lastName': p.lastName,
    'birthDate': p.birthDate.toIso8601String(), 'nationality': p.nationality,
    'passportNumber': p.passportNumber, 'passportExpiry': p.passportExpiry.toIso8601String(),
    'phone': p.phone, 'email': p.email,
  }).toList(),
  'seats': b.seats,
  'fare': {'fare': b.fare.fare, 'tax': b.fare.tax, 'service': b.fare.service, 'seatFee': b.fare.seatFee, 'total': b.fare.total},
  'paymentMethod': b.paymentMethod.name,
  'status': b.status.name,
  'createdAt': b.createdAt.toIso8601String(),
};


BookingEntity _bookingFromMap(Map<String, dynamic> m) {
  final f = Map<String, dynamic>.from(m['flight'] as Map? ?? const {});
  final depCode = f['departureCode']?.toString() ?? '---';
  final arrCode = f['arrivalCode']?.toString() ?? '---';
  final dep = AirportEntity(code: depCode, cityEn: depCode, cityTh: depCode, nameEn: depCode, nameTh: depCode);
  final arr = AirportEntity(code: arrCode, cityEn: arrCode, cityTh: arrCode, nameEn: arrCode, nameTh: arrCode);
  final passengersRaw = (m['passengers'] as List? ?? const []);
  final passengers = passengersRaw.map((e) {
    final p = Map<String, dynamic>.from(e as Map);
    DateTime dt(String key) => DateTime.tryParse(p[key]?.toString() ?? '') ?? DateTime(2000);
    return PassengerEntity(
      title: p['title']?.toString() ?? '', firstName: p['firstName']?.toString() ?? '', lastName: p['lastName']?.toString() ?? '',
      birthDate: dt('birthDate'), nationality: p['nationality']?.toString() ?? '', passportNumber: p['passportNumber']?.toString() ?? '',
      passportExpiry: dt('passportExpiry'), phone: p['phone']?.toString() ?? '', email: p['email']?.toString() ?? '',
    );
  }).toList();
  final fare = Map<String, dynamic>.from(m['fare'] as Map? ?? const {});
  double n(String key) => (fare[key] as num?)?.toDouble() ?? 0;
  T enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) => values.firstWhere((e) => e.name == raw?.toString(), orElse: () => fallback);
  return BookingEntity(
    id: m['id']?.toString() ?? '', userId: m['userId']?.toString() ?? '',
    flight: FlightEntity(
      id: f['id']?.toString() ?? '', airline: f['airline']?.toString() ?? '', flightNumber: f['flightNumber']?.toString() ?? '',
      departure: dep, arrival: arr,
      departureTime: DateTime.tryParse(f['departureTime']?.toString() ?? '') ?? DateTime.now(),
      arrivalTime: DateTime.tryParse(f['arrivalTime']?.toString() ?? '') ?? DateTime.now(),
      basePrice: n('fare'), availableSeats: 0,
    ),
    cabinClass: enumByName(CabinClass.values, m['cabinClass'], CabinClass.economy), passengers: passengers,
    seats: (m['seats'] as List? ?? const []).map((e) => e.toString()).toList(),
    fare: FareBreakdown(fare: n('fare'), tax: n('tax'), service: n('service'), seatFee: n('seatFee')),
    paymentMethod: enumByName(PaymentMethod.values, m['paymentMethod'], PaymentMethod.promptPay),
    status: enumByName(BookingStatus.values, m['status'], BookingStatus.upcoming),
    createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );
}
