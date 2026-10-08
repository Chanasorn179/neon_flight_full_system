import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../data/fares.dart';
import '../../data/thai_airlines.dart';
import '../../models/entities.dart';
import '../../providers/flight_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/airline_logo.dart';
import '../../widgets/app_widgets.dart';
import '../booking/passenger_screen.dart';

class FlightResultsScreen extends StatelessWidget {
  const FlightResultsScreen({super.key, this.outbound});

  /// Set on the second step of a round trip: the chosen outbound flight.
  final FlightEntity? outbound;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FlightProvider>();
    final lang = context.watch<LanguageProvider>().languageCode;
    final choosingReturn = outbound != null;
    final from = choosingReturn ? p.to : p.from;
    final to = choosingReturn ? p.from : p.to;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(from),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward_rounded, size: 20),
            ),
            Text(to),
          ],
        ),
      ),
      body: Column(
        children: [
          if (p.isRoundTrip)
            _StepBanner(
              lang: lang,
              step: choosingReturn ? 2 : 1,
              title: tr(lang, choosingReturn ? 'choose_return' : 'choose_outbound'),
              outbound: outbound,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: p.sort,
                    decoration: InputDecoration(labelText: tr(lang, 'sort_by')),
                    items: [
                      DropdownMenuItem(value: 'cheapest', child: Text(tr(lang, 'cheapest'))),
                      DropdownMenuItem(value: 'earliest', child: Text(tr(lang, 'earliest'))),
                      DropdownMenuItem(value: 'fastest', child: Text(tr(lang, 'fastest'))),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      p.setSort(v);
                      await p.search();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${tr(lang, 'max_price')} ${money(p.maxPrice)}', style: Theme.of(context).textTheme.labelMedium),
                      Slider(
                        value: p.maxPrice.clamp(3000, 50000).toDouble(),
                        min: 3000,
                        max: 50000,
                        divisions: 47,
                        onChanged: p.setMaxPrice,
                        onChangeEnd: (_) => p.search(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _body(context, p, lang)),
        ],
      ),
    );
  }

  void _select(BuildContext context, FlightProvider p, FlightEntity flight) {
    final Widget next;
    if (p.isRoundTrip && outbound == null) {
      next = FlightResultsScreen(outbound: flight);
    } else if (outbound != null) {
      next = PassengerScreen(
        flight: outbound!,
        cabinClass: p.cabinClass,
        returnFlight: flight,
      );
    } else {
      next = PassengerScreen(flight: flight, cabinClass: p.cabinClass);
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => next));
  }

  Widget _body(BuildContext context, FlightProvider p, String lang) {
    if (p.loading) return const Center(child: CircularProgressIndicator());
    if (p.error != null) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: tr(lang, 'load_failed'),
        subtitle: p.error!,
        action: FilledButton(onPressed: p.search, child: Text(tr(lang, 'retry'))),
      );
    }
    final flights = outbound == null ? p.results : p.returnOptionsAfter(outbound!);
    if (flights.isEmpty) {
      return EmptyState(
        icon: Icons.flight_takeoff,
        title: tr(lang, 'no_flights'),
        subtitle: tr(lang, outbound == null ? 'no_flights_sub' : 'no_return_flights'),
        action: FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr(lang, 'search_again'))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: flights.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => FlightCard(
        flight: flights[i],
        cabinClass: p.cabinClass,
        lang: lang,
        onSelect: () => _select(context, p, flights[i]),
      ),
    );
  }
}

class FlightCard extends StatelessWidget {
  const FlightCard({
    super.key,
    required this.flight,
    required this.cabinClass,
    required this.lang,
    required this.onSelect,
  });

  final FlightEntity flight;
  final CabinClass cabinClass;
  final String lang;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final h = flight.duration.inHours;
    final m = flight.duration.inMinutes.remainder(60);
    final airline = airlineForFlight(flight.airline, flight.flightNumber);
    final passengers = context.watch<FlightProvider>().passengerCount;
    // What the passenger actually pays per seat: fare + airport tax.
    final perPerson = flight.price(cabinClass) +
        passengerServiceCharge(flight.departure, flight.arrival);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                AirlineLogo(
                  airlineName: flight.airline,
                  flightNumber: flight.flightNumber,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        airline == null
                            ? flight.airline
                            : (lang == 'th' ? airline.nameTh : airline.nameEn),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(flight.flightNumber),
                    ],
                  ),
                ),
                Text(
                  '${flight.availableSeats} ${tr(lang, 'seats')}',
                  style: TextStyle(color: flight.availableSeats < 6 ? Colors.red : Colors.green),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(child: _Point(code: flight.departure.code, time: timeOf(flight.departureTime))),
                Expanded(
                  child: Column(
                    children: [
                      Text('$h ${tr(lang, 'hours')} $m ${tr(lang, 'minutes')}', style: Theme.of(context).textTheme.labelSmall),
                      const Icon(Icons.flight_takeoff),
                      Text(tr(lang, 'direct'), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(child: _Point(code: flight.arrival.code, time: timeOf(flight.arrivalTime), right: true)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_cabin(lang, cabinClass)),
                      Text(
                        money(perPerson),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        passengers > 1
                            ? trArgs(lang, 'total_for_n', {
                                'n': '$passengers',
                                'amount': money(perPerson * passengers),
                              })
                            : tr(lang, 'per_person_incl_tax'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onSelect,
                  child: Text(tr(lang, 'select')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBanner extends StatelessWidget {
  const _StepBanner({
    required this.lang,
    required this.step,
    required this.title,
    required this.outbound,
  });

  final String lang;
  final int step;
  final String title;
  final FlightEntity? outbound;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trArgs(lang, 'step_of', {'n': '$step', 'total': '2'}),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(title, style: theme.textTheme.titleMedium),
          if (outbound != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                AirlineLogo(
                  airlineName: outbound!.airline,
                  flightNumber: outbound!.flightNumber,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${tr(lang, 'outbound_flight')}: ${outbound!.flightNumber} · '
                    '${dateOf(outbound!.departureTime)} ${timeOf(outbound!.departureTime)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.code, required this.time, this.right = false});
  final String code, time;
  final bool right;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(time, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          Text(code, style: Theme.of(context).textTheme.titleMedium),
        ],
      );
}

String _cabin(String lang, CabinClass c) => switch (c) {
      CabinClass.economy => tr(lang, 'economy'),
      CabinClass.premiumEconomy => tr(lang, 'premium_economy'),
      CabinClass.business => tr(lang, 'business'),
      CabinClass.first => tr(lang, 'first'),
    };

