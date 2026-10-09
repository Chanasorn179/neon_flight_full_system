import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../data/fares.dart';
import '../../models/travel_models.dart';
import '../../providers/language_provider.dart';
import '../../widgets/airline_logo.dart';
import '../../widgets/common_widgets.dart';

/// Boarding moment between seat selection and payment: a tilted boarding
/// pass with "cabin doors closed", then the plane flies the great-circle
/// route over a real Earth (NASA Blue Marble on a shader globe), and the
/// camera lands on a street map of the actual destination airport.
/// Tap anywhere to skip; skipped entirely when the OS reduces motion.
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

/// Shader + Earth texture, loaded once and reused.
class _GlobeAssets {
  _GlobeAssets(this.program, this.earth);
  final ui.FragmentProgram program;
  final ui.Image earth;

  static Future<_GlobeAssets>? _future;
  static Future<_GlobeAssets> load() => _future ??= () async {
    final program = await ui.FragmentProgram.fromAsset('shaders/globe.frag');
    final data = await rootBundle.load('assets/earth/earth_4096.jpg');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return _GlobeAssets(program, frame.image);
  }();
}

// Timeline (fraction of the whole animation).
const _passEnd = .20;
const _globeStart = .16;
const _globeEnd = .80;
const _mapStart = .76;

