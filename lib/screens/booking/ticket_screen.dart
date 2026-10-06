import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_localizations.dart';
import '../../models/entities.dart';
import '../../providers/language_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/ticket_qr_service.dart';
import '../../widgets/airline_logo.dart';
import '../../widgets/app_widgets.dart';
import 'ticket_scanner_screen.dart';

class TicketScreen extends StatelessWidget {
  const TicketScreen({super.key, required this.booking});
  final BookingEntity booking;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final qrData = TicketQrService.encode(booking);

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Ticket'),
        actions: [
          IconButton(
            tooltip: tr(lang, 'scan_ticket'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TicketScannerScreen(),
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
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
                        AirlineLogo(
                          airlineName: booking.flight.airline,
                          flightNumber: booking.flight.flightNumber,
                          size: 56,
                        ),
                        const Text(
                          'NEON FLIGHT',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              booking.flight.departure.code,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const Icon(Icons.arrow_forward),
                            Text(
                              booking.flight.arrival.code,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const Divider(height: 28),
                        _row(context, 'Booking ID', booking.id),
                        _row(
                          context,
                          tr(lang, 'passenger'),
                          booking.passengers.first.fullName,
                        ),
                        _row(
                          context,
                          tr(lang, 'flight'),
                          booking.flight.flightNumber,
                        ),
                        _row(
                          context,
                          tr(lang, 'date'),
                          dateOf(booking.flight.departureTime),
                        ),
                        _row(
                          context,
                          tr(lang, 'time'),
                          timeOf(booking.flight.departureTime),
                        ),
                        _row(
                          context,
                          tr(lang, 'seat'),
                          booking.seats.join(', '),
                        ),
                        _row(
                          context,
                          tr(lang, 'class'),
                          _cabin(lang, booking.cabinClass),
                        ),
                        const SizedBox(height: 20),

                        // The QR only appears once the server has confirmed
                        // payment and issued the public ticket record.
                        StreamBuilder<PaymentStatus>(
                          stream: booking.isPaid
                              ? null
                              : FirebaseService.watchPaymentStatus(booking.id),
                          initialData: booking.paymentStatus,
                          builder: (context, snapshot) {
                            if (snapshot.data != PaymentStatus.paid) {
                              return _PendingPayment(booking: booking);
                            }
                            return Column(
                              children: [
                            // Bigger QR + generous quiet zone + short payload.
                            // This makes it much easier to scan using another
                            // phone's camera, Google Lens, or a generic QR app.
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(18),
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 240,
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.all(12),
                                gapless: true,
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              booking.id,
                              style: const TextStyle(
                                letterSpacing: 2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr(lang, 'ticket_qr_hint'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(content: Text(tr(lang, 'downloaded'))),
                        ),
                        icon: const Icon(Icons.download),
                        label: Text(tr(lang, 'download')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(content: Text(tr(lang, 'share_opened'))),
                        ),
                        icon: const Icon(Icons.share),
                        label: Text(tr(lang, 'share')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TicketScannerScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(tr(lang, 'open_scanner')),
                  ),
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
            Expanded(
              child: Text(
                a,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                b,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
}

String _cabin(String lang, CabinClass c) => switch (c) {
      CabinClass.economy => tr(lang, 'economy'),
      CabinClass.premiumEconomy => tr(lang, 'premium_economy'),
      CabinClass.business => tr(lang, 'business'),
      CabinClass.first => tr(lang, 'first'),
    };

class _PendingPayment extends StatelessWidget {
  const _PendingPayment({required this.booking});

  final BookingEntity booking;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            size: 40,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(height: 8),
          Text(
            tr(lang, 'payment_pending'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              trArgs(lang, 'payment_pending_amount', {'amount': money(booking.fare.total)}),
              trArgs(lang, 'payment_pending_reference', {'id': booking.id}),
              tr(lang, 'payment_pending_qr'),
            ].join('\n'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
