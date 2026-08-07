import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_localizations.dart';
import '../../widgets/app_widgets.dart';

class AirportTransferSection extends StatefulWidget {
  const AirportTransferSection({
    super.key,
    required this.languageCode,
    required this.departureAirportCode,
    this.flightDepartureTime,
  });

  final String languageCode;
  final String departureAirportCode;
  final DateTime? flightDepartureTime;

  @override
  State<AirportTransferSection> createState() => _AirportTransferSectionState();
}

class _AirportTransferSectionState extends State<AirportTransferSection> {
  _TransferReservation? reservation;

  String get languageCode => widget.languageCode;
  String get departureAirportCode => widget.departureAirportCode;

  String _localized(String english, String thai) =>
      languageCode == 'th' ? thai : english;

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
      reservation = null;
    }
  }

  List<_TransferVehicle> _availableVehicles(_TransferLocation location) {
    return location.vehicles
        .where(
          (vehicle) =>
              vehicle.status == _TransferStatus.available &&
              vehicle.name != reservation?.vehicle.name,
        )
        .toList();
  }

  void _scheduleTransfer(BuildContext context, _TransferLocation location) {
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

    final pickupTime = departureTime.subtract(const Duration(hours: 3));
    final availableVehicles = location.vehicles
        .where((vehicle) => vehicle.status == _TransferStatus.available)
        .toList();
    if (availableVehicles.isEmpty) return;
    final vehicle =
        availableVehicles[Random().nextInt(availableVehicles.length)];
    setState(() {
      reservation = _TransferReservation(
        vehicle: vehicle,
        pickupTime: pickupTime,
        flightDepartureTime: departureTime,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${tr(languageCode, 'transfer_schedule_success')}: ${vehicle.name} · '
          '${timeOf(pickupTime)}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showVehicles(
    BuildContext context,
    _TransferLocation location,
  ) async {
    final availableVehicles = _availableVehicles(location);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  tr(languageCode, 'airport_transfer'),
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(location.code),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tr(languageCode, 'transfer_service_24h'),
                            style: TextStyle(
                              color: Theme.of(
                                sheetContext,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        sheetContext,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _PickupSummary(
                  airport: _localized(location.nameEn, location.nameTh),
                  pickup: _localized(location.pickupEn, location.pickupTh),
                  availableCount: availableVehicles.length,
                  languageCode: languageCode,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  itemCount: location.vehicles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _VehicleCard(
                    vehicle: location.vehicles[index],
                    languageCode: languageCode,
                    reserved:
                        location.vehicles[index].name ==
                        reservation?.vehicle.name,
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: availableVehicles.isEmpty
                          ? null
                          : () {
                              final vehicle =
                                  availableVehicles[Random().nextInt(
                                    availableVehicles.length,
                                  )];
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${vehicle.name} ${tr(languageCode, 'transfer_on_way')} '
                                    '${_localized(location.pickupEn, location.pickupTh)}',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                      icon: const Icon(Icons.local_taxi_rounded),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Text(
                          '${tr(languageCode, 'transfer_call_available')} '
                          '(${availableVehicles.length} ${tr(languageCode, 'cars')})',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = _departureLocation;
    if (location == null) return const SizedBox.shrink();

    final availableCount = _availableVehicles(location).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          tr(languageCode, 'airport_transfer'),
          icon: Icons.airport_shuttle_rounded,
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer.withValues(alpha: .65),
                  theme.colorScheme.tertiaryContainer.withValues(alpha: .45),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: .85),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.local_taxi_rounded,
                        color: theme.colorScheme.primary,
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(languageCode, 'airport_transfer'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tr(languageCode, 'transfer_subtitle'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(Icons.flight_takeoff_rounded, size: 18),
                    label: Text(location.code),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 12),
                _PickupSummary(
                  airport: _localized(location.nameEn, location.nameTh),
                  pickup: _localized(location.pickupEn, location.pickupTh),
                  availableCount: availableCount,
                  languageCode: languageCode,
                ),
                if (reservation != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lock_rounded,
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
                            Flexible(
                              child: Text(
                                reservation!.vehicle.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${tr(languageCode, 'transfer_pickup_time')}: '
                          '${dateOf(reservation!.pickupTime)} · '
                          '${timeOf(reservation!.pickupTime)}',
                        ),
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
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: reservation == null
                        ? () => _scheduleTransfer(context, location)
                        : null,
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text(
                      tr(
                        languageCode,
                        reservation == null
                            ? 'transfer_schedule'
                            : 'transfer_locked',
                      ),
                    ),
                  ),
                ),
                if (reservation == null && widget.flightDepartureTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      tr(languageCode, 'transfer_auto_pickup'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showVehicles(context, location),
                    icon: const Icon(Icons.directions_car_filled_outlined),
                    label: Text(
                      '${tr(languageCode, 'transfer_view_cars')} '
                      '(${location.vehicles.length})',
                    ),
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

class _PickupSummary extends StatelessWidget {
  const _PickupSummary({
    required this.airport,
    required this.pickup,
    required this.availableCount,
    required this.languageCode,
  });

  final String airport;
  final String pickup;
  final int availableCount;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  airport,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${tr(languageCode, 'transfer_current_pickup')}: $pickup',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${tr(languageCode, 'available')} $availableCount '
              '${tr(languageCode, 'cars')}',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.languageCode,
    this.reserved = false,
  });

  final _TransferVehicle vehicle;
  final String languageCode;
  final bool reserved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = reserved ? Colors.blue : vehicle.status.color;

    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .55),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(vehicle.icon, color: statusColor),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${vehicle.name} · ${vehicle.model}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${tr(languageCode, 'driver')} ${vehicle.driver} · '
                        '${vehicle.plateNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    reserved
                        ? tr(languageCode, 'transfer_locked')
                        : vehicle.status.label(languageCode),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                if (vehicle.status == _TransferStatus.available && !reserved)
                  Text(
                    '${vehicle.etaMinutes} ${tr(languageCode, 'minutes')} · '
                    '${vehicle.seats} ${tr(languageCode, 'seats')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _TransferStatus { available, pickingUp, droppingOff, unavailable }

extension on _TransferStatus {
  Color get color => switch (this) {
    _TransferStatus.available => Colors.green,
    _TransferStatus.pickingUp || _TransferStatus.droppingOff => Colors.orange,
    _TransferStatus.unavailable => Colors.red,
  };

  String label(String languageCode) => switch (this) {
    _TransferStatus.available => tr(languageCode, 'available'),
    _TransferStatus.pickingUp => tr(languageCode, 'transfer_picking_up'),
    _TransferStatus.droppingOff => tr(languageCode, 'transfer_dropping_off'),
    _TransferStatus.unavailable => tr(languageCode, 'unavailable'),
  };
}

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

class _TransferReservation {
  const _TransferReservation({
    required this.vehicle,
    required this.pickupTime,
    required this.flightDepartureTime,
  });

  final _TransferVehicle vehicle;
  final DateTime pickupTime;
  final DateTime flightDepartureTime;
}

class _TransferLocation {
  const _TransferLocation({
    required this.code,
    required this.nameEn,
    required this.nameTh,
    required this.pickupEn,
    required this.pickupTh,
    required this.vehicles,
  });

  final String code;
  final String nameEn;
  final String nameTh;
  final String pickupEn;
  final String pickupTh;
  final List<_TransferVehicle> vehicles;
}

const _transferLocations = [
  _TransferLocation(
    code: 'BKK',
    nameEn: 'Suvarnabhumi Airport',
    nameTh: 'สนามบินสุวรรณภูมิ',
    pickupEn: 'Level 1, Gate 4',
    pickupTh: 'ชั้น 1 ประตู 4',
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
    code: 'CNX',
    nameEn: 'Chiang Mai International Airport',
    nameTh: 'สนามบินนานาชาติเชียงใหม่',
    pickupEn: 'Domestic Terminal, Gate 2',
    pickupTh: 'อาคารผู้โดยสารในประเทศ ประตู 2',
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
