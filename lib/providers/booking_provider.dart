import 'package:flutter/foundation.dart';
import '../models/entities.dart';
import '../repositories/booking_repository.dart';

class BookingProvider extends ChangeNotifier {
  BookingProvider(this.repository);
  final BookingRepository repository;
  List<BookingEntity> bookings = [];
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
      seatFee: seats.length * 200,
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
    bookings.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<void> load(String userId) async {
    loading = true;
    notifyListeners();
    try {
      bookings = await repository.forUser(userId);
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
