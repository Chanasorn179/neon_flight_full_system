import 'travel_models.dart';

enum NoticeKind { departingSoon, paymentPending, paid, cancelled }

/// An in-app notification derived from the user's bookings.
class AppNotice {
  const AppNotice({required this.kind, required this.booking, required this.time});

  final NoticeKind kind;
  final BookingEntity booking;

  /// When it became relevant; used for ordering.
  final DateTime time;

  /// Stable per booking and kind, so "seen" survives restarts.
  String get id => '${booking.id}_${kind.name}';

  /// Notices for [bookings] at [now], most urgent first.
  static List<AppNotice> fromBookings(List<BookingEntity> bookings, DateTime now) {
    final notices = <AppNotice>[];
    for (final b in bookings) {
      // A round trip is paid or cancelled as one: one notice for the trip.
      final isReturnLeg = b.tripId != null && b.id != b.tripId;
      final departure = b.flight.departureTime;

      if (b.status == BookingStatus.cancelled) {
        if (!isReturnLeg) {
          notices.add(AppNotice(kind: NoticeKind.cancelled, booking: b, time: b.createdAt));
        }
        continue;
      }
      if (departure.isBefore(now)) continue;

      if (!b.isPaid) {
        if (!isReturnLeg) {
          notices.add(AppNotice(kind: NoticeKind.paymentPending, booking: b, time: b.createdAt));
        }
        continue;
      }
      if (!isReturnLeg) {
        notices.add(AppNotice(kind: NoticeKind.paid, booking: b, time: b.createdAt));
      }
      final soon = departure.subtract(const Duration(hours: 48));
      if (now.isAfter(soon)) {
        notices.add(AppNotice(kind: NoticeKind.departingSoon, booking: b, time: soon));
      }
    }
    notices.sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      return byKind != 0 ? byKind : b.time.compareTo(a.time);
    });
    return notices;
  }
}
