import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/mock_api.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/flight_provider.dart';
import 'providers/language_provider.dart';
import 'providers/payment_methods_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/booking_repository.dart';
import 'repositories/flight_repository.dart';
import 'services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseService.initialize();

  final api = MockApi();

  final AuthRepository authRepository =
  FirebaseService.enabled
      ? FirebaseAuthRepository()
      : MockAuthRepository(api);

  final BookingRepository bookingRepository =
  FirebaseService.enabled
      ? FirebaseBookingRepository()
      : MockBookingRepository(api);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(),
        ),

        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),

        ChangeNotifierProvider(
          create: (_) =>
              AuthProvider(authRepository),
        ),

        ChangeNotifierProvider(
          create: (_) => FlightProvider(
            HybridFlightRepository(api),
          ),
        ),

        ChangeNotifierProvider(
          create: (_) => BookingProvider(
            bookingRepository,
          ),
        ),

        ChangeNotifierProvider(
          create: (_) =>
              PaymentMethodsProvider(),
        ),

        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: const NeonFlightApp(),
    ),
  );
}