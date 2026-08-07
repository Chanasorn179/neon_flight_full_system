import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/app.dart';
import 'package:mini_projects/data/mock_api.dart';
import 'package:mini_projects/providers/auth_provider.dart';
import 'package:mini_projects/providers/booking_provider.dart';
import 'package:mini_projects/providers/flight_provider.dart';
import 'package:mini_projects/providers/language_provider.dart';
import 'package:mini_projects/providers/settings_provider.dart';
import 'package:mini_projects/repositories/auth_repository.dart';
import 'package:mini_projects/repositories/booking_repository.dart';
import 'package:mini_projects/repositories/flight_repository.dart';
import 'package:mini_projects/screens/home/airport_transfer_section.dart';
import 'package:provider/provider.dart';

void main() {
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

  testWidgets('airport transfer shows cars and calls one available car', (
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
    expect(find.text('ว่าง 2 คัน'), findsOneWidget);
    expect(find.text('BKK'), findsOneWidget);
    expect(find.text('HKT'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(find.text('ดูรถทั้งหมด (5)'));
    await tester.pumpAndSettle();

    final vehicleList = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('กำลังไปรับลูกค้า'),
      120,
      scrollable: vehicleList,
    );
    expect(find.text('กำลังไปรับลูกค้า'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('กำลังไปส่งลูกค้า'),
      120,
      scrollable: vehicleList,
    );
    expect(find.text('กำลังไปส่งลูกค้า'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('ไม่ว่าง'),
      120,
      scrollable: vehicleList,
    );
    expect(find.text('ไม่ว่าง'), findsOneWidget);

    await tester.tap(find.text('เรียกรถว่าง (2 คัน)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('กำลังมารับคุณที่'), findsOneWidget);
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
    expect(find.text('ดูรถทั้งหมด (3)'), findsOneWidget);

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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AirportTransferSection(
              languageCode: 'th',
              departureAirportCode: 'BKK',
              flightDepartureTime: DateTime(2030, 1, 10, 11),
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('ระบบกำหนดเวลารับก่อนเที่ยวบิน 3 ชั่วโมงอัตโนมัติ'),
      findsOneWidget,
    );

    await tester.tap(find.text('จองรถรับส่ง'));
    await tester.pumpAndSettle();

    expect(find.text('ล็อกรถแล้ว'), findsWidgets);
    expect(find.text('เวลารับรถ: 10/01/2030 · 08:00'), findsOneWidget);
    expect(find.text('เวลาเที่ยวบิน: 10/01/2030 · 11:00'), findsOneWidget);
    expect(find.text('ว่าง 1 คัน'), findsOneWidget);
    expect(
      find.text('Neon Car 01').evaluate().isNotEmpty ||
          find.text('Neon Car 05').evaluate().isNotEmpty,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
