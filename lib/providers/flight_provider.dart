import 'package:flutter/foundation.dart';
import '../models/travel_models.dart';
import '../repositories/flight_repository.dart';

class FlightProvider extends ChangeNotifier {
  FlightProvider(this.repository) {
    loadAirports();
  }
  final FlightRepository repository;
  List<AirportEntity> airports = [];
  List<FlightEntity> results = [];

  /// Return-leg options when [isRoundTrip]; same filters as [results].
  List<FlightEntity> returnResults = [];
  bool loading = false;
  String? error;
  String from = 'BKK';
  String to = 'CNX';
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
  void setDeparture(DateTime value) {
    departureDate = value;
    // Keep the return date on or after departure.
    if (returnDate != null && returnDate!.isBefore(value)) returnDate = value;
    notifyListeners();
  }
  void setReturn(DateTime? value) { returnDate = value; notifyListeners(); }
  void setTripType(TripType value) {
    tripType = value;
    if (value == TripType.oneWay) returnDate = null;
    // Sensible default so a round-trip search works without extra taps.
    if (value == TripType.roundTrip) {
      returnDate ??= departureDate.add(const Duration(days: 3));
    }
    notifyListeners();
  }
  void setCabin(CabinClass value) { cabinClass = value; notifyListeners(); }
  /// Airlines cap a single booking at 9 passengers; the seat-lock rules rely on it.
  static const maxPassengers = 9;
  void setPassengers(int a, int c) {
    if (a < 1 || c < 0 || a + c > maxPassengers) return;
    adults = a; children = c; notifyListeners();
  }
  void setMaxPrice(double value) { maxPrice = value; notifyListeners(); }
  void setSort(String value) { sort = value; notifyListeners(); }

  bool get isRoundTrip => tripType == TripType.roundTrip && returnDate != null;

  List<FlightEntity> _filterSort(List<FlightEntity> raw) {
    final list = raw.where((f) => f.price(cabinClass) <= maxPrice).toList();
    if (sort == 'cheapest') list.sort((a, b) => a.price(cabinClass).compareTo(b.price(cabinClass)));
    if (sort == 'earliest') list.sort((a, b) => a.departureTime.compareTo(b.departureTime));
    if (sort == 'fastest') list.sort((a, b) => a.duration.compareTo(b.duration));
    return list;
  }

  /// Return flights that leave after [outbound] lands.
  List<FlightEntity> returnOptionsAfter(FlightEntity outbound) => returnResults
      .where((f) => f.departureTime.isAfter(outbound.arrivalTime))
      .toList();

  Future<void> search() async {
    loading = true; error = null; notifyListeners();
    try {
      results = _filterSort(await repository.search(from, to, departureDate));
      returnResults = isRoundTrip
          ? _filterSort(await repository.search(to, from, returnDate!))
          : [];
    } catch (e) { error = e.toString(); results = []; returnResults = []; }
    finally { loading = false; notifyListeners(); }
  }
}
