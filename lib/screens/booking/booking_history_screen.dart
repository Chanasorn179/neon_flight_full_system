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
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) context.read<BookingProvider>().load(user.id);
  }

  Future<void> _refresh() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) await context.read<BookingProvider>().load(user.id);
  }

  void _openTicket(BookingEntity booking) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TicketScreen(booking: booking)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final provider = context.watch<BookingProvider>();
    final items =
        provider.bookings
            .where((booking) => booking.status == selected)
            .toList()
          ..sort(
            (a, b) => b.flight.departureTime.compareTo(a.flight.departureTime),
          );
    final counts = {
      for (final status in BookingStatus.values)
        status: provider.bookings
            .where((booking) => booking.status == status)
            .length,
    };

    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'my_bookings'))),
      body: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _BookingStatusTabs(
                selected: selected,
                counts: counts,
                lang: lang,
                onSelected: (status) => setState(() => selected = status),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: provider.loading && provider.bookings.isEmpty
                  ? const _BookingHistoryLoading()
                  : items.isEmpty
                  ? _EmptyBookingHistory(status: selected, lang: lang)
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: _BookingCard(
                            key: ValueKey('booking-card-${items[index].id}'),
                            booking: items[index],
                            lang: lang,
                            onOpen: () => _openTicket(items[index]),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingStatusTabs extends StatelessWidget {
  const _BookingStatusTabs({
    required this.selected,
    required this.counts,
    required this.lang,
    required this.onSelected,
  });

  final BookingStatus selected;
  final Map<BookingStatus, int> counts;
  final String lang;
  final ValueChanged<BookingStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          for (final status in BookingStatus.values) ...[
            ChoiceChip(
              key: ValueKey('booking-tab-${status.name}'),
              selected: selected == status,
              showCheckmark: false,
              avatar: Icon(_statusIcon(status), size: 18),
              label: Text(
                '${_statusLabel(lang, status)} (${counts[status] ?? 0})',
              ),
              onSelected: (_) => onSelected(status),
            ),
            if (status != BookingStatus.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _BookingHistoryLoading extends StatelessWidget {
  const _BookingHistoryLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(
          height: 260,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _EmptyBookingHistory extends StatelessWidget {
  const _EmptyBookingHistory({required this.status, required this.lang});

  final BookingStatus status;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        EmptyState(
          icon: _statusIcon(status),
          title: tr(lang, 'no_booking'),
          subtitle: tr(lang, 'no_booking_sub'),
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    super.key,
    required this.booking,
    required this.lang,
    required this.onOpen,
  });

  final BookingEntity booking;
  final String lang;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme.colorScheme, booking.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.flight_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.flight.airline,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          booking.flight.flightNumber,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _statusIcon(booking.status),
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _statusLabel(lang, booking.status),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _RouteSummary(booking: booking, lang: lang),
              const Divider(height: 30),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 560 ? 3 : 2;
                  final gap = 10.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: 14,
                    children: [
                      _BookingFact(
                        width: width,
                        icon: Icons.event_outlined,
                        label: tr(lang, 'date'),
                        value: dateOf(booking.flight.departureTime),
                      ),
                      _BookingFact(
                        width: width,
                        icon: Icons.airline_seat_recline_normal,
                        label: tr(lang, 'seat'),
                        value: booking.seats.isEmpty
                            ? '-'
                            : booking.seats.join(', '),
                      ),
                      _BookingFact(
                        width: width,
                        icon: Icons.people_outline,
                        label: tr(lang, 'passenger'),
                        value: '${booking.passengers.length}',
                      ),
                      _BookingFact(
                        width: width,
                        icon: Icons.workspace_premium_outlined,
                        label: tr(lang, 'class'),
                        value: _cabin(lang, booking.cabinClass),
                      ),
                      _BookingFact(
                        width: width,
                        icon: Icons.payments_outlined,
                        label: tr(lang, 'total'),
                        value: money(booking.fare.total),
                      ),
                    ],
                  );
                },
              ),
              const Divider(height: 30),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking ID',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          booking.id,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.confirmation_number_outlined),
                    label: Text(tr(lang, 'view_ticket')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.booking, required this.lang});

  final BookingEntity booking;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flight = booking.flight;
    final duration = flight.duration;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: _AirportTime(
            code: flight.departure.code,
            city: cityName(
              lang,
              flight.departure.code,
              cityTh: flight.departure.cityTh,
              cityEn: flight.departure.cityEn,
            ),
            time: timeOf(flight.departureTime),
            alignment: CrossAxisAlignment.start,
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Text(
                  _durationText(lang, duration),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: theme.colorScheme.outlineVariant),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Icon(
                        Icons.flight_takeoff_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: Divider(color: theme.colorScheme.outlineVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  tr(lang, 'direct'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: _AirportTime(
            code: flight.arrival.code,
            city: cityName(
              lang,
              flight.arrival.code,
              cityTh: flight.arrival.cityTh,
              cityEn: flight.arrival.cityEn,
            ),
            time: timeOf(flight.arrivalTime),
            alignment: CrossAxisAlignment.end,
          ),
        ),
      ],
    );
  }
}

class _AirportTime extends StatelessWidget {
  const _AirportTime({
    required this.code,
    required this.city,
    required this.time,
    required this.alignment,
  });

  final String code;
  final String city;
  final String time;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textAlign = alignment == CrossAxisAlignment.end
        ? TextAlign.right
        : TextAlign.left;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          code,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          time,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _BookingFact extends StatelessWidget {
  const _BookingFact({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String lang, BookingStatus status) => switch (status) {
  BookingStatus.upcoming => tr(lang, 'upcoming'),
  BookingStatus.completed => tr(lang, 'completed'),
  BookingStatus.cancelled => tr(lang, 'cancelled'),
};

IconData _statusIcon(BookingStatus status) => switch (status) {
  BookingStatus.upcoming => Icons.flight_takeoff_rounded,
  BookingStatus.completed => Icons.task_alt_rounded,
  BookingStatus.cancelled => Icons.cancel_outlined,
};

Color _statusColor(ColorScheme colors, BookingStatus status) =>
    switch (status) {
      BookingStatus.upcoming => colors.primary,
      BookingStatus.completed => colors.tertiary,
      BookingStatus.cancelled => colors.error,
    };

String _durationText(String lang, Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes ${tr(lang, 'minutes')}';
  if (minutes == 0) return '$hours ${tr(lang, 'hours')}';
  return '$hours ${tr(lang, 'hours')} $minutes ${tr(lang, 'minutes')}';
}

String _cabin(String lang, CabinClass cabin) => switch (cabin) {
  CabinClass.economy => tr(lang, 'economy'),
  CabinClass.premiumEconomy => tr(lang, 'premium_economy'),
  CabinClass.business => tr(lang, 'business'),
  CabinClass.first => tr(lang, 'first'),
};
