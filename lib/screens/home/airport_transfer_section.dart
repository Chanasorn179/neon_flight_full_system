import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/app_localizations.dart';
import '../../models/entities.dart';
import '../../widgets/app_widgets.dart';

typedef GpsLocationLoader = Future<GpsLocationEntity> Function();
typedef TransferBookingCallback =
    FutureOr<void> Function(TransferBookingEntity booking);

const double _transferServiceRadiusKm = 20;

class AirportTransferSection extends StatefulWidget {
  const AirportTransferSection({
    super.key,
    required this.languageCode,
    required this.departureAirportCode,
    this.flightDepartureTime,
    this.userId = 'guest',
    this.initialReservation,
    this.onBooked,
    this.driverNotificationEnabled = false,
    this.gpsLocationLoader,
  });

  final String languageCode;
  final String departureAirportCode;
  final DateTime? flightDepartureTime;
  final String userId;
  final TransferBookingEntity? initialReservation;
  final TransferBookingCallback? onBooked;
  final bool driverNotificationEnabled;
  final GpsLocationLoader? gpsLocationLoader;

  @override
  State<AirportTransferSection> createState() => _AirportTransferSectionState();
}

class _AirportTransferSectionState extends State<AirportTransferSection> {
  TransferBookingEntity? reservation;
  GpsLocationEntity? currentLocation;
  bool locating = false;
  String? locationErrorKey;

  String get languageCode => widget.languageCode;
  String get departureAirportCode => widget.departureAirportCode;

  String _localized(String english, String thai) =>
      languageCode == 'th' ? thai : english;

  @override
  void initState() {
    super.initState();
    reservation = widget.initialReservation;
    currentLocation = reservation?.pickupLocation;
  }

  _TransferLocation? get _departureLocation {
    for (final location in _transferLocations) {
      if (location.code == departureAirportCode) return location;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant AirportTransferSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.departureAirportCode != widget.departureAirportCode ||
        oldWidget.flightDepartureTime != widget.flightDepartureTime) {
      reservation = widget.initialReservation;
      currentLocation = reservation?.pickupLocation;
      locationErrorKey = null;
    } else if (oldWidget.initialReservation?.id !=
        widget.initialReservation?.id) {
      reservation = widget.initialReservation;
      currentLocation = reservation?.pickupLocation;
    }
  }

  List<_TransferVehicle> _availableVehicles(_TransferLocation location) {
    final vehicles = location.vehicles
        .where((vehicle) => vehicle.status == _TransferStatus.available)
        .toList();
    if (reservation != null && vehicles.isNotEmpty) {
      return vehicles.sublist(1);
    }
    return vehicles;
  }

  double _distanceToAirportKm(
    _TransferLocation airport,
    GpsLocationEntity location,
  ) {
    return Geolocator.distanceBetween(
          location.latitude,
          location.longitude,
          airport.latitude,
          airport.longitude,
        ) /
        1000;
  }

