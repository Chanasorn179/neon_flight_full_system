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
import 'package:provider/provider.dart';

void main() {
  testWidgets('Neon Flight login screen renders', (tester) async {
    final api = MockApi();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider(MockAuthRepository(api))),
          ChangeNotifierProvider(create: (_) => FlightProvider(MockFlightRepository(api))),
          ChangeNotifierProvider(create: (_) => BookingProvider(MockBookingRepository(api))),
        ],
        child: const NeonFlightApp(),
      ),
    );
    await tester.pump();
    expect(find.text('NEON FLIGHT'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
  });
}
