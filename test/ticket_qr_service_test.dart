import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/models/travel_models.dart';
import 'package:mini_projects/services/ticket_qr_service.dart';

void main() {
  // backend/ticket_token.js must produce the same legacy token (see
  // backend/payment_admin.test.js); tickets confirmed before random tokens
  // existed are stored under it.
  test('legacy token matches the backend ticket issuer', () {
    expect(
      TicketQrService.legacyTokenForBookingId('NF12345678'),
      '6088A39DA44E',
    );
    expect(
      TicketQrService.publicDocumentId('NF12345678', '6088A39DA44E'),
      'NF12345678_6088A39DA44E',
    );
  });

  test('server-issued token is used in the QR and accepted offline', () {
    const issued = '0123456789ABCDEF';
    final url = TicketQrService.encode(_booking(ticketToken: issued));
    expect(url, 'https://neon-flight.web.app/t/NF12345678?token=$issued');

    final result = TicketQrService.verify(url);
    expect(result.valid, isTrue);
    expect(result.data, {'bookingId': 'NF12345678', 'token': issued});
  });

  test('booking without an issued token falls back to the legacy token', () {
    expect(
      TicketQrService.encode(_booking()),
      'https://neon-flight.web.app/t/NF12345678?token=6088A39DA44E',
    );
  });

  test('malformed tokens are rejected before any lookup', () {
    final result = TicketQrService.verify(
      'https://neon-flight.web.app/t/NF12345678?token=NOT-A-TOKEN',
    );
    expect(result.valid, isFalse);
    expect(result.message, 'qr_bad_token');
  });
}

BookingEntity _booking({String? ticketToken}) {
  const airport = AirportEntity(
    code: 'BKK',
    cityEn: 'Bangkok',
    cityTh: 'กรุงเทพฯ',
    nameEn: 'Suvarnabhumi',
    nameTh: 'สุวรรณภูมิ',
  );
  return BookingEntity(
    id: 'NF12345678',
    userId: 'u1',
    flight: FlightEntity(
      id: 'f1',
      flightNumber: 'TG102',
      airline: 'Thai Airways',
      departure: airport,
      arrival: airport,
      departureTime: DateTime(2026, 11, 20, 8),
      arrivalTime: DateTime(2026, 11, 20, 9),
      basePrice: 1000,
      availableSeats: 10,
    ),
    cabinClass: CabinClass.economy,
    passengers: const [],
    seats: const ['1A'],
    fare: const FareBreakdown(fare: 1000, tax: 0, service: 0, seatFee: 0),
    paymentMethod: PaymentMethod.promptPay,
    status: BookingStatus.upcoming,
    createdAt: DateTime(2026, 10, 1),
    paymentStatus: PaymentStatus.paid,
    ticketToken: ticketToken,
  );
}
