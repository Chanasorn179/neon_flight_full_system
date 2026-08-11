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
import 'package:mini_projects/screens/booking/booking_history_screen.dart';
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

  testWidgets('Booking history switches between all status tabs', (
    tester,
  ) async {
    final api = MockApi();
    final auth = AuthProvider(MockAuthRepository(api));
    final booking = BookingProvider(MockBookingRepository(api));
    await auth.login('demo@neonflight.app', '1234');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: booking),
        ],
        child: const MaterialApp(home: BookingHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('booking-tab-upcoming')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-card-NF260801')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('booking-tab-completed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('booking-card-NF260614')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('booking-tab-cancelled')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('booking-card-NF260722')), findsOneWidget);
  });
}
