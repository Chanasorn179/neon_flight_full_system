import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../core/theme.dart';
import '../../models/entities.dart';
import '../../providers/booking_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/airline_logo.dart';
import '../../widgets/app_widgets.dart';
import 'payment_screen.dart';
import 'takeoff_screen.dart';

class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({
    super.key,
    required this.flight,
    required this.cabinClass,
    required this.passengers,
    this.returnFlight,
    this.outbound,
    this.outboundSeats = const [],
  });

  final FlightEntity flight;
  final CabinClass cabinClass;
  final List<PassengerEntity> passengers;

  /// Round trip, outbound step: the leg to pick seats for next.
  final FlightEntity? returnFlight;

  /// Round trip, return step: the outbound leg and its chosen seats.
  final FlightEntity? outbound;
  final List<String> outboundSeats;

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  /// Seat shown in the floating glass panel (last one picked).
  String? focusedSeat;

  /// Seat chosen for each passenger, in passenger order (null = not yet).
  late final List<String?> assigned = List<String?>.filled(
    widget.passengers.length,
    null,
  );

  /// Passenger whose seat the next tap sets.
  int active = 0;

  /// Seats held by other bookings on this departure.
  Set<String> taken = <String>{};

  @override
  void initState() {
    super.initState();
    _loadTakenSeats();
  }

  Future<void> _loadTakenSeats() async {
    try {
      final seats = await context.read<BookingProvider>().repository.takenSeats(
        widget.flight,
      );
      if (!mounted) return;
      setState(() {
        taken = seats;
        for (var i = 0; i < assigned.length; i++) {
          if (seats.contains(assigned[i])) assigned[i] = null;
        }
      });
    } catch (_) {
      // Keep the demo layout; the booking itself still enforces seat locks.
    }
  }

  Set<String> get unavailable => {...taken, ..._demoOccupied};

  /// Pre-booked seats so the demo cabin never looks empty.
  Set<String> get _demoOccupied => switch (widget.cabinClass) {
    CabinClass.economy => {'1B', '2D', '3C', '5A', '6F', '8E', '9B'},
    CabinClass.premiumEconomy => {'1C', '2F', '4A', '5E'},
    CabinClass.business => {'1D', '3A'},
    CabinClass.first => {'2F'},
  };

  int get requiredSeats => widget.passengers.length;
  bool get canContinue =>
      requiredSeats > 0 && assigned.every((seat) => seat != null);
  double get seatTotal =>
      assigned.whereType<String>().length * widget.cabinClass.seatFee;

  Map<String, int> get _seatOwner => {
    for (var i = 0; i < assigned.length; i++)
      if (assigned[i] != null) assigned[i]!: i,
  };

  /// Tapping a free seat gives it to the active passenger (moving them if they
  /// already had one) and moves on to the next passenger without a seat.
  /// Tapping a taken-by-us seat frees it and makes its passenger active.
  void _tapSeat(String id) {
    if (unavailable.contains(id)) return;

    HapticFeedback.selectionClick();

    setState(() {
      final owner = assigned.indexOf(id);
      if (owner != -1) {
        assigned[owner] = null;
        active = owner;
        focusedSeat = null;
        return;
      }
      assigned[active] = id;
      focusedSeat = id;
      final next = assigned.indexWhere((seat) => seat == null);
      if (next != -1) active = next;
    });
    if (canContinue) HapticFeedback.mediumImpact();
  }

  Future<void> _continueToPayment() async {
    if (!canContinue) return;

    HapticFeedback.lightImpact();

    // Passenger order, so seat i belongs to passenger i.
    final seats = assigned.whereType<String>().toList();
    final Widget next;
    if (widget.returnFlight != null) {
      next = SeatSelectionScreen(
        flight: widget.returnFlight!,
        cabinClass: widget.cabinClass,
        passengers: widget.passengers,
        outbound: widget.flight,
        outboundSeats: seats,
      );
    } else if (widget.outbound != null) {
      next = PaymentScreen(
        flight: widget.outbound!,
        cabinClass: widget.cabinClass,
        passengers: widget.passengers,
        seats: widget.outboundSeats,
        returnFlight: widget.flight,
        returnSeats: seats,
      );
    } else {
      next = PaymentScreen(
        flight: widget.flight,
        cabinClass: widget.cabinClass,
        passengers: widget.passengers,
        seats: seats,
      );
    }
    final toPayment = widget.returnFlight == null;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => toPayment
            ? TakeoffScreen(flight: widget.flight, seats: seats, next: next)
            : next,
      ),
    );
    // Back from payment (e.g. a seat was taken meanwhile): refresh the map.
    await _loadTakenSeats();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final layout = _CabinLayout.forClass(widget.cabinClass);
    final legLabel = widget.returnFlight != null
        ? tr(lang, 'outbound_flight')
        : widget.outbound != null
        ? tr(lang, 'return_flight')
        : null;

    // Always a night cabin, whatever the app theme.
    return Theme(
      data: AppTheme.dark,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            backgroundColor: _Focus.bg,
            body: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _NightBackdropPainter()),
                ),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _TopBar(
                        flight: widget.flight,
                        cabinClass: widget.cabinClass,
                        legLabel: legLabel,
                        lang: lang,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 260),
                          child: _TiltedFuselage(
                            lang: lang,
                            child: _CabinMap(
                              layout: layout,
                              seatOwner: _seatOwner,
                              unavailable: unavailable,
                              focused: focusedSeat,
                              showPassengerNumbers: requiredSeats > 1,
                              onSeat: _tapSeat,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(
                                  begin: const Offset(0, .15),
                                  end: Offset.zero,
                                ).animate(a),
                                child: child,
                              ),
                            ),
                            child: focusedSeat == null
                                ? _HintGlass(
                                    key: const ValueKey('hint'),
                                    text: trArgs(lang, 'choose_seat_for', {
                                      'name': _passengerName(active, lang),
                                    }),
                                  )
                                : _SeatGlass(
                                    key: ValueKey(focusedSeat),
                                    seat: focusedSeat!,
                                    kind: layout.kindOf(focusedSeat!),
                                    fee: widget.cabinClass.seatFee,
                                    passenger: _passengerName(
                                      _seatOwner[focusedSeat!] ?? active,
                                      lang,
                                    ),
                                    lang: lang,
                                  ),
                          ),
                          if (requiredSeats > 1) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 44,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: requiredSeats,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, i) => _PassengerPill(
                                  number: i + 1,
                                  name: _passengerName(i, lang),
                                  seat: assigned[i],
                                  active: i == active,
                                  onTap: () => setState(() {
                                    active = i;
                                    focusedSeat = assigned[i];
                                  }),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _ConfirmPill(
                            enabled: canContinue,
                            label: canContinue
                                ? '${tr(lang, 'confirm_seats')} · ${money(seatTotal)}'
                                : '${tr(lang, 'select_seat')} ${assigned.whereType<String>().length}/$requiredSeats',
                            onTap: _continueToPayment,
                            textStyle: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _passengerName(int i, String lang) {
    final p = widget.passengers[i];
    final name = p.firstName.trim();
    return name.isEmpty ? '${tr(lang, 'passenger')} ${i + 1}' : name;
  }
}

/// Night-cabin palette.
abstract final class _Focus {
  static const bg = Color(0xFF0A0D13);
  static const seat = Color(0xFF232833);
  static const seatEdge = Color(0xFF2F3542);
  static const seatTaken = Color(0xFF15181F);
  static const accent = Color(0xFF4C8DFF);
  static const text = Colors.white;
  static const muted = Color(0x99FFFFFF);
}

class _NightBackdropPainter extends CustomPainter {
  const _NightBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * .25),
          size.longestSide * .8,
          [const Color(0xFF16203A), _Focus.bg],
        ),
    );
    final dot = Paint()..color = Colors.white.withValues(alpha: .035);
    for (var y = 0.0; y < size.height; y += 22) {
      for (var x = (y ~/ 22).isEven ? 0.0 : 11.0; x < size.width; x += 22) {
        canvas.drawCircle(Offset(x, y), .9, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.flight,
    required this.cabinClass,
    required this.legLabel,
    required this.lang,
  });

  final FlightEntity flight;
  final CabinClass cabinClass;
  final String? legLabel;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: _Focus.text),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${flight.departure.code}  →  ${flight.arrival.code}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _Focus.text,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
                Text(
                  [
                    ?legLabel,
                    flight.flightNumber,
                    _cabin(lang, cabinClass),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _Focus.muted,
                  ),
                ),
              ],
            ),
          ),
          AirlineLogo(
            airlineName: flight.airline,
            flightNumber: flight.flightNumber,
            size: 36,
          ),
        ],
      ),
    );
  }
}

