import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../core/app_localizations.dart';
import '../../data/thai_airlines.dart';
import '../../models/entities.dart';
import '../../providers/booking_provider.dart';
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
                _BoardingPass(
                  booking: booking,
                  lang: lang,
                  // The QR only appears once the server has confirmed
                  // payment and issued the public ticket record.
                  bottom: StreamBuilder<PaymentStatus>(
                    stream: booking.isPaid
                        ? null
                        : FirebaseService.watchPaymentStatus(booking.id),
                    initialData: booking.paymentStatus,
                    builder: (context, snapshot) {
                      if (booking.status == BookingStatus.cancelled) {
                        return const _CancelledNotice();
                      }
                      if (snapshot.data != PaymentStatus.paid) {
                        return _PendingPayment(booking: booking);
                      }
                      return Column(
                        children: [
                          // Big QR with a generous quiet zone: easy to scan
                          // with another phone's camera or a generic QR app.
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: QrImageView(
                              data: qrData,
                              version: QrVersions.auto,
                              size: 220,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.all(10),
                              gapless: true,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            booking.id,
                            style: const TextStyle(
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
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
}

String _cabin(String lang, CabinClass c) => switch (c) {
      CabinClass.economy => tr(lang, 'economy'),
      CabinClass.premiumEconomy => tr(lang, 'premium_economy'),
      CabinClass.business => tr(lang, 'business'),
      CabinClass.first => tr(lang, 'first'),
    };

class _BoardingPass extends StatelessWidget {
  const _BoardingPass({
    required this.booking,
    required this.lang,
    required this.bottom,
  });

  final BookingEntity booking;
  final String lang;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final flight = booking.flight;
    final airline = airlineForFlight(flight.airline, flight.flightNumber);
    final airlineName = airline == null
        ? flight.airline
        : (lang == 'th' ? airline.nameTh : airline.nameEn);
    final h = flight.duration.inHours;
    final m = flight.duration.inMinutes.remainder(60);
    const onHeader = Colors.white; // on AppTheme.heroGradient in both modes

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? .35 : .08,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    AirlineLogo(
                      airlineName: flight.airline,
                      flightNumber: flight.flightNumber,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            airlineName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: onHeader,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${flight.flightNumber} · ${_cabin(lang, booking.cabinClass)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onHeader.withValues(alpha: .85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _Endpoint(
                      code: flight.departure.code,
                      city: lang == 'th' ? flight.departure.cityTh : flight.departure.cityEn,
                      time: timeOf(flight.departureTime),
                      color: onHeader,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.flight_rounded, color: onHeader),
                          const SizedBox(height: 4),
                          Container(height: 1.5, color: onHeader.withValues(alpha: .4)),
                          const SizedBox(height: 6),
                          Text(
                            '$h ${tr(lang, 'hours')} $m ${tr(lang, 'minutes')}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: onHeader.withValues(alpha: .9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Endpoint(
                      code: flight.arrival.code,
                      city: lang == 'th' ? flight.arrival.cityTh : flight.arrival.cityEn,
                      time: timeOf(flight.arrivalTime),
                      color: onHeader,
                      alignEnd: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Column(
              children: [
                _Detail(
                  label: tr(lang, 'passenger'),
                  value: booking.passengers.map((p) => p.fullName).join(', '),
                  wide: true,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _Detail(label: tr(lang, 'date'), value: dateOf(flight.departureTime))),
                    Expanded(child: _Detail(label: tr(lang, 'seat'), value: booking.seats.join(', '))),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _Detail(label: 'Booking ID', value: booking.id)),
                    Expanded(child: _Detail(label: tr(lang, 'flight'), value: flight.flightNumber)),
                  ],
                ),
              ],
            ),
          ),
          const _Perforation(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
            child: bottom,
          ),
        ],
      ),
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.code,
    required this.city,
    required this.time,
    required this.color,
    this.alignEnd = false,
  });

  final String code;
  final String city;
  final String time;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            code,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
          Text(
            city,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withValues(alpha: .85),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value, this.wide = false});

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: wide ? double.infinity : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Tear line between the flight details and the QR, with side notches.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notch = theme.scaffoldBackgroundColor;
    return SizedBox(
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: LayoutBuilder(
              builder: (context, c) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  (c.maxWidth / 12).floor(),
                  (_) => Container(
                    width: 6,
                    height: 1.6,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -14,
            child: CircleAvatar(radius: 14, backgroundColor: notch),
          ),
          Positioned(
            right: -14,
            child: CircleAvatar(radius: 14, backgroundColor: notch),
          ),
        ],
      ),
    );
  }
}

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
        color: AppTheme.pendingBackground(theme.brightness),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            size: 40,
            color: AppTheme.pendingForeground(theme.brightness),
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
          if (booking.canCancel) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error.withValues(alpha: .6)),
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => _confirmCancel(context, lang),
              icon: const Icon(Icons.cancel_outlined),
              label: Text(tr(lang, 'cancel_booking')),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, String lang) async {
    final provider = context.read<BookingProvider>();
    final isTrip = provider.tripOf(booking).length > 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: colors.error),
          title: Text(tr(lang, 'cancel_booking')),
          content: Text([
            trArgs(lang, 'cancel_booking_confirm', {'id': booking.id}),
            if (isTrip) tr(lang, 'cancel_trip_note'),
          ].join('\n\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr(lang, 'keep_booking')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr(lang, 'cancel_booking')),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.cancel(booking);
      messenger.showSnackBar(SnackBar(content: Text(tr(lang, 'booking_cancelled'))));
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(tr(lang, 'cancel_failed'))));
    }
  }
}

class _CancelledNotice extends StatelessWidget {
  const _CancelledNotice();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.block_rounded, size: 36, color: theme.colorScheme.error),
          const SizedBox(height: 8),
          Text(
            tr(lang, 'booking_cancelled'),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            tr(lang, 'booking_cancelled_body'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
