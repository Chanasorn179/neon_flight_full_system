import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notice.dart';
import '../models/entities.dart';
import '../repositories/booking_repository.dart';

class BookingProvider extends ChangeNotifier {
  BookingProvider(this.repository);
  final BookingRepository repository;
  List<BookingEntity> bookings = [];

  StreamSubscription<List<BookingEntity>>? _watch;
  String? _watchedUser;

  /// Notice ids the user has already seen (persisted on the device).
  Set<String> seenNotices = {};
  bool _seenLoaded = false;
  static const _seenKey = 'seen_notices';

  List<AppNotice> get notices => AppNotice.fromBookings(bookings, DateTime.now());

  int get unseenCount => notices.where((n) => !seenNotices.contains(n.id)).length;

  Future<void> _loadSeen() async {
    if (_seenLoaded) return;
    _seenLoaded = true;
    try {
      seenNotices = (await SharedPreferencesAsync().getStringList(_seenKey) ?? []).toSet();
      notifyListeners();
    } catch (_) {
      // No local storage (e.g. tests): everything starts unseen.
    }
  }

  Future<void> markNoticesSeen() async {
    seenNotices = {...seenNotices, ...notices.map((n) => n.id)};
    notifyListeners();
    try {
      await SharedPreferencesAsync().setStringList(_seenKey, seenNotices.toList());
    } catch (_) {}
  }

  /// Keeps [bookings] in sync with the server so payment confirmations show
  /// up live (ticket QR, history, notification bell).
  void _watchUser(String userId) {
    if (_watchedUser == userId) return;
    _watch?.cancel();
    _watchedUser = userId;
    _watch = repository.watch(userId).listen((fresh) {
      bookings = fresh..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }
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

  /// The booking plus its round-trip partner, if any.
  List<BookingEntity> tripOf(BookingEntity booking) => booking.tripId == null
      ? [booking]
      : [
          for (final b in bookings)
            if (b.tripId == booking.tripId) b,
          if (!bookings.any((b) => b.id == booking.id)) booking,
        ];

  /// Cancels an unpaid booking (both legs of a round trip) and frees seats.
  Future<void> cancel(BookingEntity booking) async {
    final trip = tripOf(booking).where((b) => b.canCancel).toList();
    if (trip.isEmpty) return;
    await repository.cancel(trip);
    final ids = {for (final b in trip) b.id};
    bookings = [
      for (final b in bookings)
        ids.contains(b.id) ? b.withStatus(BookingStatus.cancelled) : b,
    ];
    notifyListeners();
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
      _watchUser(userId);
      await _loadSeen();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
