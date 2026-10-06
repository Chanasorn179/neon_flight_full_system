import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/app_localizations.dart';
import '../../models/entities.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/airline_logo.dart';
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
      if (user != null) {
        context.read<BookingProvider>().load(user.id);
      }
    });
  }

  Future<void> _refresh() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      await context.read<BookingProvider>().load(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = context.watch<LanguageProvider>().languageCode;
    final provider = context.watch<BookingProvider>();
    final userId = context.watch<AuthProvider>().currentUser?.id;

    // ใช้สถานะที่คำนวณจากเวลาแทนการพึ่ง booking.status เพียงอย่างเดียว
    // เพื่อให้รายการย้ายจาก "กำลังจะเดินทาง" ไป "เสร็จสิ้น" อัตโนมัติ
    // แม้ข้อมูลเดิมในหน่วยความจำจะยังเป็น BookingStatus.upcoming อยู่
    final flightItems = provider.bookings
        .where((booking) => _effectiveFlightStatus(booking) == selected)
        .toList()
      ..sort(
        (first, second) => second.flight.departureTime.compareTo(
          first.flight.departureTime,
        ),
      );

    final transferItems = provider.transferBookings
        .where(
          (booking) =>
              booking.userId == userId &&
              _effectiveTransferStatus(booking) == selected,
        )
        .toList()
      ..sort((first, second) => second.pickupTime.compareTo(first.pickupTime));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          tr(lang, 'my_bookings'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.heroGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: .18),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.confirmation_number_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(lang, 'my_bookings'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${flightItems.length} ${tr(lang, 'flight_bookings')} · '
                              '${transferItems.length} ${tr(lang, 'transfer_bookings')}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<BookingStatus>(
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
                  onSelectionChanged: (value) {
                    setState(() {
                      selected = value.first;
                    });
                  },
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: provider.loading
                  ? const Center(child: CircularProgressIndicator())
                  : (flightItems.isEmpty && transferItems.isEmpty)
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 60, 16, 120),
                      children: [
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
      children: [
        if (transferBookings.isNotEmpty) ...[
          SectionTitle(
            tr(languageCode, 'transfer_bookings'),
            icon: Icons.airport_shuttle_rounded,
          ),
          const SizedBox(height: 12),
          for (final booking in transferBookings) ...[
            _TransferBookingCard(booking: booking, languageCode: languageCode),
            const SizedBox(height: 14),
          ],
        ],
        if (flightBookings.isNotEmpty) ...[
          if (transferBookings.isNotEmpty) const SizedBox(height: 6),
          SectionTitle(
            tr(languageCode, 'flight_bookings'),
            icon: Icons.flight_takeoff_rounded,
          ),
          const SizedBox(height: 12),
          for (final booking in flightBookings) ...[
            _FlightBookingCard(booking: booking, languageCode: languageCode),
            const SizedBox(height: 14),
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
    final theme = Theme.of(context);
    final duration = booking.flight.duration;
    final durationText = '${duration.inHours}${tr(languageCode, 'hours')} '
        '${duration.inMinutes.remainder(60)} ${tr(languageCode, 'minutes')}';

    return Container(
      key: ValueKey('booking-card-${booking.id}'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: AirlineLogo(
                    airlineName: booking.flight.airline,
                    flightNumber: booking.flight.flightNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${booking.flight.departure.code} → ${booking.flight.arrival.code}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${booking.flight.airline} · ${booking.flight.flightNumber}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!booking.isPaid &&
                    booking.status != BookingStatus.cancelled)
                  _StatusChip(
                    label: tr(languageCode, 'payment_pending_short'),
                    color: AppTheme.pendingForeground(theme.brightness),
                    icon: Icons.hourglass_top_rounded,
                  )
                else
                  _StatusChip(
                    label: tr(
                      languageCode,
                      _statusKey(_effectiveFlightStatus(booking)),
                    ),
                    color: _statusColor(
                      context,
                      _effectiveFlightStatus(booking),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimeBlock(
                    code: booking.flight.departure.code,
                    city: languageCode == 'th'
                        ? booking.flight.departure.cityTh
                        : booking.flight.departure.cityEn,
                    time: timeOf(booking.flight.departureTime),
                    date: dateOf(booking.flight.departureTime),
                    alignEnd: false,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Icon(
                        Icons.flight_takeoff_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 6),
                      Text(durationText, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Expanded(
                  child: _TimeBlock(
                    code: booking.flight.arrival.code,
                    city: languageCode == 'th'
                        ? booking.flight.arrival.cityTh
                        : booking.flight.arrival.cityEn,
                    time: timeOf(booking.flight.arrivalTime),
                    date: dateOf(booking.flight.arrivalTime),
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _FlightMeta(
                      label: tr(languageCode, 'class'),
                      value: _cabin(languageCode, booking.cabinClass),
                    ),
                  ),
                  Expanded(
                    child: _FlightMeta(
                      label: tr(languageCode, 'seat'),
                      value: booking.seats.isEmpty ? '-' : booking.seats.join(', '),
                    ),
                  ),
                  Expanded(
                    child: _FlightMeta(
                      label: 'Booking ID',
                      value: booking.id,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TicketScreen(booking: booking)),
                  );
                },
                icon: const Icon(Icons.confirmation_number_outlined),
                label: Text(tr(languageCode, 'view_ticket')),
              ),
            ),
          ],
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
    final airport = languageCode == 'th' ? booking.airportNameTh : booking.airportNameEn;
    final pickupLocation = booking.pickupLocation;
    final gpsLocation = '${pickupLocation.latitude.toStringAsFixed(6)}, '
        '${pickupLocation.longitude.toStringAsFixed(6)} · '
        '${tr(languageCode, 'gps_accuracy')} ±${pickupLocation.accuracyMeters.round()} m';
    final phase = _transferPhaseFor(booking);
    final progress = _transferPhaseProgress(phase);

    return Container(
      key: ValueKey('transfer-booking-${booking.id}'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: .75),
                    borderRadius: BorderRadius.circular(18),
                  ),
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
                        '${tr(languageCode, 'airport_transfer')} · ${booking.airportCode}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(airport, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                _StatusChip(
                  label: _transferPhaseTitle(languageCode, phase),
                  color: _transferPhaseColor(context, phase),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: .08),
                    theme.colorScheme.secondary.withValues(alpha: .08),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timeline_rounded,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _transferPhaseTitle(languageCode, phase),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: progress,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: .12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ProgressStep(
                          title: _transferStepLabel(languageCode, 0),
                          active: progress >= 0.25,
                        ),
                      ),
                      Expanded(
                        child: _ProgressStep(
                          title: _transferStepLabel(languageCode, 1),
                          active: progress >= 0.50,
                        ),
                      ),
                      Expanded(
                        child: _ProgressStep(
                          title: _transferStepLabel(languageCode, 2),
                          active: progress >= 0.75,
                        ),
                      ),
                      Expanded(
                        child: _ProgressStep(
                          title: _transferStepLabel(languageCode, 3),
                          active: progress >= 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _TransferBookingDetail(
              icon: Icons.my_location_rounded,
              text: '${tr(languageCode, 'gps_current_location')}: $gpsLocation',
            ),
            const SizedBox(height: 8),
            _TransferBookingDetail(
              icon: Icons.radar_rounded,
              text: '${tr(languageCode, 'gps_distance_from_airport')}: '
                  '${booking.distanceToAirportKm.toStringAsFixed(1)} km',
            ),
            const SizedBox(height: 8),
            _TransferBookingDetail(
              icon: Icons.schedule_rounded,
              text: '${tr(languageCode, 'transfer_pickup_time')}: '
                  '${dateOf(booking.pickupTime)} · ${timeOf(booking.pickupTime)}',
            ),
            const SizedBox(height: 8),
            _TransferBookingDetail(
              icon: Icons.flight_takeoff_rounded,
              text: '${tr(languageCode, 'transfer_flight_departure')}: '
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

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.title, required this.active});

  final String title;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: active ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.code,
    required this.city,
    required this.time,
    required this.date,
    required this.alignEnd,
  });

  final String code;
  final String city;
  final String time;
  final String date;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(code, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(city, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Text(time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(date, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _FlightMeta extends StatelessWidget {
  const _FlightMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

Color _statusColor(BuildContext context, BookingStatus status) {
  return switch (status) {
    BookingStatus.upcoming => Theme.of(context).colorScheme.primary,
    BookingStatus.completed => Colors.green,
    BookingStatus.cancelled => Theme.of(context).colorScheme.error,
  };
}

String _statusKey(BookingStatus status) => switch (status) {
  BookingStatus.upcoming => 'upcoming',
  BookingStatus.completed => 'completed',
  BookingStatus.cancelled => 'cancelled',
};

BookingStatus _effectiveFlightStatus(BookingEntity booking) {
  if (booking.status == BookingStatus.cancelled) {
    return BookingStatus.cancelled;
  }

  if (booking.status == BookingStatus.completed) {
    return BookingStatus.completed;
  }

  // เที่ยวบินจะถือว่าเสร็จสิ้นเมื่อเลยเวลาเครื่องถึงแล้ว
  if (!DateTime.now().isBefore(booking.flight.arrivalTime)) {
    return BookingStatus.completed;
  }

  return BookingStatus.upcoming;
}

BookingStatus _effectiveTransferStatus(TransferBookingEntity booking) {
  if (booking.status == BookingStatus.cancelled) {
    return BookingStatus.cancelled;
  }

  if (booking.status == BookingStatus.completed) {
    return BookingStatus.completed;
  }

  // ในข้อมูล Transfer ปัจจุบันยังไม่มีเวลาถึงสนามบินจริง
  // จึงใช้เวลาเที่ยวบินเป็นเส้นตายสูงสุดของงานรับส่ง
  // เมื่อเลยเวลาเที่ยวบิน รายการจะย้ายไปแท็บ "เสร็จสิ้น" อัตโนมัติ
  if (!DateTime.now().isBefore(booking.flightDepartureTime)) {
    return BookingStatus.completed;
  }

  return BookingStatus.upcoming;
}

_TransferPhase _transferPhaseFor(TransferBookingEntity booking) {
  final effectiveStatus = _effectiveTransferStatus(booking);

  if (effectiveStatus == BookingStatus.cancelled) {
    return _TransferPhase.cancelled;
  }
  if (effectiveStatus == BookingStatus.completed) {
    return _TransferPhase.arrived;
  }

  final now = DateTime.now();
  final pickup = booking.pickupTime;
  final departure = booking.flightDepartureTime;

  if (now.isBefore(pickup.subtract(const Duration(minutes: 30)))) {
    return _TransferPhase.scheduled;
  }
  if (now.isBefore(pickup.add(const Duration(minutes: 15)))) {
    return _TransferPhase.driverOnWay;
  }
  if (now.isBefore(departure)) {
    return _TransferPhase.onTheWay;
  }
  return _TransferPhase.arrived;
}

double _transferPhaseProgress(_TransferPhase phase) {
  return switch (phase) {
    _TransferPhase.scheduled => .25,
    _TransferPhase.driverOnWay => .50,
    _TransferPhase.onTheWay => .75,
    _TransferPhase.arrived => 1,
    _TransferPhase.cancelled => .25,
  };
}

Color _transferPhaseColor(
  BuildContext context,
  _TransferPhase phase,
) {
  return switch (phase) {
    _TransferPhase.scheduled => Theme.of(context).colorScheme.primary,
    _TransferPhase.driverOnWay => Colors.orange,
    _TransferPhase.onTheWay => Colors.blue,
    _TransferPhase.arrived => Colors.green,
    _TransferPhase.cancelled => Theme.of(context).colorScheme.error,
  };
}

String _transferPhaseTitle(String lang, _TransferPhase phase) {
  if (lang == 'th') {
    return switch (phase) {
      _TransferPhase.scheduled => 'จองรถเรียบร้อย',
      _TransferPhase.driverOnWay => 'คนขับกำลังไปรับ',
      _TransferPhase.onTheWay => 'กำลังเดินทางไปสนามบิน',
      _TransferPhase.arrived => 'ถึงสนามบินแล้ว',
      _TransferPhase.cancelled => 'ยกเลิกรายการรับส่ง',
    };
  }
  return switch (phase) {
    _TransferPhase.scheduled => 'Transfer scheduled',
    _TransferPhase.driverOnWay => 'Driver is on the way',
    _TransferPhase.onTheWay => 'On the way to the airport',
    _TransferPhase.arrived => 'Arrived at the airport',
    _TransferPhase.cancelled => 'Transfer cancelled',
  };
}

String _transferStepLabel(String lang, int step) {
  if (lang == 'th') {
    return switch (step) {
      0 => 'จองแล้ว',
      1 => 'ไปรับ',
      2 => 'เดินทาง',
      _ => 'ถึงแล้ว',
    };
  }
  return switch (step) {
    0 => 'Booked',
    1 => 'Pickup',
    2 => 'On route',
    _ => 'Arrived',
  };
}

String _cabin(String lang, CabinClass c) => switch (c) {
  CabinClass.economy => tr(lang, 'economy'),
  CabinClass.premiumEconomy => tr(lang, 'premium_economy'),
  CabinClass.business => tr(lang, 'business'),
  CabinClass.first => tr(lang, 'first'),
};

enum _TransferPhase { scheduled, driverOnWay, onTheWay, arrived, cancelled }
