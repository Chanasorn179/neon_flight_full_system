import '../data/mock_api.dart';
import '../models/entities.dart';
import '../services/aviation_api_service.dart';

abstract class FlightRepository {
  Future<List<AirportEntity>> airports();
  Future<List<FlightEntity>> search(String from, String to, DateTime date);
  List<PromotionEntity> promotions();
}

class HybridFlightRepository implements FlightRepository {
  HybridFlightRepository(this.api) : aviation = AviationApiService(api);

  final MockApi api;
  final AviationApiService aviation;

  @override
  Future<List<AirportEntity>> airports() async => api.airports;

  @override
  Future<List<FlightEntity>> search(
    String from,
    String to,
    DateTime date,
  ) =>
      aviation.search(from, to, date);

  @override
  List<PromotionEntity> promotions() => api.promotions;
}

class MockFlightRepository extends HybridFlightRepository {
  MockFlightRepository(super.api);
}
