import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../models/entities.dart';
import '../../providers/language_provider.dart';
import '../../widgets/app_widgets.dart';

class TicketScreen extends StatelessWidget {
  const TicketScreen({super.key, required this.booking});
  final BookingEntity booking;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    return Scaffold(
      appBar: AppBar(title: const Text('E-Ticket')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        const Icon(Icons.flight_takeoff, size: 46, color: Color(0xFF0A66C2)),
                        const Text('NEON FLIGHT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(booking.flight.departure.code, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                            const Icon(Icons.arrow_forward),
                            Text(booking.flight.arrival.code, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const Divider(height: 28),
                        _row(context, 'Booking ID', booking.id),
                        _row(context, tr(lang, 'passenger'), booking.passengers.first.fullName),
                        _row(context, tr(lang, 'flight'), booking.flight.flightNumber),
                        _row(context, tr(lang, 'date'), dateOf(booking.flight.departureTime)),
                        _row(context, tr(lang, 'time'), timeOf(booking.flight.departureTime)),
                        _row(context, tr(lang, 'seat'), booking.seats.join(', ')),
                        _row(context, tr(lang, 'class'), _cabin(lang, booking.cabinClass)),
                        const SizedBox(height: 18),
                        const _PseudoQr(),
                        const SizedBox(height: 8),
                        Text(booking.id, style: const TextStyle(letterSpacing: 2)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(lang, 'downloaded')))),
                        icon: const Icon(Icons.download),
                        label: Text(tr(lang, 'download')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(lang, 'share_opened')))),
                        icon: const Icon(Icons.share),
                        label: Text(tr(lang, 'share')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(a, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            Expanded(child: Text(b, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      );
}

class _PseudoQr extends StatelessWidget {
  const _PseudoQr();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        height: 150,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 15),
          itemCount: 225,
          itemBuilder: (_, i) {
            final black = ((i * 17 + i ~/ 15 * 13) % 7) < 3 || (i % 15 < 3 && i ~/ 15 < 3);
            return ColoredBox(color: black ? Colors.black : Colors.white);
          },
        ),
      );
}

String _cabin(String lang, CabinClass c) => switch (c) {
      CabinClass.economy => tr(lang, 'economy'),
      CabinClass.premiumEconomy => tr(lang, 'premium_economy'),
      CabinClass.business => tr(lang, 'business'),
      CabinClass.first => tr(lang, 'first'),
    };
