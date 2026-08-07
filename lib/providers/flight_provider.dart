import 'package:flutter/foundation.dart';
import '../models/entities.dart';
import '../repositories/flight_repository.dart';

class FlightProvider extends ChangeNotifier {
  FlightProvider(this.repository) {
    loadAirports();
  }
  final FlightRepository repository;
  List<AirportEntity> airports = [];
  List<FlightEntity> results = [];
  bool loading = false;
  String? error;
  String from = 'BKK';
  String to = 'NRT';
  DateTime departureDate = DateTime.now().add(const Duration(days: 14));
  DateTime? returnDate;
  TripType tripType = TripType.oneWay;
  CabinClass cabinClass = CabinClass.economy;
  int adults = 1;
  int children = 0;
  double maxPrice = 50000;
  String sort = 'cheapest';

  List<PromotionEntity> get promotions => repository.promotions();
  int get passengerCount => adults + children;

  Future<void> loadAirports() async { airports = await repository.airports(); notifyListeners(); }
  void setRoute(String f, String t) { from = f; to = t; notifyListeners(); }
  void swapRoute() { final v = from; from = to; to = v; notifyListeners(); }
  void setDeparture(DateTime value) { departureDate = value; notifyListeners(); }
  void setReturn(DateTime? value) { returnDate = value; notifyListeners(); }
  void setTripType(TripType value) { tripType = value; if (value == TripType.oneWay) returnDate = null; notifyListeners(); }
  void setCabin(CabinClass value) { cabinClass = value; notifyListeners(); }
  void setPassengers(int a, int c) { adults = a; children = c; notifyListeners(); }
  void setMaxPrice(double value) { maxPrice = value; notifyListeners(); }
  void setSort(String value) { sort = value; notifyListeners(); }

  Future<void> search() async {
    loading = true; error = null; notifyListeners();
    try {
      final raw = await repository.search(from, to, departureDate);
      results = raw.where((f) => f.price(cabinClass) <= maxPrice).toList();
      if (sort == 'cheapest') results.sort((a, b) => a.price(cabinClass).compareTo(b.price(cabinClass)));
      if (sort == 'earliest') results.sort((a, b) => a.departureTime.compareTo(b.departureTime));
      if (sort == 'fastest') results.sort((a, b) => a.duration.compareTo(b.duration));
    } catch (e) { error = e.toString(); results = []; }
    finally { loading = false; notifyListeners(); }
  }
}
