import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final Set<String> selected = <String>{};

  Set<String> get unavailable => switch (widget.cabinClass) {
        CabinClass.economy => {
            '1B',
            '2D',
            '3C',
            '5A',
            '6F',
            '8E',
            '9B',
          },
        CabinClass.premiumEconomy => {
            '1C',
            '2F',
            '4A',
            '5E',
          },
        CabinClass.business => {
            '1D',
            '3A',
          },
        CabinClass.first => {
            '2F',
          },
      };

  int get requiredSeats => widget.passengers.length;
  bool get canContinue => requiredSeats > 0 && selected.length == requiredSeats;
  double get seatTotal => selected.length * widget.cabinClass.seatFee;

  void _toggle(String id) {
    if (unavailable.contains(id)) return;

    HapticFeedback.selectionClick();

    setState(() {
      if (selected.remove(id)) return;

      if (selected.length < requiredSeats) {
        selected.add(id);
        return;
      }

      if (requiredSeats == 1 && selected.isNotEmpty) {
        selected
          ..clear()
          ..add(id);
      }
    });
  }

  void _continueToPayment() {
    if (!canContinue) return;

    HapticFeedback.lightImpact();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          flight: widget.flight,
          cabinClass: widget.cabinClass,
          passengers: widget.passengers,
          seats: selected.toList()..sort(),
        ),
      ),
    );
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
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
              children: [
                _FlightHeaderCard(
                  flight: widget.flight,
                  cabinClass: widget.cabinClass,
                  layout: layout,
                  lang: lang,
                  palette: palette,
                ),
                const SizedBox(height: 18),
                _ProgressCard(
                  selectedCount: selected.length,
                  requiredSeats: requiredSeats,
                  palette: palette,
                  lang: lang,
                ),
                const SizedBox(height: 18),
                _SeatLegend(
                  palette: palette,
                  lang: lang,
                ),
                const SizedBox(height: 22),
                _FrontIndicator(
                  palette: palette,
                  lang: lang,
                ),
                const SizedBox(height: 16),
                _CabinInfoCard(
                  cabinClass: widget.cabinClass,
                  layout: layout,
                  palette: palette,
                  lang: lang,
                ),
                const SizedBox(height: 16),
                _CabinMapCard(
                  layout: layout,
                  selected: selected,
                  unavailable: unavailable,
                  onSeat: _toggle,
                  palette: palette,
                  lang: lang,
                ),
              ],
            ),
          ),
          _BottomSummary(
            selected: selected,
            requiredSeats: requiredSeats,
            seatTotal: seatTotal,
            canContinue: canContinue,
            palette: palette,
            lang: lang,
            onContinue: _continueToPayment,
          ),
        ],
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
  });

  final FlightEntity flight;
  final CabinClass cabinClass;
  final _CabinLayout layout;
  final String lang;
  final _CabinPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.heroStart, palette.heroEnd],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: palette.heroEnd.withValues(alpha: .24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -32,
            top: -46,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .07),
              ),
            ),
          ),
          Positioned(
            right: 36,
            bottom: -64,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            flight.departure.code,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .5,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white70,
                              size: 22,
                            ),
                          ),
                          Text(
                            flight.arrival.code,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_cabin(lang, cabinClass)} · ${layout.description(lang)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: .86),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .18),
                          ),
                        ),
                        child: Text(
                          '${flight.airline} · ${flight.flightNumber}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .22),
                    ),
                  ),
                  child: const Icon(
                    Icons.flight_takeoff_rounded,
                    color: Colors.white,
                    size: 31,
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.selectedCount,
    required this.requiredSeats,
    required this.palette,
    required this.lang,
  });

  final int selectedCount;
  final int requiredSeats;
  final _CabinPalette palette;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = requiredSeats == 0
        ? 0.0
        : (selectedCount / requiredSeats).clamp(0.0, 1.0).toDouble();
    final done = requiredSeats > 0 && selectedCount == requiredSeats;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              done ? Icons.check_rounded : Icons.person_outline_rounded,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        done
                            ? (lang == 'th' ? 'เลือกที่นั่งครบแล้ว' : 'Seats selected')
                            : (lang == 'th' ? 'เลือกที่นั่งสำหรับผู้โดยสาร' : 'Choose passenger seats'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '$selectedCount / $requiredSeats',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: palette.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: palette.accent,
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
  const _SeatLegend({
    required this.palette,
    required this.lang,
  });

  final _CabinPalette palette;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        _LegendPill(
          fill: theme.colorScheme.surface,
          border: theme.colorScheme.outlineVariant,
          text: tr(lang, 'available'),
        ),
        _LegendPill(
          fill: palette.accent,
          border: palette.accent,
          text: tr(lang, 'selected'),
          foreground: Colors.white,
        ),
        _LegendPill(
          fill: theme.brightness == Brightness.dark
              ? const Color(0xFF4D535F)
              : const Color(0xFFB8BEC8),
          border: Colors.transparent,
          text: tr(lang, 'unavailable'),
          foreground: Colors.white,
        ),
      ],
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({
    required this.fill,
    required this.border,
    required this.text,
    this.foreground,
  });

  final Color fill;
  final Color border;
  final String text;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: border),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground == null ? null : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrontIndicator extends StatelessWidget {
  const _FrontIndicator({
    required this.palette,
    required this.lang,
  });

  final _CabinPalette palette;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: palette.soft,
            shape: BoxShape.circle,
            border: Border.all(color: palette.accent.withValues(alpha: .16)),
          ),
          child: Icon(
            Icons.flight_rounded,
            size: 34,
            color: palette.accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(lang, 'front'),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CabinInfoCard extends StatelessWidget {
  const _CabinInfoCard({
    required this.cabinClass,
    required this.layout,
    required this.palette,
    required this.lang,
  });

  final CabinClass cabinClass;
  final _CabinLayout layout;
  final _CabinPalette palette;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.accent.withValues(alpha: .14)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: .88),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(layout.icon, color: palette.accent, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  layout.description(lang),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lang == 'th'
                      ? 'ค่าที่นั่ง ${cabinClass.seatFee.toStringAsFixed(0)} บาท / ที่'
                      : 'Seat fee ${cabinClass.seatFee.toStringAsFixed(0)} THB / seat',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.info_outline_rounded,
            color: palette.accent.withValues(alpha: .72),
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _CabinMapCard extends StatelessWidget {
  const _CabinMapCard({
    required this.layout,
    required this.selected,
    required this.unavailable,
    required this.onSeat,
    required this.palette,
    required this.lang,
  });

  final _CabinLayout layout;
  final Set<String> selected;
  final Set<String> unavailable;
  final ValueChanged<String> onSeat;
  final _CabinPalette palette;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? .12 : .04,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Icon(Icons.airline_seat_recline_normal_rounded,
                    color: palette.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  lang == 'th' ? 'ผังที่นั่ง' : 'Seat map',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  layout.pattern,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _CabinMap(
            layout: layout,
            selected: selected,
            unavailable: unavailable,
            onSeat: onSeat,
            palette: palette,
          ),
        ],
      ),
    );
  }
}

