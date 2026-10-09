import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../models/travel_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/flight_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/transfer_dispatch_service.dart';
import '../../widgets/airport_picker.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/notification_bell.dart';
import '../flights/flight_results_screen.dart';
import 'airport_transfer_section.dart';

final _transferDispatchService = TransferDispatchService();

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

  Future<void> _pickReturnDate(BuildContext context, FlightProvider provider) async {
    final first = provider.departureDate;
    final date = await showDatePicker(
      context: context,
      initialDate: provider.returnDate ?? first,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
    );
    if (date != null) provider.setReturn(date);
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
    final theme = Theme.of(context);
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
    final outboundBooking = upcomingBookings.isEmpty
        ? null
        : upcomingBookings.first;
    final outboundFlight = outboundBooking?.flight;
    final transferPassenger =
        outboundBooking == null || outboundBooking.passengers.isEmpty
        ? null
        : outboundBooking.passengers.first;
    final transferReservation = outboundFlight == null || user == null
        ? null
        : bookingProvider.transferBookingFor(
            userId: user.id,
            airportCode: outboundFlight.departure.code,
            flightDepartureTime: outboundFlight.departureTime,
          );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const Text(
          'NEON FLIGHT',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: const NotificationBell(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.loadAirports,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name == null || user!.name.trim().isEmpty
                        ? tr(lang, 'hello')
                        : '${tr(lang, 'hello')} ${user.name}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(lang, 'where_today'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SearchCard(
              provider: provider,
              lang: lang,
              onPickDate: () => _pickDate(context, provider),
              onPickReturnDate: () => _pickReturnDate(context, provider),
              onSearch: () => _search(context),
            ),
            const SizedBox(height: 26),
            SectionTitle(
              tr(lang, 'special_deals'),
              icon: Icons.local_fire_department_rounded,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 252,
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
            const SizedBox(height: 26),
            AirportTransferSection(
              languageCode: lang,
              departureAirportCode:
                  outboundFlight?.departure.code ?? provider.from,
              flightDepartureTime: outboundFlight?.departureTime,
              userId: user?.id ?? 'guest',
              initialReservation: transferReservation,
              driverNotificationEnabled: true,
              onBooked: (booking) async {
                bookingProvider.addTransferBooking(booking);
                await _transferDispatchService.notifyDriver(
                  booking: booking,
                  passengerName:
                      transferPassenger?.fullName ?? user?.name ?? '',
                  passengerPhone: transferPassenger?.phone ?? '',
                );
              },
            ),
            const SizedBox(height: 26),
            SectionTitle(
              tr(lang, 'popular_destinations'),
              icon: Icons.public_rounded,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Top domestic airports by real passenger traffic.
                for (final airport in provider.airports
                    .where((a) => a.isDomestic && a.code != 'BKK' && a.code != 'DMK')
                    .take(8))
                  _DestinationChip(
                    label: cityName(
                      lang,
                      airport.code,
                      cityTh: airport.cityTh,
                      cityEn: airport.cityEn,
                    ),
                    code: airport.code,
                    onTap: () async {
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
    required this.onPickReturnDate,
    required this.onSearch,
  });

  final FlightProvider provider;
  final String lang;
  final VoidCallback onPickDate;
  final VoidCallback onPickReturnDate;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(lang, 'search_flight'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr(lang, 'where_today'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: SegmentedButton<TripType>(
                segments: [
                  ButtonSegment(
                    value: TripType.oneWay,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(tr(lang, 'one_way')),
                  ),
                  ButtonSegment(
                    value: TripType.roundTrip,
                    label: Text(tr(lang, 'round_trip')),
                  ),
                ],
                selected: {provider.tripType},
                onSelectionChanged: (v) => provider.setTripType(v.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            RouteSelector(
              from: provider.from,
              to: provider.to,
              airports: provider.airports,
              lang: lang,
              onChanged: provider.setRoute,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 360;
                final date = _InfoPickerTile(
                  icon: Icons.calendar_month_rounded,
                  label: tr(lang, 'date'),
                  value: dateOf(provider.departureDate),
                  onTap: onPickDate,
                );
                final cabin = _CabinDropdown(provider: provider, lang: lang);
                if (provider.tripType == TripType.roundTrip) {
                  final returnDate = _InfoPickerTile(
                    icon: Icons.event_repeat_rounded,
                    label: tr(lang, 'return_date'),
                    value: provider.returnDate == null
                        ? '-'
                        : dateOf(provider.returnDate!),
                    onTap: onPickReturnDate,
                  );
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: date),
                          const SizedBox(width: 10),
                          Expanded(child: returnDate),
                        ],
                      ),
                      const SizedBox(height: 10),
                      cabin,
                    ],
                  );
                }
                if (narrow) {
                  return Column(
                    children: [
                      date,
                      const SizedBox(height: 10),
                      cabin,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: date),
                    const SizedBox(width: 10),
                    Expanded(child: cabin),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            _PassengerPicker(provider: provider, lang: lang),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: provider.loading ? null : onSearch,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.search_rounded),
                label: Text(
                  tr(lang, 'search_flight'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPickerTile extends StatelessWidget {
  const _InfoPickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .75),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CabinDropdown extends StatelessWidget {
  const _CabinDropdown({required this.provider, required this.lang});

  final FlightProvider provider;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<CabinClass>(
      initialValue: provider.cabinClass,
      isExpanded: true,
      borderRadius: BorderRadius.circular(18),
      decoration: InputDecoration(
        labelText: tr(lang, 'cabin_class'),
        prefixIcon: const Icon(Icons.airline_seat_recline_normal_rounded),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .75),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .75),
          ),
        ),
      ),
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
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .75),
        ),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        title: Text(
          '${tr(lang, 'passengers')} ${provider.passengerCount}',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${tr(lang, 'adult')} ${provider.adults} · ${tr(lang, 'child')} ${provider.children}',
          style: theme.textTheme.bodySmall,
        ),
        leading: const Icon(Icons.people_alt_outlined),
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
          const SizedBox(height: 8),
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
      ),
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
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        _StepCircleButton(
          icon: Icons.remove_rounded,
          onTap: onRemove,
          enabledColor: theme.colorScheme.primary,
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        _StepCircleButton(
          icon: Icons.add_rounded,
          onTap: onAdd,
          enabledColor: theme.colorScheme.primary,
        ),
      ],
    );
  }
}

