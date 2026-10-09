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
import 'package:mini_projects/screens/auth/register_screen.dart';
import 'package:mini_projects/screens/booking/booking_history_screen.dart';
import 'package:mini_projects/screens/booking/passenger_screen.dart';
import 'package:mini_projects/screens/booking/payment_screen.dart';
import 'package:mini_projects/screens/booking/seat_selection_screen.dart';
import 'package:mini_projects/screens/booking/takeoff_screen.dart';
import 'package:mini_projects/screens/booking/ticket_screen.dart';
import 'package:mini_projects/screens/flights/flight_results_screen.dart';
import 'package:mini_projects/screens/home/main_shell.dart';
import 'package:mini_projects/screens/profile/payment_methods_screen.dart';
import 'package:mini_projects/screens/profile/profile_screen.dart';
import 'package:mini_projects/widgets/notification_bell.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _phone = Size(390, 844);

/// Small Android phone; layout overflow fails the test here.
const _narrow = Size(320, 640);

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

extension on PassengerEntity {
  PassengerEntity copyWithName(String first) => PassengerEntity(
        title: title,
        firstName: first,
        lastName: lastName,
        birthDate: birthDate,
        nationality: nationality,
        passportNumber: passportNumber,
        passportExpiry: passportExpiry,
        phone: phone,
        email: email,
      );
}

