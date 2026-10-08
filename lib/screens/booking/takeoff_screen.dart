import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../data/fares.dart';
import '../../models/entities.dart';
import '../../providers/language_provider.dart';
import '../../widgets/airline_logo.dart';
import '../../widgets/app_widgets.dart';

/// Boarding moment between seat selection and payment: a tilted boarding
/// pass with "cabin doors closed", then the plane flies the real route on a
/// night map and the camera dives into the destination. Tap to skip.
class TakeoffScreen extends StatefulWidget {
  const TakeoffScreen({
    super.key,
    required this.flight,
    required this.seats,
    required this.next,
  });

  final FlightEntity flight;
  final List<String> seats;

  /// Screen shown when the animation ends (replaces this one).
  final Widget next;

  @override
  State<TakeoffScreen> createState() => _TakeoffScreenState();
}

class _TakeoffScreenState extends State<TakeoffScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 5200),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      });

  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _finish();
      } else {
        _c.forward();
      }
    });
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => widget.next,
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final f = widget.flight;

    return Scaffold(
      backgroundColor: const Color(0xFF070A10),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // 0.00–0.38 boarding pass · 0.30–1.00 route flight (crossfade).
            final passOpacity = (1 - ((t - .30) / .08)).clamp(0.0, 1.0);
            final mapOpacity = ((t - .30) / .08).clamp(0.0, 1.0);
            final flight = ((t - .36) / .64).clamp(0.0, 1.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                if (mapOpacity > 0)
                  Opacity(
                    opacity: mapOpacity,
                    child: CustomPaint(
                      painter: _RouteMapPainter(
                        from: f.departure.code,
                        to: f.arrival.code,
                        progress: flight,
                      ),
                    ),
                  ),
                if (passOpacity > 0)
                  Opacity(
                    opacity: passOpacity,
                    child: _BoardingMoment(
                      flight: f,
                      seats: widget.seats,
                      lang: lang,
                      t: (t / .30).clamp(0.0, 1.0),
                    ),
                  ),
                if (mapOpacity > 0)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 48,
                    child: Opacity(
                      opacity: mapOpacity,
                      child: _FlightStatus(
                        flight: f,
                        progress: flight,
                        lang: lang,
                      ),
                    ),
                  ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  right: 12,
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                    child: Text(tr(lang, 'skip')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BoardingMoment extends StatelessWidget {
  const _BoardingMoment({
    required this.flight,
    required this.seats,
    required this.lang,
    required this.t,
  });

  final FlightEntity flight;
  final List<String> seats;
  final String lang;

  /// 0..1 progress of this phase.
  final double t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rise = Curves.easeOutCubic.transform((t / .5).clamp(0.0, 1.0));
    final textIn = ((t - .35) / .3).clamp(0.0, 1.0);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0012)
              ..rotateX(.55 * (1 - rise) + .18)
              ..rotateZ(-.05)
              ..translateByDouble(0, 60 * (1 - rise), 0, 1),
            child: Opacity(
              opacity: rise,
              child: _MiniPass(flight: flight, seats: seats),
            ),
          ),
          const SizedBox(height: 40),
          Opacity(
            opacity: textIn,
            child: Column(
              children: [
                const Icon(
                  Icons.flight_takeoff_rounded,
                  color: Colors.white70,
                  size: 28,
                ),
                const SizedBox(height: 10),
                Text(
                  tr(lang, 'cabin_doors_closed'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                Text(
                  tr(lang, 'ready_for_takeoff'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white60,
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

/// Dark glass boarding pass with a barcode strip.
class _MiniPass extends StatelessWidget {
  const _MiniPass({required this.flight, required this.seats});

  final FlightEntity flight;
  final List<String> seats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    TextStyle? label = theme.textTheme.labelSmall?.copyWith(
      color: Colors.white54,
    );
    TextStyle? value = theme.textTheme.titleSmall?.copyWith(
      color: Colors.white,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .14),
                Colors.white.withValues(alpha: .05),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: .18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AirlineLogo(
                    airlineName: flight.airline,
                    flightNumber: flight.flightNumber,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(flight.flightNumber, style: value),
                  const Spacer(),
                  Text(dateOf(flight.departureTime), style: label),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    flight.departure.code,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.flight_rounded, color: Colors.white70),
                    ),
                  ),
                  Text(
                    flight.arrival.code,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SEAT', style: label),
                      Text(seats.join(', '), style: value),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('BOARDING', style: label),
                      Text(
                        timeOf(
                          flight.departureTime.subtract(
                            const Duration(minutes: 30),
                          ),
                        ),
                        style: value,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 34,
                child: CustomPaint(
                  size: const Size(double.infinity, 34),
                  painter: _BarcodePainter(seed: flight.flightNumber.hashCode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  _BarcodePainter({required this.seed});
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final paint = Paint()..color = Colors.white.withValues(alpha: .85);
    var x = 0.0;
    while (x < size.width) {
      final w = 1.0 + rng.nextInt(3);
      if (rng.nextBool()) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w + 1 + rng.nextInt(2);
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter old) => old.seed != seed;
}

class _FlightStatus extends StatelessWidget {
  const _FlightStatus({
    required this.flight,
    required this.progress,
    required this.lang,
  });

  final FlightEntity flight;
  final double progress;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = Duration(
      minutes: (flight.duration.inMinutes * (1 - progress)).round(),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .14)),
          ),
          child: Row(
            children: [
              Text(
                '${flight.departure.code}  →  ${flight.arrival.code}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                trArgs(lang, 'time_remaining', {
                  'h': '${remaining.inHours}',
                  'm': '${remaining.inMinutes.remainder(60)}',
                }),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Night map: every known airport as a light, the great-circle-ish route,
/// and the plane flying it. The camera follows the plane and dives toward
/// the destination at the end.
class _RouteMapPainter extends CustomPainter {
  _RouteMapPainter({
    required this.from,
    required this.to,
    required this.progress,
  });

  final String from;
  final String to;
  final double progress;

  static const _plane = Icons.flight_rounded;

  @override
  void paint(Canvas canvas, Size size) {
    final a = airportCoordinates[from];
    final b = airportCoordinates[to];
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF070A10),
    );
    if (a == null || b == null) return;

    // Equirectangular projection fitted to the route with generous margins.
    final minLat = math.min(a.$1, b.$1), maxLat = math.max(a.$1, b.$1);
    final minLon = math.min(a.$2, b.$2), maxLon = math.max(a.$2, b.$2);
    final spanLat = math.max(maxLat - minLat, 3.0) * 1.8;
    final spanLon = math.max(maxLon - minLon, 3.0) * 1.8;
    final cLat = (minLat + maxLat) / 2, cLon = (minLon + maxLon) / 2;
    final k = math.min(size.width / spanLon, size.height * .8 / spanLat);
    Offset project((double, double) p) => Offset(
      size.width / 2 + (p.$2 - cLon) * k,
      size.height * .45 - (p.$1 - cLat) * k,
    );

    final start = project(a), end = project(b);
    final mid = Offset.lerp(start, end, .5)!;
    final normal = Offset(-(end - start).dy, (end - start).dx);
    final control =
        mid +
        normal /
            (normal.distance == 0 ? 1 : normal.distance) *
            (end - start).distance *
            .22;
    final route = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    final metric = route.computeMetrics().first;
    final fly = Curves.easeInOutSine.transform(progress);
    final tangent = metric.getTangentForOffset(metric.length * fly)!;

    // Camera: follow the plane, then zoom toward the destination.
    final dive = Curves.easeIn.transform(
      ((progress - .75) / .25).clamp(0.0, 1.0),
    );
    final zoom = 1.25 + dive * 1.6;
    final focus = Offset.lerp(tangent.position, end, dive)!;
    canvas.save();
    canvas.translate(size.width / 2, size.height * .45);
    canvas.scale(zoom);
    canvas.translate(-focus.dx, -focus.dy);

    // Graticule.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .05)
      ..strokeWidth = 1 / zoom;
    for (var lat = -10; lat <= 50; lat += 2) {
      final y = project((lat.toDouble(), 0)).dy;
      canvas.drawLine(Offset(-4000, y), Offset(4000, y), grid);
    }
    for (var lon = 80; lon <= 150; lon += 2) {
      final x = project((0, lon.toDouble())).dx;
      canvas.drawLine(Offset(x, -4000), Offset(x, 4000), grid);
    }

    // Ambient towns: faint, deterministic scatter so the night map isn't empty.
    final rng = math.Random(7);
    final town = Paint()..color = const Color(0xFFFFE2A8).withValues(alpha: .28);
    final glow = Paint()
      ..color = const Color(0xFFFFC870).withValues(alpha: .10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var i = 0; i < 320; i++) {
      // Clustered around the route, like towns seen from cruise altitude.
      final p = project((
        cLat + (rng.nextDouble() - .5) * spanLat * 1.4,
        cLon + (rng.nextDouble() - .5) * spanLon * 1.4,
      ));
      final r = (.7 + rng.nextDouble() * 1.6) / zoom;
      if (i % 9 == 0) canvas.drawCircle(p, r * 4, glow);
      canvas.drawCircle(p, r, town);
    }

    // Airports as city lights.
    for (final entry in airportCoordinates.entries) {
      final p = project(entry.value);
      final isEnd = entry.key == from || entry.key == to;
      canvas.drawCircle(
        p,
        (isEnd ? 9 : 5) / zoom,
        Paint()
          ..color = const Color(0xFF7FA6FF).withValues(alpha: isEnd ? .35 : .12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        p,
        (isEnd ? 3.2 : 1.6) / zoom,
        Paint()..color = Colors.white.withValues(alpha: isEnd ? .95 : .45),
      );
      if (isEnd) {
        final tp = TextPainter(
          text: TextSpan(
            text: entry.key,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13 / zoom,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p + Offset(8 / zoom, -tp.height - 4 / zoom));
      }
    }

    // Route: dashed ahead, solid behind the plane.
    final ahead = Paint()
      ..color = Colors.white.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 / zoom;
    for (var d = metric.length * fly; d < metric.length; d += 10 / zoom) {
      canvas.drawPath(metric.extractPath(d, d + 5 / zoom), ahead);
    }
    canvas.drawPath(
      metric.extractPath(0, metric.length * fly),
      Paint()
        ..color = const Color(0xFF7FA6FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 / zoom
        ..strokeCap = StrokeCap.round,
    );

    // Plane, nose along the route.
    canvas.save();
    canvas.translate(tangent.position.dx, tangent.position.dy);
    canvas.rotate(-tangent.angle + math.pi / 2);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(_plane.codePoint),
        style: TextStyle(
          fontFamily: _plane.fontFamily,
          package: _plane.fontPackage,
          fontSize: 30 / zoom,
          color: Colors.white,
          shadows: const [Shadow(color: Color(0xAA7FA6FF), blurRadius: 12)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();

    canvas.restore();

    // Vignette.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * .45),
          size.longestSide * .7,
          [Colors.transparent, const Color(0xFF070A10)],
          [.55, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter old) =>
      old.progress != progress || old.from != from || old.to != to;
}
