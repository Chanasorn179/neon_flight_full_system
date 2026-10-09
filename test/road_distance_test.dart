import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/models/travel_models.dart';
import 'package:mini_projects/screens/home/airport_transfer_section.dart';
import 'package:mini_projects/services/road_distance_service.dart';

void main() {
  tearDown(() => RoadDistanceService.debugLookup = null);

  test('parses the first OSRM route', () {
    final route = RoadDistanceService.parse(
      '{"code":"Ok","routes":[{"distance":30012.4,"duration":2520.2}]}',
    );
    expect(route!.distanceKm, closeTo(30.01, .01));
    expect(route.duration, const Duration(seconds: 2520));
    expect(RoadDistanceService.parse('{"code":"NoRoute","routes":[]}'), isNull);
  });

  Future<TransferBookingEntity?> book(
    WidgetTester tester,
    RoadRoute route,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    RoadDistanceService.debugLookup = (_, _, _, _) async => route;
    TransferBookingEntity? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AirportTransferSection(
              languageCode: 'en',
              departureAirportCode: 'BKK',
              flightDepartureTime: DateTime(2030, 1, 10, 11),
              onBooked: (b) => saved = b,
              // ~9 km from Suvarnabhumi in a straight line.
              gpsLocationLoader: () async => const GpsLocationEntity(
                latitude: 13.7300,
                longitude: 100.6800,
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
    return saved;
  }

  testWidgets('service area uses the road distance, not the straight line', (
    tester,
  ) async {
    final saved = await book(
      tester,
      const RoadRoute(distanceKm: 25, duration: Duration(minutes: 35)),
    );
    expect(saved, isNull);
    expect(find.textContaining('25.0 km by road'), findsOneWidget);
  });

  testWidgets('booking records the road distance', (tester) async {
    final saved = await book(
      tester,
      const RoadRoute(distanceKm: 12.4, duration: Duration(minutes: 18)),
    );
    expect(saved!.distanceToAirportKm, 12.4);
    expect(find.textContaining('about 18 min'), findsOneWidget);
  });
}
