import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/data/offline_mock_api.dart';
import 'package:mini_projects/models/app_notice.dart';
import 'package:mini_projects/models/travel_models.dart';
import 'package:mini_projects/providers/booking_provider.dart';
import 'package:mini_projects/providers/language_provider.dart';
import 'package:mini_projects/providers/settings_provider.dart';
import 'package:mini_projects/repositories/booking_repository.dart';
import 'package:mini_projects/widgets/notification_bell.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final now = DateTime(2026, 11, 19, 12);

BookingEntity booking(
  String id, {
  required DateTime departs,
  PaymentStatus payment = PaymentStatus.pending,
  BookingStatus status = BookingStatus.upcoming,
  String? tripId,
}) =>
    BookingEntity(
      id: id,
      userId: 'u1',
      flight: FlightEntity(
        id: id,
        airline: 'Thai Airways',
        flightNumber: 'TG100',
        departure: const AirportEntity(code: 'BKK', cityEn: '', cityTh: '', nameEn: '', nameTh: ''),
        arrival: const AirportEntity(code: 'CNX', cityEn: '', cityTh: '', nameEn: '', nameTh: ''),
        departureTime: departs,
        arrivalTime: departs.add(const Duration(hours: 1)),
        basePrice: 1000,
        availableSeats: 10,
      ),
      cabinClass: CabinClass.economy,
      passengers: const [],
      seats: const ['1A'],
      fare: const FareBreakdown(fare: 1000, tax: 0, service: 0, seatFee: 0),
      paymentMethod: PaymentMethod.promptPay,
      status: status,
      createdAt: DateTime(2026, 10, 1),
      paymentStatus: payment,
      tripId: tripId,
    );

void main() {
  test('notices reflect booking state, most urgent first', () {
    final notices = AppNotice.fromBookings([
      booking('NF1', departs: DateTime(2026, 11, 20, 8), payment: PaymentStatus.paid),
      booking('NF2', departs: DateTime(2026, 12, 20, 8)),
      booking('NF3', departs: DateTime(2026, 12, 20, 8), status: BookingStatus.cancelled),
      booking('NF4', departs: DateTime(2026, 1, 1), payment: PaymentStatus.paid), // past
    ], now);

    expect(notices.map((n) => n.id), [
      'NF1_departingSoon',
      'NF2_paymentPending',
      'NF1_paid',
      'NF3_cancelled',
    ]);
  });

  test('a round trip yields one payment notice, not one per leg', () {
    final notices = AppNotice.fromBookings([
      booking('NF5', departs: DateTime(2026, 12, 1), tripId: 'NF5'),
      booking('NF5R', departs: DateTime(2026, 12, 5), tripId: 'NF5'),
    ], now);
    expect(notices.map((n) => n.id), ['NF5_paymentPending']);
  });

  testWidgets('bell shows unseen count until the list is opened', (tester) async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    final provider = BookingProvider(MockBookingRepository(MockApi()))
      ..bookings = [
        booking('NF2', departs: DateTime.now().add(const Duration(days: 30))),
      ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: const MaterialApp(home: Scaffold(body: Center(child: NotificationBell()))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byType(NotificationBell));
    await tester.pumpAndSettle();
    expect(find.text('NF2', findRichText: false), findsNothing); // shown inside body text
    expect(find.textContaining('NF2'), findsOneWidget);

    Navigator.of(tester.element(find.textContaining('NF2'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('1'), findsNothing);
  });
}
