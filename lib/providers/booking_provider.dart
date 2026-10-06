import 'package:flutter/foundation.dart';
import '../models/entities.dart';
import '../repositories/booking_repository.dart';

class BookingProvider extends ChangeNotifier {
  BookingProvider(this.repository);
  final BookingRepository repository;
  List<BookingEntity> bookings = [];
  final List<TransferBookingEntity> transferBookings = [];
  bool loading = false;

  /// Fare for one leg; also used by the payment screen to show the total.
  static FareBreakdown fareFor(
    FlightEntity flight,
    CabinClass cabinClass,
    int passengerCount,
    int seatCount,
  ) =>
      FareBreakdown(
        fare: flight.price(cabinClass) * passengerCount,
        tax: 700 * passengerCount.toDouble(),
        service: 150 * passengerCount.toDouble(),
        seatFee: seatCount * cabinClass.seatFee,
      );

  /// Books one flight, or both legs of a round trip in one all-or-nothing
  /// write. Returns the outbound booking first.
  Future<List<BookingEntity>> create({
    required String userId,
    required FlightEntity flight,
    required CabinClass cabinClass,
    required List<PassengerEntity> passengers,
    required List<String> seats,
    required PaymentMethod paymentMethod,
    FlightEntity? returnFlight,
    List<String> returnSeats = const [],
  }) async {
    final id =
        'NF${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final now = DateTime.now();

    BookingEntity leg(String legId, FlightEntity f, List<String> legSeats) =>
        BookingEntity(
          id: legId,
          userId: userId,
          flight: f,
          cabinClass: cabinClass,
          passengers: passengers,
          seats: legSeats,
          fare: fareFor(f, cabinClass, passengers.length, legSeats.length),
          paymentMethod: paymentMethod,
          status: BookingStatus.upcoming,
          createdAt: now,
          tripId: returnFlight == null ? null : id,
        );

    final created = await repository.createAll([
      leg(id, flight, seats),
      if (returnFlight != null) leg('${id}R', returnFlight, returnSeats),
    ]);
    bookings.insertAll(0, created);
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
      bookings = await repository.forUser(userId)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
