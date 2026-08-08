import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../models/entities.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/flight_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/app_widgets.dart';
import '../flights/flight_results_screen.dart';
import 'airport_transfer_section.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _pickDate(BuildContext context, FlightProvider provider) async {
    final date = await showDatePicker(
      context: context,
      initialDate: provider.departureDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) provider.setDeparture(date);
  }

  Future<void> _search(BuildContext context) async {
    final provider = context.read<FlightProvider>();
    await provider.search();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FlightResultsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FlightProvider>();
    final bookingProvider = context.watch<BookingProvider>();
    final bookings = bookingProvider.bookings;
    final user = context.watch<AuthProvider>().currentUser;
    final lang = context.watch<LanguageProvider>().languageCode;
    final upcomingBookings =
        bookings
            .where((booking) => booking.status == BookingStatus.upcoming)
            .toList()
          ..sort(
            (first, second) => first.flight.departureTime.compareTo(
              second.flight.departureTime,
            ),
          );
    final outboundFlight = upcomingBookings.isEmpty
        ? null
        : upcomingBookings.first.flight;
    final transferReservation = outboundFlight == null || user == null
        ? null
        : bookingProvider.transferBookingFor(
            userId: user.id,
            airportCode: outboundFlight.departure.code,
            flightDepartureTime: outboundFlight.departureTime,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NEON FLIGHT',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: tr(lang, 'notifications'),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr(lang, 'no_notifications'))),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.loadAirports,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            Text(
              '${tr(lang, 'hello')} ${user?.name ?? ''} 👋',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(tr(lang, 'where_today')),
            const SizedBox(height: 20),
            _SearchCard(
              provider: provider,
              lang: lang,
              onPickDate: () => _pickDate(context, provider),
              onSearch: () => _search(context),
            ),
            const SizedBox(height: 28),
            SectionTitle(
              tr(lang, 'special_deals'),
              icon: Icons.local_fire_department_rounded,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: provider.promotions.isEmpty
                  ? Center(child: Text(tr(lang, 'no_deals')))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.promotions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final promo = provider.promotions[index];
                        return _PromoCard(
                          promo: promo,
                          lang: lang,
                          onSelect: () async {
                            provider.setRoute(promo.from, promo.to);
                            provider.setCabin(promo.cabinClass);
                            await _search(context);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 28),
            AirportTransferSection(
              languageCode: lang,
              departureAirportCode:
                  outboundFlight?.departure.code ?? provider.from,
              flightDepartureTime: outboundFlight?.departureTime,
              userId: user?.id ?? 'guest',
              initialReservation: transferReservation,
              onBooked: bookingProvider.addTransferBooking,
            ),
            const SizedBox(height: 28),
            SectionTitle(tr(lang, 'popular_destinations'), icon: Icons.public),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final airport in provider.airports.where(
                  (a) => a.code != 'BKK',
                ))
                  ActionChip(
                    avatar: const Icon(Icons.location_on_outlined, size: 18),
                    label: Text(
                      '${cityName(lang, airport.code, cityTh: airport.cityTh, cityEn: airport.cityEn)} (${airport.code})',
                    ),
                    onPressed: () async {
                      provider.setRoute('BKK', airport.code);
                      await _search(context);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.provider,
    required this.lang,
    required this.onPickDate,
    required this.onSearch,
  });

  final FlightProvider provider;
  final String lang;
  final VoidCallback onPickDate;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TripType>(
                segments: [
                  ButtonSegment(
                    value: TripType.oneWay,
                    label: Text(tr(lang, 'one_way')),
                  ),
                  ButtonSegment(
                    value: TripType.roundTrip,
                    label: Text(tr(lang, 'round_trip')),
                  ),
                ],
                selected: {provider.tripType},
                onSelectionChanged: (v) => provider.setTripType(v.first),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AirportDrop(
                    label: tr(lang, 'from'),
                    value: provider.from,
                    airports: provider.airports,
                    lang: lang,
                    onChanged: (v) {
                      if (v != null) provider.setRoute(v, provider.to);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: tr(lang, 'swap'),
                  onPressed: provider.swapRoute,
                  icon: const Icon(Icons.swap_horiz),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _AirportDrop(
                    label: tr(lang, 'to'),
                    value: provider.to,
                    airports: provider.airports,
                    lang: lang,
                    onChanged: (v) {
                      if (v != null) provider.setRoute(provider.from, v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 340;
                final date = OutlinedButton.icon(
                  onPressed: onPickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: FittedBox(child: Text(dateOf(provider.departureDate))),
                );
                final cabin = _CabinDropdown(provider: provider, lang: lang);
                if (narrow) {
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: date),
                      const SizedBox(height: 10),
                      cabin,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: date),
                    const SizedBox(width: 8),
                    Expanded(child: cabin),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            _PassengerPicker(provider: provider, lang: lang),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: provider.loading ? null : onSearch,
                icon: const Icon(Icons.search),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(tr(lang, 'search_flight')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AirportDrop extends StatelessWidget {
  const _AirportDrop({
    required this.label,
    required this.value,
    required this.airports,
    required this.lang,
    required this.onChanged,
  });

  final String label, value, lang;
  final List<AirportEntity> airports;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: airports.any((a) => a.code == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: airports
          .map(
            (a) => DropdownMenuItem(
              value: a.code,
              child: Text(
                '${a.code} · ${cityName(lang, a.code, cityTh: a.cityTh, cityEn: a.cityEn)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _CabinDropdown extends StatelessWidget {
  const _CabinDropdown({required this.provider, required this.lang});
  final FlightProvider provider;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<CabinClass>(
      initialValue: provider.cabinClass,
      isExpanded: true,
      decoration: InputDecoration(labelText: tr(lang, 'cabin_class')),
      items: CabinClass.values
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(_cabin(lang, c), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) provider.setCabin(v);
      },
    );
  }
}

class _PassengerPicker extends StatelessWidget {
  const _PassengerPicker({required this.provider, required this.lang});
  final FlightProvider provider;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('${tr(lang, 'passengers')} ${provider.passengerCount}'),
      leading: const Icon(Icons.people_outline),
      children: [
        _PassengerRow(
          label: tr(lang, 'adult'),
          value: provider.adults,
          onRemove: provider.adults > 1
              ? () => provider.setPassengers(
                  provider.adults - 1,
                  provider.children,
                )
              : null,
          onAdd: () =>
              provider.setPassengers(provider.adults + 1, provider.children),
        ),
        _PassengerRow(
          label: tr(lang, 'child'),
          value: provider.children,
          onRemove: provider.children > 0
              ? () => provider.setPassengers(
                  provider.adults,
                  provider.children - 1,
                )
              : null,
          onAdd: () =>
              provider.setPassengers(provider.adults, provider.children + 1),
        ),
      ],
    );
  }
}

class _PassengerRow extends StatelessWidget {
  const _PassengerRow({
    required this.label,
    required this.value,
    required this.onRemove,
    required this.onAdd,
  });

  final String label;
  final int value;
  final VoidCallback? onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center)),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.promo,
    required this.lang,
    required this.onSelect,
  });
  final PromotionEntity promo;
  final String lang;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 255,
      child: Card(
        color: theme.colorScheme.primaryContainer.withValues(alpha: .55),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      promo.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Chip(
                    label: Text('-${promo.discountPercent}%'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${promo.from} → ${promo.to}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(_cabin(lang, promo.cabinClass)),
              const SizedBox(height: 6),
              Text(
                '${tr(lang, 'remaining')} ${promo.seatsLeft} ${tr(lang, 'seats')}',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: onSelect,
                  child: Text(tr(lang, 'view_flights')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _cabin(String lang, CabinClass c) => switch (c) {
  CabinClass.economy => tr(lang, 'economy'),
  CabinClass.premiumEconomy => tr(lang, 'premium_economy'),
  CabinClass.business => tr(lang, 'business'),
  CabinClass.first => tr(lang, 'first'),
};
