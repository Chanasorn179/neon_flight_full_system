import 'package:flutter/material.dart';

import '../data/thai_airlines.dart';
import '../models/entities.dart';

/// Airline image from `assets/airlines/<CODE>.png`, falling back to a colored
/// badge with the airline code when the airline or its image is unknown.
class AirlineLogo extends StatelessWidget {
  const AirlineLogo({
    super.key,
    required this.airlineName,
    required this.flightNumber,
    this.size = 44,
  });

  final String airlineName;
  final String flightNumber;
  final double size;

  @override
  Widget build(BuildContext context) {
    final airline = airlineForFlight(airlineName, flightNumber);
    final badge = _CodeBadge(
      airline: airline,
      fallback: airlineName,
      size: size,
    );

    return Semantics(
      label: airline?.nameEn ?? airlineName,
      image: true,
      excludeSemantics: true,
      child: airline == null
          ? badge
          : Image.asset(
              airline.logoAsset,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => badge,
            ),
    );
  }
}

class _CodeBadge extends StatelessWidget {
  const _CodeBadge({
    required this.airline,
    required this.fallback,
    required this.size,
  });

  final AirlineEntity? airline;
  final String fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = airline == null
        ? Theme.of(context).colorScheme.primary
        : Color(airline!.color);
    final onColor =
        color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      child: Text(
        airline?.code ?? (fallback.isEmpty ? '?' : fallback.substring(0, 1)),
        style: TextStyle(
          color: onColor,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}
