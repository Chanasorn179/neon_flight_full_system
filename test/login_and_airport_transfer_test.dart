import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/neon_flight_app.dart';
import 'package:mini_projects/data/offline_mock_api.dart';
import 'package:mini_projects/models/travel_models.dart';
import 'package:mini_projects/providers/auth_provider.dart';
import 'package:mini_projects/providers/booking_provider.dart';
import 'package:mini_projects/providers/flight_provider.dart';
import 'package:mini_projects/providers/language_provider.dart';
import 'package:mini_projects/providers/settings_provider.dart';
import 'package:mini_projects/repositories/auth_repository.dart';
import 'package:mini_projects/repositories/booking_repository.dart';
import 'package:mini_projects/repositories/flight_repository.dart';
import 'package:mini_projects/screens/booking/booking_history_screen.dart';
import 'package:mini_projects/screens/home/airport_transfer_section.dart';
import 'package:mini_projects/services/road_distance_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    // SettingsProvider uses SharedPreferencesAsync, which has no platform
    // implementation in widget tests.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    // No network in tests: fall back to the straight-line distance.
    RoadDistanceService.debugLookup = (_, _, _, _) async => null;
  });
  tearDown(() => RoadDistanceService.debugLookup = null);

  testWidgets('Neon Flight login screen renders', (tester) async {
    final api = MockApi();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(MockAuthRepository(api)),
          ),
          ChangeNotifierProvider(
            create: (_) => FlightProvider(MockFlightRepository(api)),
          ),
          ChangeNotifierProvider(
            create: (_) => BookingProvider(MockBookingRepository(api)),
          ),
        ],
        child: const NeonFlightApp(),
      ),
    );
    await tester.pump();
    expect(find.text('NEON FLIGHT'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
  });

  testWidgets('airport transfer shows availability and books directly', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: AirportTransferSection(
              languageCode: 'th',
              departureAirportCode: 'BKK',
            ),
          ),
        ),
      ),
    );

    expect(find.text('รถบริการรับส่ง'), findsNWidgets(2));
    expect(find.text('รถว่างเหลือ 2 คัน'), findsOneWidget);
    expect(find.text('BKK'), findsOneWidget);
    expect(find.text('HKT'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.textContaining('ดูรถ'), findsNothing);
    expect(find.textContaining('Neon Car'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.byKey(const ValueKey('book-airport-transfer')));
    await tester.pumpAndSettle();

    expect(find.text('กรุณาจองเที่ยวบินก่อนจองรถรับส่ง'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('airport transfer follows the outbound departure airport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: AirportTransferSection(
              languageCode: 'th',
              departureAirportCode: 'HKT',
            ),
          ),
        ),
      ),
    );

    expect(find.text('HKT'), findsOneWidget);
    expect(find.text('สนามบินนานาชาติภูเก็ต'), findsOneWidget);
    expect(find.text('BKK'), findsNothing);
    expect(find.text('สนามบินสุวรรณภูมิ'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('รถว่างเหลือ 2 คัน'), findsOneWidget);
    expect(find.textContaining('ดูรถ'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AirportTransferSection(
            languageCode: 'th',
            departureAirportCode: 'UNKNOWN',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('รถบริการรับส่ง'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('airport transfer locks one car three hours before flight', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    TransferBookingEntity? savedTransfer;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AirportTransferSection(
              languageCode: 'th',
              departureAirportCode: 'BKK',
              flightDepartureTime: DateTime(2030, 1, 10, 11),
              userId: 'u1',
              onBooked: (booking) => savedTransfer = booking,
              gpsLocationLoader: () async => const GpsLocationEntity(
                latitude: 13.69,
                longitude: 100.75,
                accuracyMeters: 8,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('ระบบกำหนดเวลารับก่อนเที่ยวบิน 3 ชั่วโมงอัตโนมัติ'),
      findsOneWidget,
    );

    expect(find.textContaining('ยังไม่ได้ระบุตำแหน่ง'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('locate-airport-transfer')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('13.690000, 100.750000 · ความแม่นยำ ±8 m'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('book-airport-transfer')),
    );
    await tester.tap(find.byKey(const ValueKey('book-airport-transfer')));
    await tester.pumpAndSettle();

    expect(find.text('จองรถแล้ว'), findsWidgets);
    expect(find.text('เวลารับรถ: 10/01/2030 · 08:00'), findsOneWidget);
    expect(find.text('เวลาเที่ยวบิน: 10/01/2030 · 11:00'), findsOneWidget);
    expect(find.text('รถว่างเหลือ 1 คัน'), findsOneWidget);
    expect(find.textContaining('Neon Car'), findsNothing);
    expect(savedTransfer, isNotNull);
    expect(savedTransfer!.userId, 'u1');
    expect(savedTransfer!.airportCode, 'BKK');
    expect(savedTransfer!.pickupTime, DateTime(2030, 1, 10, 8));
    expect(savedTransfer!.pickupLocation.latitude, 13.69);
    expect(savedTransfer!.pickupLocation.longitude, 100.75);
    expect(savedTransfer!.distanceToAirportKm, lessThanOrEqualTo(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('airport transfer rejects GPS farther than 20 km', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    TransferBookingEntity? savedTransfer;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AirportTransferSection(
              languageCode: 'en',
              departureAirportCode: 'BKK',
              flightDepartureTime: DateTime(2030, 1, 10, 11),
              userId: 'u1',
              onBooked: (booking) => savedTransfer = booking,
              gpsLocationLoader: () async => const GpsLocationEntity(
                latitude: 13.914372,
                longitude: 100.605692,
                accuracyMeters: 8,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('book-airport-transfer')),
    );
    await tester.tap(find.byKey(const ValueKey('book-airport-transfer')));
    await tester.pumpAndSettle();

    expect(savedTransfer, isNull);
    expect(find.textContaining('Outside the service area'), findsWidgets);
    expect(
      find.byKey(const ValueKey('transfer-service-area-status')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('airport transfer accepts Don Mueang GPS for DMK', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    TransferBookingEntity? savedTransfer;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AirportTransferSection(
              languageCode: 'en',
              departureAirportCode: 'DMK',
              flightDepartureTime: DateTime(2030, 1, 10, 11),
              userId: 'u1',
              driverNotificationEnabled: true,
              onBooked: (booking) async => savedTransfer = booking,
              gpsLocationLoader: () async => const GpsLocationEntity(
                latitude: 13.914372,
                longitude: 100.605692,
                accuracyMeters: 8,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('book-airport-transfer')),
    );
    await tester.tap(find.byKey(const ValueKey('book-airport-transfer')));
    await tester.pumpAndSettle();

    expect(savedTransfer, isNotNull);
    expect(savedTransfer!.airportCode, 'DMK');
    expect(savedTransfer!.distanceToAirportKm, lessThan(0.1));
    expect(find.text('Transfer booked'), findsWidgets);
    expect(find.textContaining('Driver notified through LINE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transfer stays booked when LINE notification fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AirportTransferSection(
              languageCode: 'en',
              departureAirportCode: 'DMK',
              flightDepartureTime: DateTime(2030, 1, 10, 11),
              userId: 'u1',
              driverNotificationEnabled: true,
              onBooked: (_) async => throw Exception('LINE unavailable'),
              gpsLocationLoader: () async => const GpsLocationEntity(
                latitude: 13.914372,
                longitude: 100.605692,
                accuracyMeters: 8,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('book-airport-transfer')),
    );
    await tester.tap(find.byKey(const ValueKey('book-airport-transfer')));
    await tester.pumpAndSettle();

    expect(find.text('Transfer booked'), findsWidgets);
    expect(
      find.textContaining('Driver could not be notified through LINE'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking page shows airport transfer reservations', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final api = MockApi();
    final authProvider = AuthProvider(MockAuthRepository(api))
      ..currentUser = const UserEntity(
        id: 'u1',
        name: 'Aero Traveler',
        email: 'demo@neonflight.app',
      );
    final bookingProvider = BookingProvider(MockBookingRepository(api))
      ..addTransferBooking(
        TransferBookingEntity(
          id: 'NT203001100800',
          userId: 'u1',
          airportCode: 'BKK',
          airportNameEn: 'Suvarnabhumi Airport',
          airportNameTh: 'สนามบินสุวรรณภูมิ',
          pickupEn: 'Level 1, Gate 4',
          pickupTh: 'ชั้น 1 ประตู 4',
          pickupLocation: const GpsLocationEntity(
            latitude: 13.69,
            longitude: 100.75,
            accuracyMeters: 8,
          ),
          distanceToAirportKm: 1.1,
          pickupTime: DateTime(2030, 1, 10, 8),
          flightDepartureTime: DateTime(2030, 1, 10, 11),
          status: BookingStatus.upcoming,
          createdAt: DateTime(2029, 12, 1),
        ),
      );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: bookingProvider),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const MaterialApp(home: BookingHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('การจองรถรับส่ง'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('transfer-booking-NT203001100800')),
      findsOneWidget,
    );
    expect(find.text('รถบริการรับส่ง · BKK'), findsOneWidget);
    expect(
      find.text(
        'ตำแหน่ง GPS ปัจจุบัน: '
        '13.690000, 100.750000 · ความแม่นยำ ±8 m',
      ),
      findsOneWidget,
    );
    expect(find.text('เวลารับรถ: 10/01/2030 · 08:00'), findsOneWidget);
    expect(find.textContaining('Neon Car'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
