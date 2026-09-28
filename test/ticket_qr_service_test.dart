import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/services/ticket_qr_service.dart';

void main() {
  // backend/ticket_token.js must produce the same token (see
  // backend/payments.test.js); the server issues tickets under this ID.
  test('token matches the backend ticket issuer', () {
    expect(TicketQrService.tokenForBookingId('NF12345678'), '6088A39DA44E');
    expect(
      TicketQrService.publicDocumentId('NF12345678'),
      'NF12345678_6088A39DA44E',
    );
  });
}
