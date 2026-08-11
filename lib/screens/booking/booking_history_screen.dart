import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../models/entities.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/app_widgets.dart';
import 'ticket_screen.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  BookingStatus selected = BookingStatus.upcoming;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) context.read<BookingProvider>().load(user.id);
    });
  }

  Future<void> _refresh() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) await context.read<BookingProvider>().load(user.id);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final provider = context.watch<BookingProvider>();
    final userId = context.watch<AuthProvider>().currentUser?.id;
    final flightItems = provider.bookings
        .where((booking) => booking.status == selected)
        .toList();
    final transferItems = provider.transferBookings
        .where(
          (booking) => booking.userId == userId && booking.status == selected,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'my_bookings'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<BookingStatus>(
              segments: [
                ButtonSegment(
                  value: BookingStatus.upcoming,
                  label: Text(tr(lang, 'upcoming')),
                ),
                ButtonSegment(
                  value: BookingStatus.completed,
                  label: Text(tr(lang, 'completed')),
                ),
                ButtonSegment(
                  value: BookingStatus.cancelled,
                  label: Text(tr(lang, 'cancelled')),
                ),
              ],
              selected: {selected},
              onSelectionChanged: (v) => setState(() => selected = v.first),
              showSelectedIcon: false,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: provider.loading
                  ? const Center(child: CircularProgressIndicator())
                  : flightItems.isEmpty && transferItems.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 160),
                        EmptyState(
                          icon: Icons.event_note_outlined,
                          title: tr(lang, 'no_booking'),
                          subtitle: tr(lang, 'no_booking_sub'),
                        ),
                      ],
                    )
                  : _BookingList(
                      flightBookings: flightItems,
                      transferBookings: transferItems,
                      languageCode: lang,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({
    required this.flightBookings,
    required this.transferBookings,
    required this.languageCode,
  });

  final List<BookingEntity> flightBookings;
  final List<TransferBookingEntity> transferBookings;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('booking-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (transferBookings.isNotEmpty) ...[
          SectionTitle(
            tr(languageCode, 'transfer_bookings'),
            icon: Icons.airport_shuttle_rounded,
          ),
          const SizedBox(height: 12),
          for (final booking in transferBookings) ...[
            _TransferBookingCard(booking: booking, languageCode: languageCode),
            const SizedBox(height: 12),
          ],
        ],
        if (flightBookings.isNotEmpty) ...[
          if (transferBookings.isNotEmpty) const SizedBox(height: 4),
          SectionTitle(
            tr(languageCode, 'flight_bookings'),
            icon: Icons.flight_takeoff_rounded,
          ),
          const SizedBox(height: 12),
          for (final booking in flightBookings) ...[
            _FlightBookingCard(booking: booking, languageCode: languageCode),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _FlightBookingCard extends StatelessWidget {
  const _FlightBookingCard({required this.booking, required this.languageCode});

  final BookingEntity booking;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('booking-card-${booking.id}'),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(child: Icon(Icons.flight)),
        title: Text(
          '${booking.flight.departure.code} → ${booking.flight.arrival.code}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${dateOf(booking.flight.departureTime)}\nBooking ID: ${booking.id}',
        ),
        isThreeLine: true,
        trailing: FilledButton.tonal(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TicketScreen(booking: booking)),
          ),
          child: Text(tr(languageCode, 'view_ticket')),
        ),
      ),
    );
  }
}

class _TransferBookingCard extends StatelessWidget {
  const _TransferBookingCard({
    required this.booking,
    required this.languageCode,
  });

  final TransferBookingEntity booking;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final airport = languageCode == 'th'
        ? booking.airportNameTh
        : booking.airportNameEn;
    final pickupLocation = booking.pickupLocation;
    final gpsLocation =
        '${pickupLocation.latitude.toStringAsFixed(6)}, '
        '${pickupLocation.longitude.toStringAsFixed(6)} · '
        '${tr(languageCode, 'gps_accuracy')} '
        '±${pickupLocation.accuracyMeters.round()} m';

    return Card(
      key: ValueKey('transfer-booking-${booking.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.airport_shuttle_rounded,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tr(languageCode, 'airport_transfer')} · '
                        '${booking.airportCode}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(airport, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(tr(languageCode, _statusKey(booking.status))),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TransferBookingDetail(
              icon: Icons.my_location_rounded,
              text: '${tr(languageCode, 'gps_current_location')}: $gpsLocation',
            ),
            const SizedBox(height: 8),
            _TransferBookingDetail(
              icon: Icons.radar_rounded,
              text:
                  '${tr(languageCode, 'gps_distance_from_airport')}: '
                  '${booking.distanceToAirportKm.toStringAsFixed(1)} km · '
                  '${tr(languageCode, 'gps_within_service_area')}',
            ),
            const SizedBox(height: 8),
            _TransferBookingDetail(
              icon: Icons.schedule_rounded,
              text:
                  '${tr(languageCode, 'transfer_pickup_time')}: '
                  '${dateOf(booking.pickupTime)} · '
                  '${timeOf(booking.pickupTime)}',
            ),
            const SizedBox(height: 8),
            _TransferBookingDetail(
              icon: Icons.flight_takeoff_rounded,
              text:
                  '${tr(languageCode, 'transfer_flight_departure')}: '
                  '${dateOf(booking.flightDepartureTime)} · '
                  '${timeOf(booking.flightDepartureTime)}',
            ),
            const SizedBox(height: 10),
            Text(
              'Booking ID: ${booking.id}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferBookingDetail extends StatelessWidget {
  const _TransferBookingDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

String _statusKey(BookingStatus status) => switch (status) {
  BookingStatus.upcoming => 'upcoming',
  BookingStatus.completed => 'completed',
  BookingStatus.cancelled => 'cancelled',
};