/// Glass fuselage seen from above at an angle: the nose recedes into the
/// distance, like looking down the cabin.
class _TiltedFuselage extends StatelessWidget {
  const _TiltedFuselage({required this.lang, required this.child});

  final String lang;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Transform(
      alignment: Alignment.topCenter,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .0007)
        ..rotateX(.28),
      child: LayoutBuilder(
        builder: (context, box) {
          final nose = box.maxWidth * .42;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: .10),
                  Colors.white.withValues(alpha: .04),
                ],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.elliptical(box.maxWidth / 2, nose),
                bottom: const Radius.circular(28),
              ),
              border: Border.all(color: Colors.white.withValues(alpha: .14)),
            ),
            padding: EdgeInsets.fromLTRB(12, nose * .45, 12, 22),
            child: Column(
              children: [
                // Cockpit windscreen.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final tilt in [-.22, -.07, .07, .22])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Transform.rotate(
                          angle: tilt,
                          child: Container(
                            width: 24,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .55),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .12),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  tr(lang, 'front'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _Focus.muted,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: nose * .18),
                child,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CabinMap extends StatelessWidget {
  const _CabinMap({
    required this.layout,
    required this.seatOwner,
    required this.unavailable,
    required this.focused,
    required this.showPassengerNumbers,
    required this.onSeat,
  });

  final _CabinLayout layout;
  final Map<String, int> seatOwner;
  final Set<String> unavailable;
  final String? focused;
  final bool showPassengerNumbers;
  final ValueChanged<String> onSeat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final letterStyle = theme.textTheme.labelMedium?.copyWith(
      color: _Focus.muted,
      fontWeight: FontWeight.w700,
    );

    Widget row(List<Widget> cells, {Widget? aisle}) {
      final children = <Widget>[];
      for (var i = 0; i < cells.length; i++) {
        children.add(Expanded(child: cells[i]));
        if (layout.aisleAfter.contains(i)) {
          children.add(
            SizedBox(
              width: layout.aisleWidth,
              child: Center(child: aisle),
            ),
          );
        } else if (i != cells.length - 1) {
          children.add(SizedBox(width: layout.seatGap));
        }
      }
      return Row(children: children);
    }

    return Column(
      children: [
        row([
          for (final l in layout.letters)
            Center(child: Text(l, style: letterStyle)),
        ]),
        const SizedBox(height: 8),
        for (var r = 1; r <= layout.rows; r++) ...[
          row(
            [
              for (final l in layout.letters)
                _Seat(
                  id: '$r$l',
                  owner: seatOwner['$r$l'],
                  unavailable: unavailable.contains('$r$l'),
                  focused: focused == '$r$l',
                  showPassengerNumber: showPassengerNumbers,
                  height: layout.seatHeight,
                  onTap: () => onSeat('$r$l'),
                ),
            ],
            aisle: Text(
              r.toString().padLeft(2, '0'),
              style: theme.textTheme.labelSmall?.copyWith(color: _Focus.muted),
            ),
          ),
          if (r != layout.rows) SizedBox(height: layout.rowGap),
        ],
      ],
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.id,
    required this.owner,
    required this.unavailable,
    required this.focused,
    required this.showPassengerNumber,
    required this.height,
    required this.onTap,
  });

  final String id;
  final int? owner;
  final bool unavailable;
  final bool focused;
  final bool showPassengerNumber;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = owner != null;
    final fill = unavailable
        ? _Focus.seatTaken
        : selected
        ? _Focus.accent
        : _Focus.seat;

    final Widget? label = unavailable
        ? Icon(
            Icons.close_rounded,
            size: 14,
            color: Colors.white.withValues(alpha: .18),
          )
        : selected
        ? (showPassengerNumber
              ? Text(
                  '${owner! + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 18, color: Colors.white))
        : null;

    return Semantics(
      button: true,
      enabled: !unavailable,
      selected: selected,
      label: 'Seat $id',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: unavailable ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: height,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: focused
                  ? Colors.white
                  : selected
                  ? _Focus.accent
                  : unavailable
                  ? Colors.transparent
                  : _Focus.seatEdge,
              width: focused ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _Focus.accent.withValues(alpha: .55),
                      blurRadius: 14,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Center(child: label),
        ),
      ),
    );
  }
}