  Future<GpsLocationEntity> _loadGpsLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const _GpsLocationException('gps_service_disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const _GpsLocationException('gps_permission_denied');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _GpsLocationException('gps_permission_denied_forever');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return GpsLocationEntity(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
    );
  }

  Future<GpsLocationEntity?> _locateCurrentPosition() async {
    if (locating) return null;
    setState(() {
      locating = true;
      locationErrorKey = null;
    });

    try {
      final loader = widget.gpsLocationLoader ?? _loadGpsLocation;
      final location = await loader();
      if (!mounted) return null;
      setState(() {
        currentLocation = location;
        locating = false;
      });
      return location;
    } on _GpsLocationException catch (error) {
      if (!mounted) return null;
      setState(() {
        locating = false;
        locationErrorKey = error.messageKey;
      });
      return null;
    } catch (_) {
      if (!mounted) return null;
      setState(() {
        locating = false;
        locationErrorKey = 'gps_location_failed';
      });
      return null;
    }
  }

  Future<void> _scheduleTransfer(
    BuildContext context,
    _TransferLocation location,
  ) async {
    final departureTime = widget.flightDepartureTime;
    if (departureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(languageCode, 'transfer_ticket_required')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final pickupLocation = currentLocation ?? await _locateCurrentPosition();
    if (!context.mounted) return;
    if (pickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(languageCode, 'gps_required')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final distanceToAirportKm = _distanceToAirportKm(location, pickupLocation);
    if (distanceToAirportKm > _transferServiceRadiusKm) {
      setState(() {
        locationErrorKey = 'gps_outside_service_area';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tr(languageCode, 'gps_outside_service_area')} '
            '(${distanceToAirportKm.toStringAsFixed(1)} km)',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final pickupTime = departureTime.subtract(const Duration(hours: 3));
    final availableVehicles = location.vehicles
        .where((vehicle) => vehicle.status == _TransferStatus.available)
        .toList();
    if (availableVehicles.isEmpty) return;
    final createdAt = DateTime.now();
    final booking = TransferBookingEntity(
      id: 'NT${createdAt.millisecondsSinceEpoch}',
      userId: widget.userId,
      airportCode: location.code,
      airportNameEn: location.nameEn,
      airportNameTh: location.nameTh,
      pickupEn: location.pickupEn,
      pickupTh: location.pickupTh,
      pickupLocation: pickupLocation,
      distanceToAirportKm: distanceToAirportKm,
      pickupTime: pickupTime,
      flightDepartureTime: departureTime,
      status: BookingStatus.upcoming,
      createdAt: createdAt,
    );
    setState(() {
      reservation = booking;
    });
    var driverNotificationFailed = false;
    try {
      await widget.onBooked?.call(booking);
    } catch (_) {
      driverNotificationFailed = true;
    }
    if (!context.mounted) return;
    final notificationMessage = !widget.driverNotificationEnabled
        ? ''
        : ' · ${tr(languageCode, driverNotificationFailed ? 'transfer_line_notification_failed' : 'transfer_line_notification_success')}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${tr(languageCode, 'transfer_schedule_success')} · '
          '${tr(languageCode, 'transfer_pickup_time')}: '
          '${timeOf(pickupTime)}$notificationMessage',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  bool _looksLikeAndroidEmulatorDefault(GpsLocationEntity location) {
    // Android Emulator commonly starts at Googleplex:
    // 37.4219983, -122.084. This is not a distance-calculation bug.
    return (location.latitude - 37.4219983).abs() < 0.02 &&
        (location.longitude - (-122.084)).abs() < 0.02;
  }

  void _useAirportTestLocation(_TransferLocation airport) {
    if (!kDebugMode) return;
    setState(() {
      // A small offset from the airport keeps the test inside the 20 km zone
      // while avoiding an unrealistic exact 0.0 km distance.
      currentLocation = GpsLocationEntity(
        latitude: airport.latitude + 0.018,
        longitude: airport.longitude + 0.012,
        accuracyMeters: 8,
      );
      locationErrorKey = null;
    });
  }

  String _distanceLabel(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = _departureLocation;
    if (location == null) return const SizedBox.shrink();

    final availableCount = _availableVehicles(location).length;
    final distanceToAirportKm = currentLocation == null
        ? null
        : _distanceToAirportKm(location, currentLocation!);
    final isWithinServiceArea = distanceToAirportKm == null ||
        distanceToAirportKm <= _transferServiceRadiusKm;
    final emulatorDefault = currentLocation != null &&
        _looksLikeAndroidEmulatorDefault(currentLocation!);

    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          tr(languageCode, 'airport_transfer'),
          icon: Icons.airport_shuttle_rounded,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .06),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primary.withValues(alpha: .95),
                        theme.colorScheme.secondary.withValues(alpha: .78),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .22),
                          ),
                        ),
                        child: const Icon(
                          Icons.local_taxi_rounded,
                          color: Colors.white,
                          size: 29,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(languageCode, 'airport_transfer'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tr(languageCode, 'transfer_subtitle'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: .86),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Airport + available cars
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flight_takeoff_rounded,
                                  size: 17,
                                  color: primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  location.code,
                                  style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${tr(languageCode, 'transfer_available_remaining')} '
                              '$availableCount ${tr(languageCode, 'cars')}',
                              key: const ValueKey('transfer-available-count'),
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Text(
                        _localized(location.nameEn, location.nameTh),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 18,
                            color: primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              currentLocation == null
                                  ? tr(languageCode, 'gps_location_not_set')
                                  : _gpsLocationText(
                                      currentLocation!,
                                      languageCode,
                                    ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (emulatorDefault && kDebugMode) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: .45),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.developer_mode_rounded,
                                color: Colors.orange,
                                size: 21,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  _localized(
                                    'The emulator is using the default Googleplex GPS location. '
                                    'That is why the distance is thousands of kilometers.',
                                    'Emulator กำลังใช้พิกัดเริ่มต้น Googleplex '
                                    '(37.421998, -122.084000) จึงทำให้ระยะทางเป็นหลักหมื่นกิโลเมตร '
                                    'ไม่ใช่สูตรคำนวณระยะทางผิด',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (distanceToAirportKm != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isWithinServiceArea
                                ? Colors.green.withValues(alpha: .08)
                                : theme.colorScheme.error.withValues(alpha: .07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isWithinServiceArea
                                  ? Colors.green.withValues(alpha: .28)
                                  : theme.colorScheme.error.withValues(alpha: .25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isWithinServiceArea
                                      ? Colors.green.withValues(alpha: .13)
                                      : theme.colorScheme.error
                                          .withValues(alpha: .12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isWithinServiceArea
                                      ? Icons.check_rounded
                                      : Icons.close_rounded,
                                  color: isWithinServiceArea
                                      ? Colors.green
                                      : theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr(
                                        languageCode,
                                        isWithinServiceArea
                                            ? 'gps_within_service_area'
                                            : 'gps_outside_service_area',
                                      ),
                                      style: TextStyle(
                                        color: isWithinServiceArea
                                            ? Colors.green.shade700
                                            : theme.colorScheme.error,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_distanceLabel(distanceToAirportKm)} '
                                      '· ${_localized('service radius 20 km', 'พื้นที่ให้บริการ 20 กม.')}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey('locate-airport-transfer'),
                              onPressed: reservation == null && !locating
                                  ? _locateCurrentPosition
                                  : null,
                              icon: locating
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.my_location_rounded),
                              label: Text(
                                tr(
                                  languageCode,
                                  locating
                                      ? 'gps_locating'
                                      : currentLocation == null
                                          ? 'gps_use_current_location'
                                          : 'gps_refresh_location',
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (kDebugMode && emulatorDefault) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () => _useAirportTestLocation(location),
                            icon: const Icon(Icons.science_rounded),
                            label: Text(
                              _localized(
                                'Use airport test location',
                                'ใช้ตำแหน่งทดสอบใกล้สนามบิน',
                              ),
                            ),
                          ),
                        ),
                      ],

                      if (locationErrorKey != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          tr(languageCode, locationErrorKey!),
                          key: const ValueKey('gps-location-error'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],

                      if (reservation != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer
                                .withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    color: theme.colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tr(languageCode, 'transfer_locked'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 9),
                              Text(
                                '${tr(languageCode, 'transfer_pickup_time')}: '
                                '${dateOf(reservation!.pickupTime)} · '
                                '${timeOf(reservation!.pickupTime)}',
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${tr(languageCode, 'transfer_flight_departure')}: '
                                '${dateOf(reservation!.flightDepartureTime)} · '
                                '${timeOf(reservation!.flightDepartureTime)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          key: const ValueKey('book-airport-transfer'),
                          onPressed: reservation == null &&
                                  availableCount > 0 &&
                                  !locating &&
                                  isWithinServiceArea
                              ? () => _scheduleTransfer(context, location)
                              : null,
                          icon: Icon(
                            reservation == null
                                ? Icons.event_available_rounded
                                : Icons.lock_rounded,
                          ),
                          label: Text(
                            tr(
                              languageCode,
                              reservation == null
                                  ? 'transfer_schedule'
                                  : 'transfer_locked',
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                      if (reservation == null &&
                          widget.flightDepartureTime != null) ...[
                        const SizedBox(height: 9),
                        Center(
                          child: Text(
                            tr(languageCode, 'transfer_auto_pickup'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _gpsLocationText(GpsLocationEntity location, String languageCode) {
  return '${location.latitude.toStringAsFixed(6)}, '
      '${location.longitude.toStringAsFixed(6)} · '
      '${tr(languageCode, 'gps_accuracy')} '
      '±${location.accuracyMeters.round()} m';
}

class _GpsLocationException implements Exception {
  const _GpsLocationException(this.messageKey);

  final String messageKey;
}

enum _TransferStatus { available, pickingUp, droppingOff, unavailable }

class _TransferVehicle {
  const _TransferVehicle({
    required this.name,
    required this.model,
    required this.driver,
    required this.plateNumber,
    required this.seats,
    required this.status,
    required this.icon,
    this.etaMinutes = 0,
  });

  final String name;
  final String model;
  final String driver;
  final String plateNumber;
  final int seats;
  final int etaMinutes;
  final _TransferStatus status;
  final IconData icon;
}

class _TransferLocation {
  const _TransferLocation({
    required this.code,
    required this.nameEn,
    required this.nameTh,
    required this.pickupEn,
    required this.pickupTh,
    required this.latitude,
    required this.longitude,
    required this.vehicles,
  });

  final String code;
  final String nameEn;
  final String nameTh;
  final String pickupEn;
  final String pickupTh;
  final double latitude;
  final double longitude;
  final List<_TransferVehicle> vehicles;
}

const _transferLocations = [
  _TransferLocation(
    code: 'BKK',
    nameEn: 'Suvarnabhumi Airport',
    nameTh: 'สนามบินสุวรรณภูมิ',
    pickupEn: 'Level 1, Gate 4',
    pickupTh: 'ชั้น 1 ประตู 4',
    latitude: 13.681100,
    longitude: 100.747002,
    vehicles: [
      _TransferVehicle(
        name: 'Neon Car 01',
        model: 'Toyota Camry',
        driver: 'สมชาย',
        plateNumber: 'กข 4582',
        seats: 3,
        etaMinutes: 2,
        status: _TransferStatus.available,
        icon: Icons.local_taxi_rounded,
      ),
      _TransferVehicle(
        name: 'Neon Car 05',
        model: 'Honda Accord',
        driver: 'มนัส',
        plateNumber: 'ชล 7316',
        seats: 3,
        etaMinutes: 4,
        status: _TransferStatus.available,
        icon: Icons.directions_car_rounded,
      ),
      _TransferVehicle(
        name: 'Neon Van 08',
        model: 'Toyota Commuter',
        driver: 'นที',
        plateNumber: 'ฮว 9124',
        seats: 8,
        status: _TransferStatus.pickingUp,
        icon: Icons.airport_shuttle_rounded,
      ),
      _TransferVehicle(
        name: 'Neon SUV 12',
        model: 'Toyota Fortuner',
        driver: 'อนันต์',
        plateNumber: 'สญ 6631',
        seats: 5,
        status: _TransferStatus.droppingOff,
        icon: Icons.directions_car_filled_rounded,
      ),
      _TransferVehicle(
        name: 'Neon Van 15',
        model: 'Hyundai H-1',
        driver: 'กิตติ',
        plateNumber: 'นข 2209',
        seats: 7,
        status: _TransferStatus.unavailable,
        icon: Icons.airport_shuttle_rounded,
      ),
    ],
  ),
  _TransferLocation(
    code: 'DMK',
    nameEn: 'Don Mueang International Airport',
    nameTh: 'ท่าอากาศยานดอนเมือง',
    pickupEn: 'Terminal 2, Gate 12',
    pickupTh: 'อาคาร 2 ประตู 12',
    latitude: 13.914372,
    longitude: 100.605692,
    vehicles: [
      _TransferVehicle(
        name: 'Neon DMK 17',
        model: 'Toyota Camry',
        driver: 'ณัฐพล',
        plateNumber: 'กท 1717',
        seats: 3,
        etaMinutes: 3,
        status: _TransferStatus.available,
        icon: Icons.local_taxi_rounded,
      ),
      _TransferVehicle(
        name: 'Neon DMK 19',
        model: 'Toyota Commuter',
        driver: 'วีระ',
        plateNumber: 'ฮม 1919',
        seats: 8,
        etaMinutes: 6,
        status: _TransferStatus.available,
        icon: Icons.airport_shuttle_rounded,
      ),
      _TransferVehicle(
        name: 'Neon DMK 22',
        model: 'Honda CR-V',
        driver: 'ธนกร',
        plateNumber: 'ขม 2222',
        seats: 5,
        status: _TransferStatus.pickingUp,
        icon: Icons.directions_car_filled_rounded,
      ),
    ],
  ),
  _TransferLocation(
    code: 'CNX',
    nameEn: 'Chiang Mai International Airport',
    nameTh: 'สนามบินนานาชาติเชียงใหม่',
    pickupEn: 'Domestic Terminal, Gate 2',
    pickupTh: 'อาคารผู้โดยสารในประเทศ ประตู 2',
    latitude: 18.766800,
    longitude: 98.962601,
    vehicles: [
      _TransferVehicle(
        name: 'Neon Car 21',
        model: 'Toyota Altis',
        driver: 'วิชัย',
        plateNumber: 'กท 8821',
        seats: 3,
        etaMinutes: 3,
        status: _TransferStatus.available,
        icon: Icons.local_taxi_rounded,
      ),
      _TransferVehicle(
        name: 'Neon Van 23',
        model: 'Toyota Commuter',
        driver: 'ประสิทธิ์',
        plateNumber: 'ฮน 4420',
        seats: 8,
        status: _TransferStatus.pickingUp,
        icon: Icons.airport_shuttle_rounded,
      ),
      _TransferVehicle(
        name: 'Neon SUV 25',
        model: 'Honda CR-V',
        driver: 'ศุภชัย',
        plateNumber: 'ขจ 5190',
        seats: 5,
        status: _TransferStatus.unavailable,
        icon: Icons.directions_car_filled_rounded,
      ),
    ],
  ),
  _TransferLocation(
    code: 'HKT',
    nameEn: 'Phuket International Airport',
    nameTh: 'สนามบินนานาชาติภูเก็ต',
    pickupEn: 'Domestic Terminal, Gate 1',
    pickupTh: 'อาคารผู้โดยสารในประเทศ ประตู 1',
    latitude: 8.113257,
    longitude: 98.317400,
    vehicles: [
      _TransferVehicle(
        name: 'Neon SUV 31',
        model: 'Toyota Fortuner',
        driver: 'ภูริ',
        plateNumber: 'กม 7288',
        seats: 5,
        etaMinutes: 5,
        status: _TransferStatus.available,
        icon: Icons.directions_car_filled_rounded,
      ),
      _TransferVehicle(
        name: 'Neon Van 34',
        model: 'Hyundai H-1',
        driver: 'ชาญ',
        plateNumber: 'นข 3451',
        seats: 7,
        etaMinutes: 7,
        status: _TransferStatus.available,
        icon: Icons.airport_shuttle_rounded,
      ),
      _TransferVehicle(
        name: 'Neon Car 36',
        model: 'Toyota Camry',
        driver: 'ธีรภัทร',
        plateNumber: 'กต 6103',
        seats: 3,
        status: _TransferStatus.droppingOff,
        icon: Icons.local_taxi_rounded,
      ),
    ],
  ),
  _TransferLocation(
    code: 'NRT',
    nameEn: 'Narita International Airport',
    nameTh: 'สนามบินนานาชาตินาริตะ',
    pickupEn: 'Terminal 1, South Wing',
    pickupTh: 'อาคาร 1 ฝั่งใต้',
    latitude: 35.768580,
    longitude: 140.388714,
    vehicles: [
      _TransferVehicle(
        name: 'Neon Tokyo 41',
        model: 'Toyota Crown',
        driver: 'Haruto',
        plateNumber: '成田 41-08',
        seats: 3,
        etaMinutes: 4,
        status: _TransferStatus.available,
        icon: Icons.local_taxi_rounded,
      ),
      _TransferVehicle(
        name: 'Neon Tokyo 43',
        model: 'Toyota Alphard',
        driver: 'Ren',
        plateNumber: '成田 43-12',
        seats: 6,
        etaMinutes: 6,
        status: _TransferStatus.available,
        icon: Icons.airport_shuttle_rounded,
      ),
      _TransferVehicle(
        name: 'Neon Tokyo 46',
        model: 'Nissan Serena',
        driver: 'Sota',
        plateNumber: '成田 46-27',
        seats: 6,
        status: _TransferStatus.pickingUp,
        icon: Icons.directions_car_filled_rounded,
      ),
    ],
  ),
  _TransferLocation(
    code: 'ICN',
    nameEn: 'Incheon International Airport',
    nameTh: 'สนามบินนานาชาติอินชอน',
    pickupEn: 'Terminal 1, Gate 7',
    pickupTh: 'อาคาร 1 ประตู 7',
    latitude: 37.469101,
    longitude: 126.450996,
    vehicles: [
      _TransferVehicle(
        name: 'Neon Seoul 51',
        model: 'Hyundai Grandeur',
        driver: 'Min-jun',
        plateNumber: '인천 51가 8210',
        seats: 3,
        etaMinutes: 5,
        status: _TransferStatus.available,
        icon: Icons.local_taxi_rounded,
      ),
      _TransferVehicle(
        name: 'Neon Seoul 53',
        model: 'Kia Carnival',
        driver: 'Ji-ho',
        plateNumber: '인천 53나 4108',
        seats: 7,
        status: _TransferStatus.droppingOff,
        icon: Icons.airport_shuttle_rounded,
      ),
      _TransferVehicle(
        name: 'Neon Seoul 55',
        model: 'Hyundai Staria',
        driver: 'Seo-jun',
        plateNumber: '인천 55다 2291',
        seats: 7,
        status: _TransferStatus.unavailable,
        icon: Icons.directions_car_filled_rounded,
      ),
    ],
  ),
  _TransferLocation(
    code: 'SIN',
    nameEn: 'Singapore Changi Airport',
    nameTh: 'สนามบินชางงีสิงคโปร์',
    pickupEn: 'Terminal 3, Arrival Pickup',
    pickupTh: 'อาคาร 3 จุดรับผู้โดยสารขาเข้า',
    latitude: 1.350190,
    longitude: 103.994003,
    vehicles: [
      _TransferVehicle(
        name: 'Neon SG 61',
        model: 'Mercedes-Benz E-Class',
        driver: 'Daniel',
        plateNumber: 'SNG 6108',
        seats: 3,
        etaMinutes: 3,
        status: _TransferStatus.available,
        icon: Icons.local_taxi_rounded,
      ),
      _TransferVehicle(
        name: 'Neon SG 64',
        model: 'Toyota Alphard',
        driver: 'Wei Ming',
        plateNumber: 'SNG 6412',
        seats: 6,
        etaMinutes: 6,
        status: _TransferStatus.available,
        icon: Icons.airport_shuttle_rounded,
      ),
      _TransferVehicle(
        name: 'Neon SG 67',
        model: 'Hyundai Staria',
        driver: 'Arjun',
        plateNumber: 'SNG 6725',
        seats: 7,
        status: _TransferStatus.pickingUp,
        icon: Icons.directions_car_filled_rounded,
      ),
    ],
  ),
];