void main() {
  late MockApi api;
  late AuthProvider auth;
  late FlightProvider flights;
  late BookingProvider bookings;
  late PaymentMethodsProvider methods;
  late FlightEntity flight;

  setUpAll(() async {
    // flutter_map's tile cache asks path_provider for a folder.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
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
    methods = PaymentMethodsProvider();
    flight = (await api.searchFlights('BKK', 'CNX', DateTime(2026, 11, 20)))[1];
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget Function() screen, {
    bool loggedIn = true,
    Future<void> Function()? prepare,
    Future<void> Function(WidgetTester tester)? act,
    Size size = _phone,
    String lang = 'th',
  }) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.binding.setSurfaceSize(size);
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      await tester.runAsync(() async {
        if (loggedIn && auth.currentUser == null) {
          await auth.login('demo@neonflight.app', 'secret1');
        }
        await flights.loadAirports();
        await prepare?.call();
      });
      final languages = LanguageProvider()..setLanguage(lang);
      // Fresh widget state for each theme (no carry-over between runs).
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: languages),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: flights),
            ChangeNotifierProvider.value(value: bookings),
            ChangeNotifierProvider.value(value: methods),
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
      if (act != null) {
        await act(tester);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/${name}_${mode.name}.png'),
      );
    }
  }

  testWidgets('login', (t) => shoot(t, 'login', () => const LoginScreen(), loggedIn: false));
  testWidgets('register_narrow', (t) => shoot(t, 'register_narrow', () => const RegisterScreen(), loggedIn: false, size: _narrow));
  testWidgets('login_narrow_en', (t) => shoot(t, 'login_narrow_en', () => const LoginScreen(), loggedIn: false, size: _narrow, lang: 'en'));
  for (final (name, size, lang) in [
    ('passenger', _phone, 'th'),
    ('passenger_narrow', _narrow, 'th'),
    ('passenger_narrow_ja', _narrow, 'ja'),
  ]) {
    testWidgets(name, (t) => shoot(
          t,
          name,
          () => PassengerScreen(
            flight: flight,
            cabinClass: CabinClass.economy,
            debugSavedPassengers: [passenger],
          ),
          size: size,
          lang: lang,
        ));
  }
  testWidgets('home_narrow', (t) => shoot(t, 'home_narrow', () => const MainShell(), size: _narrow));
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
  testWidgets('seats_full', (t) => shoot(
        t,
        'seats_full',
        size: const Size(390, 1500),
        () => SeatSelectionScreen(
          flight: flight,
          cabinClass: CabinClass.economy,
          passengers: [
            passenger,
            passenger.copyWithName('Somchai'),
            passenger.copyWithName('Mali'),
          ],
        ),
        act: (t) async {
          await t.tap(find.bySemanticsLabel('Seat 4C'));
          await t.tap(find.bySemanticsLabel('Seat 4D'));
        },
      ));
  testWidgets('seats_takeoff', (t) => shoot(
        t,
        'seats_takeoff',
        () => SeatSelectionScreen(
          flight: flight,
          cabinClass: CabinClass.economy,
          passengers: [passenger],
        ),
        // Light run selects the seat (plays the take-off); dark run deselects.
        act: (t) async {
          await t.tap(find.bySemanticsLabel('Seat 6C'));
          await t.pump(const Duration(milliseconds: 300));
        },
      ));
  testWidgets('takeoff_pass', (t) => shoot(
        t,
        'takeoff_pass',
        () => TakeoffScreen(
          flight: flight,
          seats: const ['4C'],
          next: const Scaffold(body: Center(child: Text('next'))),
        ),
      ));
  testWidgets('globe_intro', (t) => shoot(
        t,
        'globe_intro',
        () => TakeoffScreen(
          flight: flight,
          seats: const ['4C'],
          next: const Scaffold(body: Center(child: Text('next'))),
        ),
        act: (t) async {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
          await t.pump(const Duration(milliseconds: 300));
        },
      ));
  testWidgets('globe_start', (t) => shoot(
        t,
        'globe_start',
        () => TakeoffScreen(
          flight: flight,
          seats: const ['4C'],
          next: const Scaffold(body: Center(child: Text('next'))),
        ),
        act: (t) async {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
          for (var i = 0; i < 16; i++) {
            await t.pump(const Duration(milliseconds: 100));
          }
        },
      ));
  testWidgets('globe_mid', (t) => shoot(
        t,
        'globe_mid',
        () => TakeoffScreen(
          flight: flight,
          seats: const ['4C'],
          next: const Scaffold(body: Center(child: Text('next'))),
        ),
        act: (t) async {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
          for (var i = 0; i < 36; i++) {
            await t.pump(const Duration(milliseconds: 100));
          }
        },
      ));
  testWidgets('globe_dive', (t) => shoot(
        t,
        'globe_dive',
        () => TakeoffScreen(
          flight: flight,
          seats: const ['4C'],
          next: const Scaffold(body: Center(child: Text('next'))),
        ),
        act: (t) async {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
          for (var i = 0; i < 53; i++) {
            await t.pump(const Duration(milliseconds: 100));
          }
        },
      ));
  testWidgets('dest_map', (t) => shoot(
        t,
        'dest_map',
        () => TakeoffScreen(
          flight: flight,
          seats: const ['4C'],
          next: const Scaffold(body: Center(child: Text('next'))),
        ),
        act: (t) async {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
          for (var i = 0; i < 68; i++) {
            await t.pump(const Duration(milliseconds: 100));
          }
        },
      ));
  testWidgets('seats_business', (t) => shoot(
        t,
        'seats_business',
        () => SeatSelectionScreen(
          flight: flight,
          cabinClass: CabinClass.business,
          passengers: [passenger],
        ),
        act: (t) async => t.tap(find.bySemanticsLabel('Seat 2C')),
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
  testWidgets('notifications', (t) => shoot(
        t,
        'notifications',
        () => const MainShell(),
        prepare: () async {
          // Runs for light and dark; seed once (seat locks reject a repeat).
          if ((await api.bookings(auth.currentUser!.id)).isNotEmpty) return;
          final soon = await api.searchFlights(
            'BKK',
            'CNX',
            DateTime.now().add(const Duration(days: 1)),
          );
          await api.createBookings([
            booking(PaymentStatus.pending),
            BookingEntity(
              id: 'NF55501234',
              userId: auth.currentUser!.id,
              flight: soon.first,
              cabinClass: CabinClass.economy,
              passengers: [passenger],
              seats: const ['3A'],
              fare: const FareBreakdown(fare: 2000, tax: 700, service: 150, seatFee: 200),
              paymentMethod: PaymentMethod.promptPay,
              status: BookingStatus.upcoming,
              createdAt: DateTime(2026, 10, 2),
              paymentStatus: PaymentStatus.paid,
            ),
          ]);
        },
        act: (t) async => t.tap(find.byType(NotificationBell)),
      ));

  Future<void> seedMethods() async {
    if (methods.methods.length > 1) return;
    await methods.load(auth.currentUser!.id);
    await methods.add(
      const SavedPaymentMethodEntity(
        id: 'card-visa',
        type: SavedPaymentType.card,
        label: 'Visa',
        detail: '•••• 4242 · 12/29',
      ),
      makeDefault: true,
    );
    await methods.add(const SavedPaymentMethodEntity(
      id: 'card-jcb',
      type: SavedPaymentType.card,
      label: 'JCB',
      detail: '•••• 0518 · 03/28',
    ));
    await methods.add(const SavedPaymentMethodEntity(
      id: 'bank-kbank',
      type: SavedPaymentType.mobileBanking,
      label: 'Mobile Banking',
      detail: 'Kasikornbank (K PLUS)',
    ));
  }

  testWidgets('payment_methods', (t) => shoot(
        t,
        'payment_methods',
        () => const PaymentMethodsScreen(),
        prepare: seedMethods,
      ));
  testWidgets('add_card', (t) => shoot(
        t,
        'add_card',
        () => const PaymentMethodsScreen(),
        prepare: seedMethods,
        act: (t) async {
          if (find.byType(AddPaymentMethodSheet).evaluate().isEmpty) {
            await t.tap(find.byType(FloatingActionButton));
            await t.pumpAndSettle();
            await t.tap(find.text('Mastercard'));
            final fields = find.byType(TextFormField);
            await t.enterText(fields.at(0), '7788');
            await t.enterText(fields.at(1), '1130');
          }
        },
      ));
  testWidgets('payment_saved', (t) => shoot(
        t,
        'payment_saved',
        () => PaymentScreen(
          flight: flight,
          cabinClass: CabinClass.economy,
          passengers: [passenger],
          seats: const ['12C'],
        ),
        prepare: seedMethods,
      ));
  testWidgets('profile', (t) => shoot(t, 'profile', () => const Scaffold(body: ProfileScreen())));
}