/// Frosted panel that floats over the map.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: .16)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _HintGlass extends StatelessWidget {
  const _HintGlass({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.touch_app_rounded, color: _Focus.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _Focus.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatGlass extends StatelessWidget {
  const _SeatGlass({
    super.key,
    required this.seat,
    required this.kind,
    required this.fee,
    required this.passenger,
    required this.lang,
  });

  final String seat;
  final _SeatKind kind;
  final double fee;
  final String passenger;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, String key) = switch (kind) {
      _SeatKind.window => (Icons.window_rounded, 'seat_window'),
      _SeatKind.aisle => (Icons.swap_horiz_rounded, 'seat_aisle'),
      _SeatKind.middle => (Icons.event_seat_rounded, 'seat_middle'),
    };
    Widget chip(IconData i, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 15, color: _Focus.text),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(color: _Focus.text),
          ),
        ],
      ),
    );

    return _Glass(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _Focus.accent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _Focus.accent.withValues(alpha: .5),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Text(
              seat,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trArgs(lang, 'seat_for', {'seat': seat, 'name': passenger}),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _Focus.text,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    chip(icon, tr(lang, key)),
                    chip(
                      Icons.sell_outlined,
                      fee == 0 ? tr(lang, 'seat_included') : money(fee),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerPill extends StatelessWidget {
  const _PassengerPill({
    required this.number,
    required this.name,
    required this.seat,
    required this.active,
    required this.onTap,
  });

  final int number;
  final String name;
  final String? seat;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: .16)
                : Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? Colors.white70 : Colors.white24),
          ),
          child: Text(
            '$number  $name  ${seat ?? '—'}',
            style: TextStyle(
              color: _Focus.text,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmPill extends StatelessWidget {
  const _ConfirmPill({
    required this.enabled,
    required this.label,
    required this.onTap,
    required this.textStyle,
  });

  final bool enabled;
  final String label;
  final VoidCallback onTap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.white.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: enabled ? 1 : .18),
            ),
          ),
          child: Text(
            label,
            style: textStyle?.copyWith(
              color: enabled ? _Focus.bg : _Focus.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

enum _SeatKind { window, middle, aisle }

class _CabinLayout {
  const _CabinLayout({
    required this.letters,
    required this.aisleAfter,
    required this.rows,
    required this.seatHeight,
    required this.aisleWidth,
    required this.seatGap,
    required this.rowGap,
  });

  final List<String> letters;
  final Set<int> aisleAfter;
  final int rows;
  final double seatHeight;
  final double aisleWidth;
  final double seatGap;
  final double rowGap;

  _SeatKind kindOf(String seatId) {
    final letter = seatId.replaceAll(RegExp(r'\d'), '');
    final i = letters.indexOf(letter);
    if (i == 0 || i == letters.length - 1) return _SeatKind.window;
    if (aisleAfter.contains(i) || aisleAfter.contains(i - 1)) {
      return _SeatKind.aisle;
    }
    return _SeatKind.middle;
  }

  static _CabinLayout forClass(CabinClass cabinClass) => switch (cabinClass) {
    CabinClass.economy => const _CabinLayout(
      letters: ['A', 'B', 'C', 'D', 'E', 'F'],
      aisleAfter: {2},
      rows: 10,
      seatHeight: 40,
      aisleWidth: 30,
      seatGap: 6,
      rowGap: 9,
    ),
    CabinClass.premiumEconomy => const _CabinLayout(
      letters: ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
      aisleAfter: {1, 4},
      rows: 7,
      seatHeight: 44,
      aisleWidth: 24,
      seatGap: 5,
      rowGap: 11,
    ),
    CabinClass.business => const _CabinLayout(
      letters: ['A', 'C', 'D', 'F'],
      aisleAfter: {1},
      rows: 5,
      seatHeight: 58,
      aisleWidth: 44,
      seatGap: 10,
      rowGap: 16,
    ),
    CabinClass.first => const _CabinLayout(
      letters: ['A', 'F'],
      aisleAfter: {0},
      rows: 3,
      seatHeight: 76,
      aisleWidth: 90,
      seatGap: 10,
      rowGap: 20,
    ),
  };
}

String _cabin(String lang, CabinClass cabinClass) => switch (cabinClass) {
  CabinClass.economy => tr(lang, 'economy'),
  CabinClass.premiumEconomy => tr(lang, 'premium_economy'),
  CabinClass.business => tr(lang, 'business'),
  CabinClass.first => tr(lang, 'first'),
};