class _StepCircleButton extends StatelessWidget {
  const _StepCircleButton({
    required this.icon,
    required this.onTap,
    required this.enabledColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color enabledColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? enabledColor.withValues(alpha: .12)
              : Colors.grey.withValues(alpha: .12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? enabledColor : Colors.grey,
        ),
      ),
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
    final isDark = theme.brightness == Brightness.dark;
    final gradient = _promoGradient(promo.cabinClass, isDark);
    final promoTextColor = isDark ? const Color(0xFFF7F9FF) : const Color(0xFF162033);

    return SizedBox(
      width: 250,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: .1),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: .10)
                            : Colors.white.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        promo.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: promoTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: .12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '-${promo.discountPercent}%',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFBBD1FF) : theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${promo.from} → ${promo.to}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: promoTextColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: .10)
                      : Colors.white.withValues(alpha: .65),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _cabin(lang, promo.cabinClass),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${tr(lang, 'remaining')} ${promo.seatsLeft} ${tr(lang, 'seats')}',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: onSelect,
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: .10)
                        : Colors.white.withValues(alpha: .55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    tr(lang, 'view_flights'),
                    style: TextStyle(
                      color: promoTextColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient _promoGradient(CabinClass cabin, bool isDark) {
    if (isDark) {
      return switch (cabin) {
        CabinClass.economy => const LinearGradient(
          colors: [Color(0xFF1C2C45), Color(0xFF243A59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        CabinClass.premiumEconomy => const LinearGradient(
          colors: [Color(0xFF173B36), Color(0xFF21514A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        CabinClass.business => const LinearGradient(
          colors: [Color(0xFF322853), Color(0xFF463770)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        CabinClass.first => const LinearGradient(
          colors: [Color(0xFF463A20), Color(0xFF5A4827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      };
    }

    return switch (cabin) {
      CabinClass.economy => const LinearGradient(
        colors: [Color(0xFFDDE8FF), Color(0xFFC9D9F8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      CabinClass.premiumEconomy => const LinearGradient(
        colors: [Color(0xFFE2F4EE), Color(0xFFCDEBDF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      CabinClass.business => const LinearGradient(
        colors: [Color(0xFFE6E0FF), Color(0xFFD9D0FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      CabinClass.first => const LinearGradient(
        colors: [Color(0xFFFFF0C7), Color(0xFFFFE5A3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    };
  }
}

class _DestinationChip extends StatelessWidget {
  const _DestinationChip({
    required this.label,
    required this.code,
    required this.onTap,
  });

  final String label;
  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 44) / 2;
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      code,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
