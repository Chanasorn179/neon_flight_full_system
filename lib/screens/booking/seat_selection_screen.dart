import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../models/entities.dart';
import '../../providers/booking_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/airline_logo.dart';
import '../../widgets/app_widgets.dart';
import 'payment_screen.dart';

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

class _SeatSelectionScreenState extends State<SeatSelectionScreen>
    with SingleTickerProviderStateMixin {
  /// Plays the "plane takes off" flourish when the last seat is chosen.
  late final AnimationController _takeoff = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void dispose() {
    _takeoff.dispose();
    super.dispose();
  }

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
    final wasComplete = canContinue;

    setState(() {
      final owner = assigned.indexOf(id);
      if (owner != -1) {
        assigned[owner] = null;
        active = owner;
        return;
      }
      assigned[active] = id;
      final next = assigned.indexWhere((seat) => seat == null);
      if (next != -1) active = next;
    });

    // Celebrate only the moment the selection becomes complete, and skip it
    // when the user asked the system to reduce motion.
    if (!wasComplete &&
        canContinue &&
        !MediaQuery.disableAnimationsOf(context)) {
      HapticFeedback.mediumImpact();
      _takeoff.forward(from: 0);
    }
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
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => next));
    // Back from payment (e.g. a seat was taken meanwhile): refresh the map.
    await _loadTakenSeats();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final theme = Theme.of(context);
    final layout = _CabinLayout.forClass(widget.cabinClass);
    final palette = _CabinPalette.forClass(widget.cabinClass, theme.brightness);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          tr(lang, 'select_seat'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _FlightHeaderCard(
                      flight: widget.flight,
                      cabinClass: widget.cabinClass,
                      layout: layout,
                      lang: lang,
                      palette: palette,
                      legLabel: widget.returnFlight != null
                          ? tr(lang, 'outbound_flight')
                          : widget.outbound != null
                          ? tr(lang, 'return_flight')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _SeatLegend(palette: palette, lang: lang),
                    const SizedBox(height: 14),
                    _Fuselage(
                      lang: lang,
                      palette: palette,
                      child: _CabinMap(
                        layout: layout,
                        seatOwner: _seatOwner,
                        unavailable: unavailable,
                        showPassengerNumbers: requiredSeats > 1,
                        onSeat: _tapSeat,
                        palette: palette,
                      ),
                    ),
                  ],
                ),
              ),
              _BottomSummary(
                passengers: widget.passengers,
                assigned: assigned,
                active: active,
                onPassenger: (i) => setState(() => active = i),
                seatTotal: seatTotal,
                canContinue: canContinue,
                palette: palette,
                lang: lang,
                onContinue: _continueToPayment,
              ),
            ],
          ),
          Positioned.fill(
            child: _TakeoffOverlay(animation: _takeoff, color: palette.accent),
          ),
        ],
      ),
    );
  }
}

