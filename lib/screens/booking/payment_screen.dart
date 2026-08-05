import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../models/entities.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/language_provider.dart';
import '../../core/constants.dart';
import '../../widgets/app_widgets.dart';
import 'ticket_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.flight,
    required this.cabinClass,
    required this.passengers,
    required this.seats,
  });

  final FlightEntity flight;
  final CabinClass cabinClass;
  final List<PassengerEntity> passengers;
  final List<String> seats;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod method = PaymentMethod.promptPay;
  bool paying = false;

  FareBreakdown get fare => FareBreakdown(
        fare: widget.flight.price(widget.cabinClass) * widget.passengers.length,
        tax: AppConstants.airportTax * widget.passengers.length.toDouble(),
        service: AppConstants.serviceFee * widget.passengers.length.toDouble(),
        seatFee: widget.seats.length * 200,
      );

  Future<void> pay() async {
    setState(() => paying = true);
    final user = context.read<AuthProvider>().currentUser!;
    final booking = await context.read<BookingProvider>().create(
          userId: user.id,
          flight: widget.flight,
          cabinClass: widget.cabinClass,
          passengers: widget.passengers,
          seats: widget.seats,
          paymentMethod: method,
        );
    if (!mounted) return;
    setState(() => paying = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => TicketScreen(booking: booking)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'payment'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.flight.departure.code} → ${widget.flight.arrival.code}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text('${widget.flight.airline} · ${widget.flight.flightNumber} · ${_cabin(lang, widget.cabinClass)}'),
                  const SizedBox(height: 8),
                  Text('${tr(lang, 'seat')}: ${widget.seats.join(', ')}'),
                ],
              ),
            ),
          ),
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
                    const Icon(Icons.qr_code_2, size: 120),
                    Text(tr(lang, 'scan_promptpay')),
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
