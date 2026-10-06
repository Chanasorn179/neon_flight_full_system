// Renders the main screens to PNGs with real fonts, for visual review.
//
//   flutter test test/screenshots --run-skipped --update-goldens
//
// Output: test/screenshots/out/<screen>_<light|dark>.png (gitignored).
// Uses Windows' Leelawadee UI for Thai text, so it only runs on Windows.
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/core/theme.dart';
import 'package:mini_projects/data/mock_api.dart';
import 'package:mini_projects/models/entities.dart';
import 'package:mini_projects/providers/auth_provider.dart';
import 'package:mini_projects/providers/booking_provider.dart';
import 'package:mini_projects/providers/flight_provider.dart';
import 'package:mini_projects/providers/language_provider.dart';
import 'package:mini_projects/providers/payment_methods_provider.dart';
import 'package:mini_projects/providers/settings_provider.dart';
import 'package:mini_projects/providers/theme_provider.dart';
import 'package:mini_projects/repositories/auth_repository.dart';
import 'package:mini_projects/repositories/booking_repository.dart';
import 'package:mini_projects/repositories/flight_repository.dart';
import 'package:mini_projects/screens/auth/login_screen.dart';
import 'package:mini_projects/screens/booking/booking_history_screen.dart';
import 'package:mini_projects/screens/booking/payment_screen.dart';
import 'package:mini_projects/screens/booking/seat_selection_screen.dart';
import 'package:mini_projects/screens/booking/ticket_screen.dart';
import 'package:mini_projects/screens/flights/flight_results_screen.dart';
import 'package:mini_projects/screens/home/main_shell.dart';
import 'package:mini_projects/screens/profile/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _phone = Size(390, 844);

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

final passenger = PassengerEntity(
  title: 'Ms.',
  firstName: 'Anong',
  lastName: 'Sukjai',
  birthDate: DateTime(1998, 4, 2),
  nationality: 'Thai',
  passportNumber: 'AA1234567',
  passportExpiry: DateTime(2031, 1, 1),
  phone: '0812345678',
  email: 'anong@example.com',
);

void main() {
  late MockApi api;
  late AuthProvider auth;
  late FlightProvider flights;
  late BookingProvider bookings;
  late FlightEntity flight;

  setUpAll(() async {
    const fonts = 'C:/Windows/Fonts';
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
    await _loadFont('Roboto', ['$fonts/LeelawUI.ttf', '$fonts/LeelaUIb.ttf']);
    await _loadFont('MaterialIcons', [
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    api = MockApi();
    auth = AuthProvider(MockAuthRepository(api));
    flights = FlightProvider(MockFlightRepository(api));
    bookings = BookingProvider(MockBookingRepository(api));
    flight = (await api.searchFlights('BKK', 'CNX', DateTime(2026, 11, 20)))[1];
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget Function() screen, {
    bool loggedIn = true,
    Future<void> Function()? prepare,
  }) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.binding.setSurfaceSize(_phone);
      tester.view.physicalSize = _phone * 3;
      tester.view.devicePixelRatio = 3;
      await tester.runAsync(() async {
        if (loggedIn && auth.currentUser == null) {
          await auth.login('demo@neonflight.app', 'secret1');
        }
        await flights.loadAirports();
        await prepare?.call();
      });
      final languages = LanguageProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: languages),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: flights),
            ChangeNotifierProvider.value(value: bookings),
            ChangeNotifierProvider(create: (_) => PaymentMethodsProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: screen(),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/${name}_${mode.name}.png'),
      );
    }
  }

  testWidgets('login', (t) => shoot(t, 'login', () => const LoginScreen(), loggedIn: false));
  testWidgets('home', (t) => shoot(t, 'home', () => const MainShell()));
  testWidgets('results', (t) => shoot(
        t,
        'results',
        () => const FlightResultsScreen(),
        prepare: () async {
          flights.setRoute('BKK', 'CNX');
          flights.setDeparture(DateTime(2026, 11, 20));
          await flights.search();
        },
      ));
  testWidgets('seats', (t) => shoot(
        t,
        'seats',
        () => SeatSelectionScreen(
          flight: flight,
          cabinClass: CabinClass.economy,
          passengers: [passenger],
        ),
      ));
  testWidgets('payment', (t) => shoot(
        t,
        'payment',
        () => PaymentScreen(
          flight: flight,
          cabinClass: CabinClass.economy,
          passengers: [passenger],
          seats: const ['12C'],
        ),
      ));
  BookingEntity booking(PaymentStatus status) => BookingEntity(
        id: 'NF12345678',
        userId: auth.currentUser?.id ?? 'u1',
        flight: flight,
        cabinClass: CabinClass.economy,
        passengers: [passenger],
        seats: const ['12C'],
        fare: const FareBreakdown(fare: 2450, tax: 700, service: 150, seatFee: 200),
        paymentMethod: PaymentMethod.promptPay,
        status: BookingStatus.upcoming,
        createdAt: DateTime(2026, 10, 6),
        paymentStatus: status,
      );
  testWidgets('ticket_pending', (t) => shoot(
        t,
        'ticket_pending',
        () => TicketScreen(booking: booking(PaymentStatus.pending)),
      ));
  testWidgets('ticket_paid', (t) => shoot(
        t,
        'ticket_paid',
        () => TicketScreen(booking: booking(PaymentStatus.paid)),
      ));
  testWidgets('history', (t) => shoot(
        t,
        'history',
        () => const Scaffold(body: BookingHistoryScreen()),
        prepare: () async {
          bookings.bookings = [booking(PaymentStatus.pending), booking(PaymentStatus.paid)];
        },
      ));
  testWidgets('profile', (t) => shoot(t, 'profile', () => const Scaffold(body: ProfileScreen())));
}