/// A plane climbing from the bottom of the screen to the top with a fading
/// contrail. Purely decorative: it ignores touches and hides from screen
/// readers.
class _TakeoffOverlay extends StatelessWidget {
  const _TakeoffOverlay({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            if (t == 0 || t == 1) return const SizedBox.shrink();
            return LayoutBuilder(
              builder: (context, box) {
                const planeSize = 72.0;
                const trail = 220.0;
                final climb = Curves.easeInOutSine.transform(t);
                // From below the bottom edge to above the top edge.
                final y =
                    box.maxHeight +
                    planeSize -
                    climb * (box.maxHeight + planeSize * 2 + trail);
                // A gentle S-curve so it reads as flying, not sliding.
                final sway = math.sin(t * math.pi * 2) * 26;
                final x = box.maxWidth / 2 - planeSize / 2 + sway;
                final tilt = math.cos(t * math.pi * 2) * .12;
                final fade = t < .12
                    ? t / .12
                    : (t > .88 ? (1 - t) / .12 : 1.0);

                return Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: Stack(
                    children: [
                      // Contrail.
                      Positioned(
                        left: x + planeSize / 2 - 3,
                        top: y + planeSize * .7,
                        child: Container(
                          width: 6,
                          height: trail,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withValues(alpha: .45),
                                color.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: x,
                        top: y,
                        child: Transform.rotate(
                          angle: tilt,
                          child: Container(
                            width: planeSize,
                            height: planeSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: .14),
                            ),
                            child: Icon(
                              Icons.flight_rounded,
                              size: 52,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FlightHeaderCard extends StatelessWidget {
  const _FlightHeaderCard({
    required this.flight,
    required this.cabinClass,
    required this.layout,
    required this.lang,
    required this.palette,
    this.legLabel,
  });

  final FlightEntity flight;
  final CabinClass cabinClass;
  final _CabinLayout layout;
  final String lang;
  final _CabinPalette palette;

  /// "Outbound flight" / "Return flight" on a round trip.
  final String? legLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onHero = Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.heroStart, palette.heroEnd],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          AirlineLogo(
            airlineName: flight.airline,
            flightNumber: flight.flightNumber,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (legLabel != null)
                  Text(
                    legLabel!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: onHero.withValues(alpha: .85),
                    ),
                  ),
                Row(
                  children: [
                    Text(
                      flight.departure.code,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: onHero,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: onHero,
                        size: 18,
                      ),
                    ),
                    Text(
                      flight.arrival.code,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: onHero,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${flight.flightNumber} · ${_cabin(lang, cabinClass)} · ${layout.pattern}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onHero.withValues(alpha: .88),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  tr(lang, 'seat_fee'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: onHero.withValues(alpha: .85),
                  ),
                ),
                Text(
                  money(cabinClass.seatFee),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: onHero,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatLegend extends StatelessWidget {
  const _SeatLegend({required this.palette, required this.lang});

  final _CabinPalette palette;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 8,
      children: [
        _LegendItem(
          seat: _SeatLook(
            fill: colors.surfaceContainerLowest,
            border: colors.outline,
            foreground: colors.onSurface,
          ),
          text: tr(lang, 'available'),
        ),
        _LegendItem(
          seat: _SeatLook(
            fill: palette.accent,
            border: palette.accent,
            foreground: palette.onAccent,
          ),
          text: tr(lang, 'selected'),
        ),
        _LegendItem(
          seat: _SeatLook.unavailable(colors),
          text: tr(lang, 'unavailable'),
          icon: Icons.close_rounded,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.seat, required this.text, this.icon});

  final _SeatLook seat;
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 22,
          child: _SeatShape(
            look: seat,
            radius: 7,
            child: icon == null
                ? null
                : Icon(icon, size: 12, color: seat.foreground),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Aircraft body: a rounded nose with cockpit windows, then the cabin.
class _Fuselage extends StatelessWidget {
  const _Fuselage({
    required this.lang,
    required this.palette,
    required this.child,
  });

  final String lang;
  final _CabinPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final noseHeight = constraints.maxWidth * .34;
        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(
              top: Radius.elliptical(constraints.maxWidth / 2, noseHeight),
              bottom: const Radius.circular(30),
            ),
            border: Border.all(color: colors.outlineVariant, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? .25 : .06,
                ),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(10, noseHeight * .42, 10, 20),
          child: Column(
            children: [
              // Cockpit windows.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final tilt in [-.18, -.06, .06, .18])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Transform.rotate(
                        angle: tilt,
                        child: Container(
                          width: 22,
                          height: 11,
                          decoration: BoxDecoration(
                            color: palette.accent.withValues(alpha: .28),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  Text(
                    tr(lang, 'front'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: noseHeight * .22),
              child,
            ],
          ),
        );
      },
    );
  }
}

class _CabinMap extends StatelessWidget {
  const _CabinMap({
    required this.layout,
    required this.seatOwner,
    required this.unavailable,
    required this.showPassengerNumbers,
    required this.onSeat,
    required this.palette,
  });

  final _CabinLayout layout;

  /// Seat id -> index of the passenger sitting there.
  final Map<String, int> seatOwner;
  final Set<String> unavailable;
  final bool showPassengerNumbers;
  final ValueChanged<String> onSeat;
  final _CabinPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapWidth = math.max(constraints.maxWidth, layout.minMapWidth);
        final map = SizedBox(
          width: mapWidth,
          child: Column(
            children: [
              _ColumnHeader(layout: layout),
              const SizedBox(height: 8),
              for (int row = 1; row <= layout.rows; row++) ...[
                _SeatRow(
                  row: row,
                  layout: layout,
                  seatOwner: seatOwner,
                  unavailable: unavailable,
                  showPassengerNumbers: showPassengerNumbers,
                  onSeat: onSeat,
                  palette: palette,
                ),
                if (row != layout.rows) SizedBox(height: layout.rowGap),
              ],
            ],
          ),
        );
        // Only very narrow screens need to pan sideways.
        if (mapWidth <= constraints.maxWidth) return map;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: map,
        );
      },
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.layout});

  final _CabinLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const SizedBox(width: _windowGutter),
        for (int i = 0; i < layout.letters.length; i++) ...[
          Expanded(
            child: Center(
              child: Text(
                layout.letters[i],
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (layout.aisleAfter.contains(i))
            SizedBox(width: layout.aisleWidth)
          else if (i != layout.letters.length - 1)
            SizedBox(width: layout.seatGap),
        ],
        const SizedBox(width: _windowGutter),
      ],
    );
  }
}

const double _windowGutter = 14;

class _SeatRow extends StatelessWidget {
  const _SeatRow({
    required this.row,
    required this.layout,
    required this.seatOwner,
    required this.unavailable,
    required this.showPassengerNumbers,
    required this.onSeat,
    required this.palette,
  });

  final int row;
  final _CabinLayout layout;
  final Map<String, int> seatOwner;
  final Set<String> unavailable;
  final bool showPassengerNumbers;
  final ValueChanged<String> onSeat;
  final _CabinPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final window = Container(
      width: 4,
      height: layout.seatHeight * .42,
      decoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(4),
      ),
    );

    return Row(
      children: [
        SizedBox(
          width: _windowGutter,
          child: Align(alignment: Alignment.centerLeft, child: window),
        ),
        for (int i = 0; i < layout.letters.length; i++) ...[
          Expanded(
            child: _Seat(
              id: '$row${layout.letters[i]}',
              owner: seatOwner['$row${layout.letters[i]}'],
              unavailable: unavailable.contains('$row${layout.letters[i]}'),
              showPassengerNumber: showPassengerNumbers,
              onTap: () => onSeat('$row${layout.letters[i]}'),
              height: layout.seatHeight,
              radius: layout.seatRadius,
              palette: palette,
            ),
          ),
          if (layout.aisleAfter.contains(i))
            SizedBox(
              width: layout.aisleWidth,
              child: Center(
                // Row number lives in the aisle, like real cabin signage.
                child: Text(
                  '$row',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          else if (i != layout.letters.length - 1)
            SizedBox(width: layout.seatGap),
        ],
        SizedBox(
          width: _windowGutter,
          child: Align(alignment: Alignment.centerRight, child: window),
        ),
      ],
    );
  }
}

/// Colours of one seat state.
class _SeatLook {
  const _SeatLook({
    required this.fill,
    required this.border,
    required this.foreground,
  });

  factory _SeatLook.unavailable(ColorScheme colors) => _SeatLook(
    fill: colors.surfaceContainerHighest,
    border: colors.surfaceContainerHighest,
    foreground: colors.onSurfaceVariant.withValues(alpha: .7),
  );

  final Color fill;
  final Color border;
  final Color foreground;
}

/// A seat seen from above: backrest bar on top, cushion below.
class _SeatShape extends StatelessWidget {
  const _SeatShape({required this.look, required this.radius, this.child});

  final _SeatLook look;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: look.fill,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(radius),
          bottom: Radius.circular(radius * .55),
        ),
        border: Border.all(color: look.border, width: 1.2),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 3,
            left: 4,
            right: 4,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: look.foreground.withValues(alpha: .22),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.id,
    required this.owner,
    required this.unavailable,
    required this.showPassengerNumber,
    required this.onTap,
    required this.height,
    required this.radius,
    required this.palette,
  });

  final String id;

  /// Index of the passenger in this seat, if any.
  final int? owner;
  final bool unavailable;
  final bool showPassengerNumber;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final _CabinPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = owner != null;

    final look = unavailable
        ? _SeatLook.unavailable(colors)
        : selected
        ? _SeatLook(
            fill: palette.accent,
            border: palette.accent,
            foreground: palette.onAccent,
          )
        : _SeatLook(
            fill: colors.surfaceContainerLowest,
            border: colors.outline.withValues(alpha: .55),
            foreground: colors.onSurface,
          );

    final Widget label;
    if (unavailable) {
      label = Icon(Icons.close_rounded, size: 16, color: look.foreground);
    } else if (selected && showPassengerNumber) {
      label = Text(
        '${owner! + 1}',
        style: theme.textTheme.titleSmall?.copyWith(
          color: look.foreground,
          fontWeight: FontWeight.w900,
        ),
      );
    } else if (selected) {
      label = Icon(Icons.check_rounded, size: 20, color: look.foreground);
    } else {
      label = Text(
        id,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: !unavailable,
      selected: selected,
      label: 'Seat $id',
      excludeSemantics: true,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        scale: selected ? 1.06 : 1,
        child: SizedBox(
          height: height,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: unavailable ? null : onTap,
              borderRadius: BorderRadius.circular(radius),
              child: _SeatShape(
                look: look,
                radius: radius,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Center(child: label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomSummary extends StatelessWidget {
  const _BottomSummary({
    required this.passengers,
    required this.assigned,
    required this.active,
    required this.onPassenger,
    required this.seatTotal,
    required this.canContinue,
    required this.palette,
    required this.lang,
    required this.onContinue,
  });

  final List<PassengerEntity> passengers;
  final List<String?> assigned;
  final int active;
  final ValueChanged<int> onPassenger;
  final double seatTotal;
  final bool canContinue;
  final _CabinPalette palette;
  final String lang;
  final VoidCallback onContinue;

  String _name(int i) {
    final p = passengers[i];
    final name = p.firstName.trim().isEmpty ? p.fullName : p.firstName;
    return name.trim().isEmpty ? '${tr(lang, 'passenger')} ${i + 1}' : name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chosen = assigned.whereType<String>().length;
    final total = passengers.length;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: colors.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? .25 : .08,
              ),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (total > 1) ...[
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: total,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _PassengerChip(
                    number: i + 1,
                    name: _name(i),
                    seat: assigned[i],
                    active: i == active,
                    palette: palette,
                    onTap: () => onPassenger(i),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canContinue
                            ? tr(lang, 'seats_done')
                            : trArgs(lang, 'choose_seat_for', {
                                'name': _name(active),
                              }),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chosen == 0
                            ? '0 / $total'
                            : '${assigned.whereType<String>().join(', ')}  ·  $chosen/$total',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      tr(lang, 'seat_fee'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      money(seatTotal),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: palette.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: canContinue ? onContinue : null,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.onAccent,
                  disabledBackgroundColor: colors.surfaceContainerHighest,
                  disabledForegroundColor: colors.onSurfaceVariant.withValues(
                    alpha: .7,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: Icon(
                  canContinue
                      ? Icons.arrow_forward_rounded
                      : Icons.event_seat_outlined,
                ),
                label: Text(
                  canContinue
                      ? tr(lang, 'continue')
                      : '${tr(lang, 'select_seat')} $chosen/$total',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassengerChip extends StatelessWidget {
  const _PassengerChip({
    required this.number,
    required this.name,
    required this.seat,
    required this.active,
    required this.palette,
    required this.onTap,
  });

  final int number;
  final String name;
  final String? seat;
  final bool active;
  final _CabinPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasSeat = seat != null;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? palette.soft : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: active ? palette.accent : colors.outlineVariant,
            width: active ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: hasSeat
                      ? palette.accent
                      : colors.surfaceContainerHighest,
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: hasSeat
                          ? palette.onAccent
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  seat ?? '—',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: hasSeat ? palette.accent : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
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

class _CabinLayout {
  const _CabinLayout({
    required this.letters,
    required this.aisleAfter,
    required this.rows,
    required this.pattern,
    required this.minMapWidth,
    required this.seatHeight,
    required this.seatRadius,
    required this.aisleWidth,
    required this.seatGap,
    required this.rowGap,
  });

  final List<String> letters;
  final Set<int> aisleAfter;
  final int rows;
  final String pattern;
  final double minMapWidth;
  final double seatHeight;
  final double seatRadius;
  final double aisleWidth;
  final double seatGap;
  final double rowGap;

  static _CabinLayout forClass(CabinClass cabinClass) => switch (cabinClass) {
    CabinClass.economy => const _CabinLayout(
      letters: ['A', 'B', 'C', 'D', 'E', 'F'],
      aisleAfter: {2},
      rows: 10,
      pattern: '3-3',
      minMapWidth: 300,
      seatHeight: 46,
      seatRadius: 12,
      aisleWidth: 30,
      seatGap: 5,
      rowGap: 8,
    ),
    CabinClass.premiumEconomy => const _CabinLayout(
      letters: ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
      aisleAfter: {1, 4},
      rows: 7,
      pattern: '2-3-2',
      minMapWidth: 320,
      seatHeight: 50,
      seatRadius: 13,
      aisleWidth: 26,
      seatGap: 4,
      rowGap: 10,
    ),
    CabinClass.business => const _CabinLayout(
      letters: ['A', 'C', 'D', 'F'],
      aisleAfter: {1},
      rows: 5,
      pattern: '2-2',
      minMapWidth: 280,
      seatHeight: 62,
      seatRadius: 16,
      aisleWidth: 44,
      seatGap: 8,
      rowGap: 14,
    ),
    CabinClass.first => const _CabinLayout(
      letters: ['A', 'F'],
      aisleAfter: {0},
      rows: 3,
      pattern: '1-1',
      minMapWidth: 260,
      seatHeight: 80,
      seatRadius: 20,
      aisleWidth: 80,
      seatGap: 8,
      rowGap: 18,
    ),
  };
}

class _CabinPalette {
  const _CabinPalette({
    required this.accent,
    required this.onAccent,
    required this.soft,
    required this.heroStart,
    required this.heroEnd,
  });

  final Color accent;

  /// Text/icons on [accent]; dark in dark mode where the accent is light.
  final Color onAccent;
  final Color soft;
  final Color heroStart;
  final Color heroEnd;

  static _CabinPalette forClass(CabinClass cabinClass, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final onAccent = dark ? const Color(0xFF101418) : Colors.white;

    return switch (cabinClass) {
      CabinClass.economy => _CabinPalette(
        accent: dark ? const Color(0xFF8FB2FF) : const Color(0xFF1E5BD6),
        onAccent: onAccent,
        soft: dark ? const Color(0xFF17243A) : const Color(0xFFEAF1FF),
        heroStart: const Color(0xFF1E63DB),
        heroEnd: const Color(0xFF1846C2),
      ),
      CabinClass.premiumEconomy => _CabinPalette(
        accent: dark ? const Color(0xFF8ED6D0) : const Color(0xFF117A75),
        onAccent: onAccent,
        soft: dark ? const Color(0xFF142E2D) : const Color(0xFFE6F6F4),
        heroStart: const Color(0xFF168E86),
        heroEnd: const Color(0xFF0C4A56),
      ),
      CabinClass.business => _CabinPalette(
        accent: dark ? const Color(0xFFC6AEF8) : const Color(0xFF6442A8),
        onAccent: onAccent,
        soft: dark ? const Color(0xFF281F3B) : const Color(0xFFF1ECFB),
        heroStart: const Color(0xFF7650B8),
        heroEnd: const Color(0xFF3D2A70),
      ),
      CabinClass.first => _CabinPalette(
        accent: dark ? const Color(0xFFE6C779) : const Color(0xFF8A600F),
        onAccent: onAccent,
        soft: dark ? const Color(0xFF332B18) : const Color(0xFFFFF6E0),
        heroStart: const Color(0xFFA67B26),
        heroEnd: const Color(0xFF5E400D),
      ),
    };
  }
}

String _cabin(String lang, CabinClass cabinClass) => switch (cabinClass) {
  CabinClass.economy => tr(lang, 'economy'),
  CabinClass.premiumEconomy => tr(lang, 'premium_economy'),
  CabinClass.business => tr(lang, 'business'),
  CabinClass.first => tr(lang, 'first'),
};