class _TakeoffScreenState extends State<TakeoffScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 8000),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      });

  bool _done = false;
  _GlobeAssets? _globe;

  @override
  void initState() {
    super.initState();
    _GlobeAssets.load()
        .then((g) {
          if (mounted) setState(() => _globe = g);
        })
        .catchError((_) {
          // No shader support: the route still draws on a dark background.
        });
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

  double _phase(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final f = widget.flight;
    final dest = airportCoordinates[f.arrival.code];

    return Scaffold(
      backgroundColor: const Color(0xFF05070C),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final passOpacity = 1 - _phase(t, _globeStart, _passEnd);
            final globeOpacity =
                _phase(t, _globeStart, _passEnd) *
                (1 - _phase(t, _mapStart, _globeEnd));
            final mapOpacity = _phase(t, _mapStart, _globeEnd);
            final globeT = _phase(t, _globeStart, _globeEnd);
            final mapT = _phase(t, _mapStart, 1);

            return Stack(
              fit: StackFit.expand,
              children: [
                if (globeOpacity > 0)
                  Opacity(
                    opacity: globeOpacity,
                    child: CustomPaint(
                      painter: _GlobePainter(
                        assets: _globe,
                        from: f.departure,
                        to: f.arrival,
                        progress: globeT,
                        lang: lang,
                      ),
                    ),
                  ),
                if (mapOpacity > 0 && dest != null)
                  Opacity(
                    opacity: mapOpacity,
                    child: _DestinationMap(
                      airport: f.arrival,
                      at: dest,
                      progress: mapT,
                      lang: lang,
                    ),
                  ),
                if (passOpacity > 0)
                  Opacity(
                    opacity: passOpacity,
                    child: _BoardingMoment(
                      flight: f,
                      seats: widget.seats,
                      lang: lang,
                      t: _phase(t, 0, _globeStart),
                    ),
                  ),
                if (globeOpacity > 0)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 48,
                    child: Opacity(
                      opacity: globeOpacity,
                      child: _FlightStatus(
                        flight: f,
                        progress: _GlobePainter.flyProgress(globeT),
                        lang: lang,
                      ),
                    ),
                  ),
                if (globeOpacity > 0)
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Text(
                      'Imagery: NASA Earth Observatory',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .45),
                        fontSize: 10,
                      ),
                    ),
                  ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  right: 12,
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: mapOpacity > .5
                          ? Colors.black87
                          : Colors.white70,
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

/// Unit vector for a (lat, lon) in degrees.
(double, double, double) _vec((double, double) p) {
  final lat = p.$1 * math.pi / 180, lon = p.$2 * math.pi / 180;
  return (
    math.cos(lat) * math.cos(lon),
    math.cos(lat) * math.sin(lon),
    math.sin(lat),
  );
}

/// Point a fraction [f] along the great circle from [a] to [b], as (lat, lon)
/// in radians.
(double, double) _slerp((double, double) a, (double, double) b, double f) {
  final va = _vec(a), vb = _vec(b);
  final dot = (va.$1 * vb.$1 + va.$2 * vb.$2 + va.$3 * vb.$3).clamp(-1.0, 1.0);
  final omega = math.acos(dot);
  if (omega < 1e-6) return (a.$1 * math.pi / 180, a.$2 * math.pi / 180);
  final s1 = math.sin((1 - f) * omega) / math.sin(omega);
  final s2 = math.sin(f * omega) / math.sin(omega);
  final x = s1 * va.$1 + s2 * vb.$1,
      y = s1 * va.$2 + s2 * vb.$2,
      z = s1 * va.$3 + s2 * vb.$3;
  return (math.atan2(z, math.sqrt(x * x + y * y)), math.atan2(y, x));
}

/// Earth from space with the great-circle route. The camera starts on the
/// whole globe over the departure airport, zooms to fit the route, follows
/// the plane, then dives toward the destination.
class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.assets,
    required this.from,
    required this.to,
    required this.progress,
    required this.lang,
  });

  final _GlobeAssets? assets;
  final AirportEntity from;
  final AirportEntity to;
  final double progress;
  final String lang;

  static const _plane = Icons.flight_rounded;

  /// How far along the route the plane is for a given globe-phase progress.
  static double flyProgress(double p) =>
      Curves.easeInOutSine.transform(((p - .18) / .62).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final a = airportCoordinates[from.code];
    final b = airportCoordinates[to.code];
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF05070C),
    );
    _stars(canvas, size);
    if (a == null || b == null) return;

    final fly = flyProgress(progress);
    final plane = _slerp(a, b, fly);
    final start = _slerp(a, b, 0);
    final end = _slerp(a, b, 1);

    // Camera.
    final routeArc = math.acos(
      (_vec(a).$1 * _vec(b).$1 +
              _vec(a).$2 * _vec(b).$2 +
              _vec(a).$3 * _vec(b).$3)
          .clamp(-1.0, 1.0),
    );
    final minDim = math.min(size.width, size.height);
    final globeR = minDim * .40;
    final routeR = (size.width * .55 / math.max(routeArc, .02)).clamp(
      globeR,
      minDim * 9,
    );
    final zoomIn = Curves.easeInOutCubic.transform(
      (progress / .2).clamp(0.0, 1.0),
    );
    final dive = Curves.easeInCubic.transform(
      ((progress - .82) / .18).clamp(0.0, 1.0),
    );
    final radius = (globeR + (routeR - globeR) * zoomIn) * (1 + dive * 2.2);
    final followT = Curves.easeInOut.transform((progress / .2).clamp(0.0, 1.0));
    double lerpAngle(double x, double y, double t) {
      var d = y - x;
      while (d > math.pi) {
        d -= 2 * math.pi;
      }
      while (d < -math.pi) {
        d += 2 * math.pi;
      }
      return x + d * t;
    }

    final camLat = lerpAngle(start.$1, plane.$1, followT);
    final camLon = lerpAngle(start.$2, plane.$2, followT);
    final viewLat = lerpAngle(camLat, end.$1, dive);
    final viewLon = lerpAngle(camLon, end.$2, dive);
    final center = Offset(size.width / 2, size.height * .45);

    // Globe surface (shader) or a plain disc while assets load.
    final g = assets;
    if (g != null) {
      final shader = g.program.fragmentShader()
        ..setFloat(0, center.dx)
        ..setFloat(1, center.dy)
        ..setFloat(2, radius)
        ..setFloat(3, viewLat)
        ..setFloat(4, viewLon)
        ..setImageSampler(0, g.earth);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    } else {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xFF10233F),
      );
    }

    // Orthographic projection matching the shader.
    Offset? project((double, double) p) {
      final lat = p.$1, dLon = p.$2 - viewLon;
      final cosC =
          math.sin(viewLat) * math.sin(lat) +
          math.cos(viewLat) * math.cos(lat) * math.cos(dLon);
      if (cosC < 0) return null; // far side
      final x = math.cos(lat) * math.sin(dLon);
      final y =
          math.cos(viewLat) * math.sin(lat) -
          math.sin(viewLat) * math.cos(lat) * math.cos(dLon);
      return center + Offset(x, -y) * radius;
    }

    // Route: solid behind the plane, dashed ahead.
    const steps = 96;
    final behind = Path();
    final ahead = <Offset>[];
    var started = false;
    for (var i = 0; i <= steps; i++) {
      final f = i / steps;
      final pt = project(_slerp(a, b, f));
      if (pt == null) continue;
      if (f <= fly) {
        if (!started) {
          behind.moveTo(pt.dx, pt.dy);
          started = true;
        } else {
          behind.lineTo(pt.dx, pt.dy);
        }
      } else {
        ahead.add(pt);
      }
    }
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: .7)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i + 1 < ahead.length; i += 2) {
      canvas.drawLine(ahead[i], ahead[i + 1], dash);
    }
    canvas.drawPath(
      behind,
      Paint()
        ..color = const Color(0xFF8FB4FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Airports with real names.
    for (final (airport, coord) in [(from, a), (to, b)]) {
      final pt = project((coord.$1 * math.pi / 180, coord.$2 * math.pi / 180));
      if (pt == null) continue;
      canvas.drawCircle(
        pt,
        10,
        Paint()..color = Colors.white.withValues(alpha: .25),
      );
      canvas.drawCircle(pt, 4.5, Paint()..color = Colors.white);
      final name = lang == 'th' ? airport.cityTh : airport.cityEn;
      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: airport.code,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(
              text: '  $name',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .85),
                fontSize: 12,
              ),
            ),
          ],
          style: const TextStyle(
            shadows: [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pt + Offset(10, -tp.height - 6));
    }

    // Plane, nose along the route.
    final here = project(plane);
    final next = project(_slerp(a, b, math.min(1, fly + .01)));
    if (here != null) {
      final heading = next == null || (next - here).distance < .01
          ? 0.0
          : math.atan2((next - here).dy, (next - here).dx) + math.pi / 2;
      canvas.save();
      canvas.translate(here.dx, here.dy);
      canvas.rotate(heading);
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(_plane.codePoint),
          style: TextStyle(
            fontFamily: _plane.fontFamily,
            package: _plane.fontPackage,
            fontSize: 34,
            color: Colors.white,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  void _stars(Canvas canvas, Size size) {
    final rng = math.Random(11);
    final star = Paint();
    for (var i = 0; i < 160; i++) {
      star.color = Colors.white.withValues(alpha: .15 + rng.nextDouble() * .5);
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 1.1 + .2,
        star,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter old) =>
      old.progress != progress || old.assets != assets || old.lang != lang;
}

/// Street map of the real destination airport (OpenStreetMap), slowly
/// zooming in like the final approach.
class _DestinationMap extends StatelessWidget {
  const _DestinationMap({
    required this.airport,
    required this.at,
    required this.progress,
    required this.lang,
  });

  final AirportEntity airport;
  final (double, double) at;
  final double progress;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = LatLng(at.$1, at.$2);
    final city = lang == 'th' ? airport.cityTh : airport.cityEn;
    final name = lang == 'th' ? airport.nameTh : airport.nameEn;

    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.scale(
          scale: 1 + Curves.easeOut.transform(progress) * .35,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 12.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
              backgroundColor: const Color(0xFFE8ECEF),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mini_projects',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 56,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E5BD6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 10),
                        ],
                      ),
                      child: const Icon(
                        Icons.flight_land_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                color: Colors.white.withValues(alpha: .78),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trArgs(lang, 'welcome_to', {'city': city}),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$name (${airport.code})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Text(
            '© OpenStreetMap contributors',
            style: TextStyle(
              color: Colors.black.withValues(alpha: .6),
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}
