import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../data/thai_airlines.dart';
import '../../models/entities.dart';
import '../../providers/flight_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/airline_logo.dart';
import '../../widgets/app_widgets.dart';
import '../booking/passenger_screen.dart';

class FlightResultsScreen extends StatelessWidget {
  const FlightResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FlightProvider>();
    final lang = context.watch<LanguageProvider>().languageCode;

    return Scaffold(
      appBar: AppBar(title: Text('${p.from} → ${p.to}')),
      body: Column(
        children: [
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
    if (p.results.isEmpty) {
      return EmptyState(
        icon: Icons.flight_takeoff,
        title: tr(lang, 'no_flights'),
        subtitle: tr(lang, 'no_flights_sub'),
        action: FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr(lang, 'search_again'))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: p.results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => FlightCard(
        flight: p.results[i],
        cabinClass: p.cabinClass,
        lang: lang,
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
  });

  final FlightEntity flight;
  final CabinClass cabinClass;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final h = flight.duration.inHours;
    final m = flight.duration.inMinutes.remainder(60);
    final airline = airlineForFlight(flight.airline, flight.flightNumber);

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
                      Text(money(flight.price(cabinClass)), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PassengerScreen(flight: flight, cabinClass: cabinClass)),
                  ),
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

