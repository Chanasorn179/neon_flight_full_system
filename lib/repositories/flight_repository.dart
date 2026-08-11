import '../data/mock_api.dart';
import '../models/entities.dart';

abstract class FlightRepository {
  Future<List<AirportEntity>> airports();
  Future<List<FlightEntity>> search(String from, String to, DateTime date);
  List<PromotionEntity> promotions();
}

class MockFlightRepository implements FlightRepository {
  MockFlightRepository(this.api);
  final MockApi api;
  @override Future<List<AirportEntity>> airports() async => api.airports;
  @override Future<List<FlightEntity>> search(String from, String to, DateTime date) => api.searchFlights(from, to, date);
  @override List<PromotionEntity> promotions() => api.promotions;
}
