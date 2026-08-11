import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_projects/models/entities.dart';
import 'package:mini_projects/services/transfer_dispatch_service.dart';

void main() {
  final booking = TransferBookingEntity(
    id: 'NT123',
    userId: 'u1',
    airportCode: 'DMK',
    airportNameEn: 'Don Mueang International Airport',
    airportNameTh: 'ท่าอากาศยานดอนเมือง',
    pickupEn: 'Terminal 2, Gate 12',
    pickupTh: 'อาคาร 2 ประตู 12',
    pickupLocation: const GpsLocationEntity(
      latitude: 13.914372,
      longitude: 100.605692,
      accuracyMeters: 5,
    ),
    distanceToAirportKm: 0,
    pickupTime: DateTime(2030, 1, 10, 8),
    flightDepartureTime: DateTime(2030, 1, 10, 11),
    status: BookingStatus.upcoming,
    createdAt: DateTime(2029, 12, 1),
  );

  test(
    'sends only booking identity, contact and pickup GPS to backend',
    () async {
      late Map<String, dynamic> requestBody;
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'http://localhost:5000/api/transfer-bookings',
        );
        expect(request.headers['x-dispatch-key'], 'test-key');
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{ok:true}', 201);
      });
      final service = TransferDispatchService(
        client: client,
        apiBaseUrl: 'http://localhost:5000/api',
        dispatchApiKey: 'test-key',
      );

      await service.notifyDriver(
        booking: booking,
        passengerName: 'Somchai Jaidee',
        passengerPhone: '081-234-5678',
      );

      expect(requestBody, {
        'bookingId': 'NT123',
        'userId': 'u1',
        'passengerName': 'Somchai Jaidee',
        'passengerPhone': '081-234-5678',
        'latitude': 13.914372,
        'longitude': 100.605692,
      });
    },
  );

  test('throws when backend cannot notify the driver', () async {
    final service = TransferDispatchService(
      client: MockClient((_) async => http.Response('failed', 502)),
      apiBaseUrl: 'http://localhost:5000/api',
      dispatchApiKey: 'test-key',
    );

    expect(
      () => service.notifyDriver(
        booking: booking,
        passengerName: 'Somchai Jaidee',
        passengerPhone: '081-234-5678',
      ),
      throwsA(isA<TransferDispatchException>()),
    );
  });
}
