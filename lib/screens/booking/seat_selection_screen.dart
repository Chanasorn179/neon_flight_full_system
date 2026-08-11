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

  Set<String> get unavailable => switch (widget.cabinClass) {
        CabinClass.economy => {'1B', '2D', '3C', '5A', '6F', '8E', '9B'},
        CabinClass.premiumEconomy => {'1C', '2F', '4A'},
        CabinClass.business => {'1D', '3A'},
        CabinClass.first => {'2F'},
      };

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
    final layout = _CabinLayout.forClass(widget.cabinClass);

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
                            Text('${_cabin(lang, widget.cabinClass)} · ${layout.descriptionTh}'),
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
                const SizedBox(height: 26),
                Icon(Icons.flight_rounded, size: 42, color: colors.onSurface),
                Center(child: Text(tr(lang, 'front'))),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(layout.icon, size: 18, color: colors.primary),
                      const SizedBox(width: 8),
                      Text('${layout.descriptionTh} · ค่าที่นั่ง ${widget.cabinClass.seatFee.toStringAsFixed(0)} บาท/ที่'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CabinMap(
                  layout: layout,
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
                  BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 20, offset: const Offset(0, -5)),
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
                        '฿${(selected.length * widget.cabinClass.seatFee).toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.primary, fontWeight: FontWeight.w900),
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
                                    seats: selected.toList()..sort(),
                                  ),
                                ),
                              )
                          : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(canContinue ? tr(lang, 'continue') : '${tr(lang, 'select_seat')} ${selected.length}/$requiredSeats'),
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

class _CabinLayout {
  const _CabinLayout({required this.letters, required this.aisleAfter, required this.rows, required this.descriptionTh, required this.icon, required this.seatAspect});
  final List<String> letters;
  final Set<int> aisleAfter;
  final int rows;
  final String descriptionTh;
  final IconData icon;
  final double seatAspect;

  static _CabinLayout forClass(CabinClass c) => switch (c) {
        CabinClass.economy => const _CabinLayout(letters: ['A','B','C','D','E','F'], aisleAfter: {2}, rows: 10, descriptionTh: '3-3 ที่นั่งมาตรฐาน', icon: Icons.airline_seat_recline_normal, seatAspect: 1.05),
        CabinClass.premiumEconomy => const _CabinLayout(letters: ['A','B','C','D','E','F','G'], aisleAfter: {1,4}, rows: 7, descriptionTh: '2-3-2 พื้นที่กว้างขึ้น', icon: Icons.airline_seat_legroom_extra, seatAspect: .92),
        CabinClass.business => const _CabinLayout(letters: ['A','C','D','F'], aisleAfter: {1}, rows: 5, descriptionTh: '2-2 เบาะกว้างและระยะห่างมาก', icon: Icons.event_seat, seatAspect: .82),
        CabinClass.first => const _CabinLayout(letters: ['A','F'], aisleAfter: {0}, rows: 3, descriptionTh: '1-1 ห้องโดยสารแบบ Suite', icon: Icons.chair_alt, seatAspect: .72),
      };
}

class _CabinMap extends StatelessWidget {
  const _CabinMap({required this.layout, required this.selected, required this.unavailable, required this.onSeat});
  final _CabinLayout layout;
  final Set<String> selected;
  final Set<String> unavailable;
  final ValueChanged<String> onSeat;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 28),
            for (int i = 0; i < layout.letters.length; i++) ...[
              Expanded(child: Center(child: Text(layout.letters[i]))),
              if (layout.aisleAfter.contains(i)) const SizedBox(width: 24) else if (i != layout.letters.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 8),
        for (int row = 1; row <= layout.rows; row++) ...[
          Row(
            children: [
              SizedBox(width: 28, child: Text('$row', textAlign: TextAlign.center)),
              for (int i = 0; i < layout.letters.length; i++) ...[
                Expanded(
                  child: _Seat(
                    id: '$row${layout.letters[i]}',
                    selected: selected.contains('$row${layout.letters[i]}'),
                    unavailable: unavailable.contains('$row${layout.letters[i]}'),
                    onTap: () => onSeat('$row${layout.letters[i]}'),
                    aspect: layout.seatAspect,
                  ),
                ),
                if (layout.aisleAfter.contains(i)) const SizedBox(width: 24) else if (i != layout.letters.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({required this.id, required this.selected, required this.unavailable, required this.onTap, required this.aspect});
  final String id;
  final bool selected;
  final bool unavailable;
  final VoidCallback onTap;
  final double aspect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg = unavailable ? Colors.grey.shade500 : selected ? colors.primary : colors.surfaceContainerHighest;
    final fg = unavailable || selected ? Colors.white : colors.onSurface;
    return AspectRatio(
      aspectRatio: aspect,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: unavailable ? null : onTap,
          child: Center(child: Text(id, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800))),
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
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 18, height: 18, decoration: BoxDecoration(color: color, border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(5))),
          const SizedBox(width: 5),
          Text(text),
        ],
      );
}

String _cabin(String lang, CabinClass c) => switch (c) {
      CabinClass.economy => tr(lang, 'economy'),
      CabinClass.premiumEconomy => tr(lang, 'premium_economy'),
      CabinClass.business => tr(lang, 'business'),
      CabinClass.first => tr(lang, 'first'),
    };
