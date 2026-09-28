const crypto = require('node:crypto');

// Must match TicketQrService.tokenForBookingId in
// lib/services/ticket_qr_service.dart, or issued QR codes will not verify.
// Use the same TICKET_SIGNING_SECRET as the Flutter build (empty = plain SHA-256).
function tokenForBookingId(bookingId, secret = process.env.TICKET_SIGNING_SECRET || '') {
  const normalized = String(bookingId).trim();
  const digest = secret
    ? crypto.createHmac('sha256', secret).update(normalized, 'utf8').digest('hex')
    : crypto.createHash('sha256').update(normalized, 'utf8').digest('hex');
  return digest.slice(0, 12).toUpperCase();
}

function publicDocumentId(bookingId, secret) {
  const id = String(bookingId).trim();
  return `${id}_${tokenForBookingId(id, secret)}`;
}

module.exports = { tokenForBookingId, publicDocumentId };
