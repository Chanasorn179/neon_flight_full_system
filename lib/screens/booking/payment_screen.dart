import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_localizations.dart';
import '../../models/entities.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/promptpay_service.dart';
import '../../widgets/airline_logo.dart';
import '../../widgets/app_widgets.dart';
import 'ticket_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.flight,
    required this.cabinClass,
    required this.passengers,
    required this.seats,
    this.returnFlight,
    this.returnSeats = const [],
  });

  final FlightEntity flight;
  final CabinClass cabinClass;
  final List<PassengerEntity> passengers;
  final List<String> seats;

  /// Set for a round trip; both legs are paid and booked together.
  final FlightEntity? returnFlight;
  final List<String> returnSeats;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod method = PaymentMethod.promptPay;
  bool paying = false;

  FareBreakdown get fare {
    final legs = [
      BookingProvider.fareFor(widget.flight, widget.cabinClass,
          widget.passengers.length, widget.seats.length),
      if (widget.returnFlight != null)
        BookingProvider.fareFor(widget.returnFlight!, widget.cabinClass,
            widget.passengers.length, widget.returnSeats.length),
    ];
    return FareBreakdown(
      fare: legs.fold(0, (sum, f) => sum + f.fare),
      tax: legs.fold(0, (sum, f) => sum + f.tax),
      service: legs.fold(0, (sum, f) => sum + f.service),
      seatFee: legs.fold(0, (sum, f) => sum + f.seatFee),
    );
  }

  Future<void> pay() async {
    if (method == PaymentMethod.promptPay && !PromptPayService.configured) {
      final lang = context.read<LanguageProvider>().languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(lang, 'promptpay_not_configured'))),
      );
      return;
    }
    setState(() => paying = true);
    try {
      final user = context.read<AuthProvider>().currentUser!;
      final created = await context.read<BookingProvider>().create(
            userId: user.id,
            flight: widget.flight,
            cabinClass: widget.cabinClass,
            passengers: widget.passengers,
            seats: widget.seats,
            paymentMethod: method,
            returnFlight: widget.returnFlight,
            returnSeats: widget.returnSeats,
          );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => TicketScreen(booking: created.first)),
        (route) => route.isFirst,
      );
    } on SeatTakenException catch (error) {
      if (!mounted) return;
      final lang = context.read<LanguageProvider>().languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trArgs(lang, 'seat_taken', {'seats': error.seats.join(', ')}),
          ),
        ),
      );
      // Back to the seat map, which reloads taken seats.
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      final lang = context.read<LanguageProvider>().languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(lang, 'booking_failed'))),
      );
    } finally {
      if (mounted) setState(() => paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final promptPayPayload = PromptPayService.configured
        ? PromptPayService.payload(amount: fare.total)
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'payment'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LegSummary(
            label: widget.returnFlight == null ? null : tr(lang, 'outbound_flight'),
            flight: widget.flight,
            seats: widget.seats,
            cabin: _cabin(lang, widget.cabinClass),
            lang: lang,
          ),
          if (widget.returnFlight != null) ...[
            const SizedBox(height: 10),
            _LegSummary(
              label: tr(lang, 'return_flight'),
              flight: widget.returnFlight!,
              seats: widget.returnSeats,
              cabin: _cabin(lang, widget.cabinClass),
              lang: lang,
            ),
          ],
          const SizedBox(height: 16),
          Text(tr(lang, 'payment_method'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SegmentedButton<PaymentMethod>(
            segments: const [
              ButtonSegment(value: PaymentMethod.promptPay, icon: Icon(Icons.qr_code), label: Text('PromptPay')),
              ButtonSegment(value: PaymentMethod.card, icon: Icon(Icons.credit_card), label: Text('Card')),
              ButtonSegment(value: PaymentMethod.mobileBanking, icon: Icon(Icons.account_balance), label: Text('Mobile')),
            ],
            selected: {method},
            onSelectionChanged: (v) => setState(() => method = v.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 14),
          if (method == PaymentMethod.promptPay)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    if (promptPayPayload != null)
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(10),
                        child: QrImageView(data: promptPayPayload, size: 190, backgroundColor: Colors.white),
                      )
                    else
                      Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Center(child: Icon(Icons.qr_code_2_rounded, size: 110)),
                      ),
                    const SizedBox(height: 10),
                    Text(promptPayPayload != null ? 'สแกน QR PromptPay เพื่อชำระเงินจริง' : 'ตั้ง PROMPTPAY_ID ก่อนเพื่อสร้าง QR รับเงินจริง'),
                    Text(money(fare.total), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            )
          else if (method == PaymentMethod.card)
            const _CardFields()
          else
            _BankInfo(lang: lang),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _line(tr(lang, 'fare'), fare.fare),
                  _line(tr(lang, 'airport_tax'), fare.tax),
                  _line(tr(lang, 'service_fee'), fare.service),
                  _line(tr(lang, 'seat_fee'), fare.seatFee),
                  const Divider(),
                  _line(tr(lang, 'total'), fare.total, bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: paying ? null : pay,
            icon: paying
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock),
            label: Padding(padding: const EdgeInsets.all(14), child: Text(tr(lang, 'confirm_pay'))),
          ),
          if (method != PaymentMethod.promptPay) ...[
            const SizedBox(height: 8),
            Text(
              tr(lang, 'gateway_note'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, double value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null))),
            Text(money(value), style: TextStyle(fontWeight: bold ? FontWeight.w900 : null, fontSize: bold ? 18 : null)),
          ],
        ),
      );
}

class _LegSummary extends StatelessWidget {
  const _LegSummary({
    required this.label,
    required this.flight,
    required this.seats,
    required this.cabin,
    required this.lang,
  });

  final String? label;
  final FlightEntity flight;
  final List<String> seats;
  final String cabin;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              Text(
                label!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
            ],
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
                      Row(
                        children: [
                          Text(flight.departure.code, style: theme.textTheme.titleLarge),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward_rounded, size: 18),
                          ),
                          Text(flight.arrival.code, style: theme.textTheme.titleLarge),
                        ],
                      ),
                      Text(
                        '${dateOf(flight.departureTime)} · ${timeOf(flight.departureTime)}'
                        ' · ${flight.flightNumber}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$cabin · ${tr(lang, 'seat')} ${seats.join(', ')}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _CardFields extends StatelessWidget {
  const _CardFields();
  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(decoration: InputDecoration(labelText: 'Card number', prefixIcon: Icon(Icons.credit_card))),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(decoration: InputDecoration(labelText: 'MM/YY'))),
                  SizedBox(width: 10),
                  Expanded(child: TextField(decoration: InputDecoration(labelText: 'CVV'))),
                ],
              ),
            ],
          ),
        ),
      );
}

class _BankInfo extends StatelessWidget {
  const _BankInfo({required this.lang});
  final String lang;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.account_balance),
          title: const Text('Mobile Banking'),
          subtitle: Text(tr(lang, 'mobile_bank_info')),
        ),
      );
}

String _cabin(String lang, CabinClass c) => switch (c) {
      CabinClass.economy => tr(lang, 'economy'),
      CabinClass.premiumEconomy => tr(lang, 'premium_economy'),
      CabinClass.business => tr(lang, 'business'),
      CabinClass.first => tr(lang, 'first'),
    };
