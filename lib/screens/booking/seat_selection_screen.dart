import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../models/entities.dart';
import '../../providers/language_provider.dart';
import 'payment_screen.dart';

class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({
    super.key,
    required this.flight,
    required this.cabinClass,
    required this.passengers,
  });

  final FlightEntity flight;
  final CabinClass cabinClass;
  final List<PassengerEntity> passengers;

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final selected = <String>{};
  final unavailable = {'1B', '2D', '3C', '5A', '6F', '8E', '9B'};

  int get requiredSeats => widget.passengers.length;
  bool get canContinue => selected.length == requiredSeats;

  void _toggle(String id) {
    if (unavailable.contains(id)) return;
    setState(() {
      if (selected.contains(id)) {
        selected.remove(id);
      } else if (selected.length < requiredSeats) {
        selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'select_seat'))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.flight.departure.code} → ${widget.flight.arrival.code}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(_cabin(lang, widget.cabinClass)),
                          ],
                        ),
                      ),
                      const Icon(Icons.airplane_ticket_rounded, size: 36),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _Legend(color: colors.surfaceContainerHighest, text: tr(lang, 'available')),
                    _Legend(color: colors.primary, text: tr(lang, 'selected')),
                    _Legend(color: Colors.grey.shade500, text: tr(lang, 'unavailable')),
                  ],
                ),
                const SizedBox(height: 28),
                Icon(Icons.flight_rounded, size: 42, color: colors.onSurface),
                Center(child: Text(tr(lang, 'front'))),
                const SizedBox(height: 20),
                _CabinMap(
                  selected: selected,
                  unavailable: unavailable,
                  onSeat: _toggle,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: colors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(selected.isEmpty ? tr(lang, 'please_select') : tr(lang, 'selected_seats')),
                            const SizedBox(height: 3),
                            Text(
                              selected.isEmpty ? '0 / $requiredSeats' : selected.join(', '),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '฿${selected.length * 200}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: canContinue
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PaymentScreen(
                                    flight: widget.flight,
                                    cabinClass: widget.cabinClass,
                                    passengers: widget.passengers,
                                    seats: selected.toList(),
                                  ),
                                ),
                              )
                          : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        canContinue
                            ? tr(lang, 'continue')
                            : '${tr(lang, 'select_seat')} ${selected.length}/$requiredSeats',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CabinMap extends StatelessWidget {
  const _CabinMap({
    required this.selected,
    required this.unavailable,
    required this.onSeat,
  });

  final Set<String> selected;
  final Set<String> unavailable;
  final ValueChanged<String> onSeat;

  @override
  Widget build(BuildContext context) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 28),
            for (int i = 0; i < letters.length; i++) ...[
              if (i == 3) const SizedBox(width: 18),
              Expanded(child: Center(child: Text(letters[i]))),
              if (i != letters.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 8),
        for (int row = 1; row <= 10; row++) ...[
          Row(
            children: [
              SizedBox(width: 28, child: Text('$row', textAlign: TextAlign.center)),
              for (int i = 0; i < letters.length; i++) ...[
                if (i == 3) const SizedBox(width: 18),
                Expanded(
                  child: _Seat(
                    id: '$row${letters[i]}',
                    selected: selected.contains('$row${letters[i]}'),
                    unavailable: unavailable.contains('$row${letters[i]}'),
                    onTap: () => onSeat('$row${letters[i]}'),
                  ),
                ),
                if (i != letters.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.id,
    required this.selected,
    required this.unavailable,
    required this.onTap,
  });

  final String id;
  final bool selected;
  final bool unavailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg = unavailable
        ? Colors.grey.shade500
        : selected
            ? colors.primary
            : colors.surfaceContainerHighest;
    final fg = unavailable || selected ? Colors.white : colors.onSurface;

    return AspectRatio(
      aspectRatio: 1.05,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: unavailable ? null : onTap,
          child: Center(
            child: Text(id, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 5),
        Text(text),
      ],
    );
  }
}

String _cabin(String lang, CabinClass c) => switch (c) {
      CabinClass.economy => tr(lang, 'economy'),
      CabinClass.premiumEconomy => tr(lang, 'premium_economy'),
      CabinClass.business => tr(lang, 'business'),
      CabinClass.first => tr(lang, 'first'),
    };
