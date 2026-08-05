import '../data/mock_api.dart';
import '../models/entities.dart';

abstract class BookingRepository {
  Future<BookingEntity> create(BookingEntity booking);
  Future<List<BookingEntity>> forUser(String userId);
}

class MockBookingRepository implements BookingRepository {
  MockBookingRepository(this.api);
  final MockApi api;
  @override Future<BookingEntity> create(BookingEntity booking) => api.createBooking(booking);
  @override Future<List<BookingEntity>> forUser(String userId) => api.bookings(userId);
}
