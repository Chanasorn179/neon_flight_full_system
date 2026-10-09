const test = require('node:test');
const assert = require('node:assert/strict');

const { tokenForBookingId, publicDocumentId } = require('./ticket_token');
const { publicTicketFor } = require('./scripts/payment_admin');

test('ticket token matches the Flutter TicketQrService', () => {
  // Same values are asserted in test/ticket_qr_service_test.dart.
  assert.equal(tokenForBookingId('NF12345678', ''), '6088A39DA44E');
  assert.equal(tokenForBookingId(' NF12345678 ', ''), '6088A39DA44E');
  assert.equal(tokenForBookingId('NF12345678', 'test-secret'), 'A3C3ED0F3759');
  assert.equal(publicDocumentId('NF12345678', ''), 'NF12345678_6088A39DA44E');
});

test('public ticket exposes only verification fields', () => {
  const ticket = publicTicketFor('NF1', {
    userId: 'u1',
    flight: { flightNumber: 'TG102', departureCode: 'BKK', arrivalCode: 'CNX' },
    passengers: [{ title: 'Ms.', firstName: 'Anong', lastName: 'Sukjai', passportNumber: 'AA1234567' }],
    seats: ['5A'],
    cabinClass: 'economy',
    status: 'upcoming',
    fare: { total: 3200 },
  });

  assert.deepEqual(ticket, {
    bookingId: 'NF1',
    flightNumber: 'TG102',
    departureCode: 'BKK',
    arrivalCode: 'CNX',
    passengerName: 'Ms. Anong Sukjai',
    seats: ['5A'],
    cabinClass: 'economy',
    status: 'upcoming',
  });
});
