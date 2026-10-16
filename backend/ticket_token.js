const crypto = require('node:crypto');

// New tickets get a random token when an admin confirms payment. It is
// written to bookings/{id}.ticketToken (readable only by the owner) and is
// part of the publicTickets/{id}_{token} document ID, so knowing a booking ID
// is not enough to read its public record.
function newTicketToken() {
  return crypto.randomBytes(8).toString('hex').toUpperCase();
}

// Legacy scheme for tickets confirmed before random tokens: derived from the
// booking ID (plain SHA-256 unless TICKET_SIGNING_SECRET is set). Must match
// TicketQrService.legacyTokenForBookingId in lib/services/ticket_qr_service.dart.
function tokenForBookingId(bookingId, secret = process.env.TICKET_SIGNING_SECRET || '') {
  const normalized = String(bookingId).trim();
  const digest = secret
    ? crypto.createHmac('sha256', secret).update(normalized, 'utf8').digest('hex')
    : crypto.createHash('sha256').update(normalized, 'utf8').digest('hex');
  return digest.slice(0, 12).toUpperCase();
}

function publicDocumentId(bookingId, token) {
  return `${String(bookingId).trim()}_${token}`;
}

module.exports = { newTicketToken, tokenForBookingId, publicDocumentId };