class _CabinMap extends StatelessWidget {
  const _CabinMap({
    required this.layout,
    required this.selected,
    required this.unavailable,
    required this.onSeat,
    required this.palette,
  });

  final _CabinLayout layout;
  final Set<String> selected;
  final Set<String> unavailable;
  final ValueChanged<String> onSeat;
  final _CabinPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapWidth = math.max(constraints.maxWidth, layout.minMapWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: mapWidth,
            child: Column(
              children: [
                _ColumnHeader(layout: layout),
                const SizedBox(height: 9),
                for (int row = 1; row <= layout.rows; row++) ...[
                  _SeatRow(
                    row: row,
                    layout: layout,
                    selected: selected,
                    unavailable: unavailable,
                    onSeat: onSeat,
                    palette: palette,
                  ),
                  if (row != layout.rows) const SizedBox(height: 9),
                ],
              ],
            ),
          ),
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
        const SizedBox(width: 32),
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
            const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _SeatRow extends StatelessWidget {
  const _SeatRow({
    required this.row,
    required this.layout,
    required this.selected,
    required this.unavailable,
    required this.onSeat,
    required this.palette,
  });

  final int row;
  final _CabinLayout layout;
  final Set<String> selected;
  final Set<String> unavailable;
  final ValueChanged<String> onSeat;
  final _CabinPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$row',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        for (int i = 0; i < layout.letters.length; i++) ...[
          Expanded(
            child: _Seat(
              id: '$row${layout.letters[i]}',
              selected: selected.contains('$row${layout.letters[i]}'),
              unavailable: unavailable.contains('$row${layout.letters[i]}'),
              onTap: () => onSeat('$row${layout.letters[i]}'),
              height: layout.seatHeight,
              radius: layout.seatRadius,
              palette: palette,
            ),
          ),
          if (layout.aisleAfter.contains(i))
            SizedBox(width: layout.aisleWidth)
          else if (i != layout.letters.length - 1)
            const SizedBox(width: 6),
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
    required this.height,
    required this.radius,
    required this.palette,
  });

  final String id;
  final bool selected;
  final bool unavailable;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final _CabinPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color background;
    final Color foreground;
    final Color border;

    if (unavailable) {
      background = theme.brightness == Brightness.dark
          ? const Color(0xFF4C515C)
          : const Color(0xFFB7BDC7);
      foreground = Colors.white.withValues(alpha: .88);
      border = Colors.transparent;
    } else if (selected) {
      background = palette.accent;
      foreground = Colors.white;
      border = palette.accent;
    } else {
      background = theme.colorScheme.surface;
      foreground = theme.colorScheme.onSurface;
      border = theme.colorScheme.outlineVariant;
    }

    return Semantics(
      button: true,
      enabled: !unavailable,
      selected: selected,
      label: 'Seat $id',
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: selected ? .96 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: height,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: border,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: unavailable
                ? null
                : [
                    BoxShadow(
                      color: selected
                          ? palette.accent.withValues(alpha: .22)
                          : Colors.black.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? .10
                                  : .045,
                            ),
                      blurRadius: selected ? 12 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: unavailable ? null : onTap,
              borderRadius: BorderRadius.circular(radius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (unavailable)
                    Center(
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: .18),
                        size: height * .65,
                      ),
                    ),
                  Center(
                    child: Text(
                      id,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .1,
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.accent.withValues(alpha: .18),
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: palette.accent,
                          size: 10,
                        ),
                      ),
                    ),
                ],
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
    required this.selected,
    required this.requiredSeats,
    required this.seatTotal,
    required this.canContinue,
    required this.palette,
    required this.lang,
    required this.onContinue,
  });

  final Set<String> selected;
  final int requiredSeats;
  final double seatTotal;
  final bool canContinue;
  final _CabinPalette palette;
  final String lang;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedSeats = selected.toList()..sort();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? .22 : .08,
              ),
              blurRadius: 24,
              offset: const Offset(0, -7),
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
                      Text(
                        selected.isEmpty
                            ? tr(lang, 'please_select')
                            : tr(lang, 'selected_seats'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        selected.isEmpty
                            ? '0 / $requiredSeats'
                            : '${sortedSeats.join(', ')}  ·  ${selected.length}/$requiredSeats',
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
                      lang == 'th' ? 'ค่าที่นั่ง' : 'Seat fee',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '฿${seatTotal.toStringAsFixed(0)}',
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
              height: 56,
              child: FilledButton.icon(
                onPressed: canContinue ? onContinue : null,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  disabledForegroundColor: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: .55),
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
                      : '${tr(lang, 'select_seat')} ${selected.length}/$requiredSeats',
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

class _CabinLayout {
  const _CabinLayout({
    required this.letters,
    required this.aisleAfter,
    required this.rows,
    required this.descriptionTh,
    required this.descriptionEn,
    required this.icon,
    required this.pattern,
    required this.minMapWidth,
    required this.seatHeight,
    required this.seatRadius,
    required this.aisleWidth,
  });

  final List<String> letters;
  final Set<int> aisleAfter;
  final int rows;
  final String descriptionTh;
  final String descriptionEn;
  final IconData icon;
  final String pattern;
  final double minMapWidth;
  final double seatHeight;
  final double seatRadius;
  final double aisleWidth;

  String description(String lang) =>
      lang == 'th' ? descriptionTh : descriptionEn;

  static _CabinLayout forClass(CabinClass cabinClass) => switch (cabinClass) {
        CabinClass.economy => const _CabinLayout(
            letters: ['A', 'B', 'C', 'D', 'E', 'F'],
            aisleAfter: {2},
            rows: 10,
            descriptionTh: '3-3 ที่นั่งมาตรฐาน',
            descriptionEn: '3-3 standard seating',
            icon: Icons.airline_seat_recline_normal_rounded,
            pattern: '3 · 3',
            minMapWidth: 330,
            seatHeight: 48,
            seatRadius: 14,
            aisleWidth: 22,
          ),
        CabinClass.premiumEconomy => const _CabinLayout(
            letters: ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
            aisleAfter: {1, 4},
            rows: 7,
            descriptionTh: '2-3-2 พื้นที่กว้างขึ้น',
            descriptionEn: '2-3-2 extra space',
            icon: Icons.airline_seat_legroom_extra_rounded,
            pattern: '2 · 3 · 2',
            minMapWidth: 430,
            seatHeight: 52,
            seatRadius: 15,
            aisleWidth: 20,
          ),
        CabinClass.business => const _CabinLayout(
            letters: ['A', 'C', 'D', 'F'],
            aisleAfter: {1},
            rows: 5,
            descriptionTh: '2-2 เบาะกว้างและระยะห่างมาก',
            descriptionEn: '2-2 wider seats and more space',
            icon: Icons.event_seat_rounded,
            pattern: '2 · 2',
            minMapWidth: 330,
            seatHeight: 62,
            seatRadius: 18,
            aisleWidth: 36,
          ),
        CabinClass.first => const _CabinLayout(
            letters: ['A', 'F'],
            aisleAfter: {0},
            rows: 3,
            descriptionTh: '1-1 ห้องโดยสารแบบ Suite',
            descriptionEn: '1-1 private suite seating',
            icon: Icons.chair_alt_rounded,
            pattern: '1 · 1',
            minMapWidth: 300,
            seatHeight: 78,
            seatRadius: 22,
            aisleWidth: 64,
          ),
      };
}

class _CabinPalette {
  const _CabinPalette({
    required this.accent,
    required this.soft,
    required this.heroStart,
    required this.heroEnd,
  });

  final Color accent;
  final Color soft;
  final Color heroStart;
  final Color heroEnd;

  static _CabinPalette forClass(
    CabinClass cabinClass,
    Brightness brightness,
  ) {
    final dark = brightness == Brightness.dark;

    return switch (cabinClass) {
      CabinClass.economy => _CabinPalette(
          accent: dark ? const Color(0xFF86AEF6) : const Color(0xFF2457A6),
          soft: dark ? const Color(0xFF17243A) : const Color(0xFFEEF4FF),
          heroStart: const Color(0xFF285DB4),
          heroEnd: const Color(0xFF12376F),
        ),
      CabinClass.premiumEconomy => _CabinPalette(
          accent: dark ? const Color(0xFF8ED6D0) : const Color(0xFF147D78),
          soft: dark ? const Color(0xFF142E2D) : const Color(0xFFEAF8F6),
          heroStart: const Color(0xFF168E86),
          heroEnd: const Color(0xFF0C4A56),
        ),
      CabinClass.business => _CabinPalette(
          accent: dark ? const Color(0xFFC0A4F7) : const Color(0xFF6442A8),
          soft: dark ? const Color(0xFF281F3B) : const Color(0xFFF2EDFB),
          heroStart: const Color(0xFF7650B8),
          heroEnd: const Color(0xFF3D2A70),
        ),
      CabinClass.first => _CabinPalette(
          accent: dark ? const Color(0xFFE6C779) : const Color(0xFF9A6C13),
          soft: dark ? const Color(0xFF332B18) : const Color(0xFFFFF7E3),
          heroStart: const Color(0xFFB28732),
          heroEnd: const Color(0xFF65450E),
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
