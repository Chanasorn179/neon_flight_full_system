import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/mock_api.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/flight_provider.dart';
import 'providers/language_provider.dart';
import 'providers/settings_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/booking_repository.dart';
import 'repositories/flight_repository.dart';
import 'providers/theme_provider.dart';

void main() {
  final api = MockApi();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(MockAuthRepository(api))),
        ChangeNotifierProvider(create: (_) => FlightProvider(MockFlightRepository(api))),
        ChangeNotifierProvider(create: (_) => BookingProvider(MockBookingRepository(api))),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const NeonFlightApp(),
    ),
  );
}
