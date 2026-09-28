// Admin tool: confirm payments and issue E-tickets.
//
// The app can only create bookings with paymentStatus 'pending'
// (see firestore.rules). After checking that the money arrived in the
// PromptPay/bank account, an admin confirms the booking here. That marks it
// paid and creates publicTickets/{bookingId_token}, which the app and the
// hosted verification page use to show a VALID ticket.
//
// PowerShell (from backend/):
//   $env:GOOGLE_APPLICATION_CREDENTIALS='C:\path\to\service-account.json'
//   $env:TICKET_SIGNING_SECRET='...'   # only if the Flutter build uses one
//   node scripts/payments.js list
//   node scripts/payments.js confirm NF12345678
//   node scripts/payments.js reject NF12345678

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { publicDocumentId } = require('../ticket_token');

function text(value, fallback = '-') {
  const s = value == null ? '' : String(value).trim();
  return s && s !== '-' ? s : fallback;
}

// Builds the public verification record. Keep the field names in sync with
// web_ticket/index.html and lib/screens/booking/ticket_scanner_screen.dart.
function publicTicketFor(bookingId, booking) {
  const flight = booking.flight || {};
  const passenger = (booking.passengers || [])[0] || {};
  const passengerName = [passenger.title, passenger.firstName, passenger.lastName]
    .map((v) => text(v, ''))
    .filter(Boolean)
    .join(' ');

  return {
    bookingId,
    flightNumber: text(flight.flightNumber),
    departureCode: text(booking.departureCode || flight.departureCode),
    arrivalCode: text(booking.arrivalCode || flight.arrivalCode),
    passengerName: passengerName || '-',
    seats: (booking.seats || []).map(String),
    cabinClass: text(booking.cabinClass),
    status: text(booking.status, 'upcoming'),
  };
}

async function list(db) {
  const snapshot = await db
    .collection('bookings')
    .where('paymentStatus', '==', 'pending')
    .get();
  const rows = snapshot.docs
    .map((doc) => doc.data())
    .filter((b) => b.status !== 'cancelled');

  if (rows.length === 0) {
    console.log('No bookings waiting for payment.');
    return;
  }
  for (const b of rows) {
    const created = b.createdAt?.toDate?.().toISOString() ?? '-';
    const total = Number(b.fare?.total ?? 0).toLocaleString('th-TH');
    console.log(
      `${b.id}  ${total} THB  ${b.paymentMethod}  ${b.flight?.flightNumber ?? '-'}  created ${created}`,
    );
  }
}

async function confirm(db, bookingId) {
  const bookingRef = db.collection('bookings').doc(bookingId);
  const ticketRef = db.collection('publicTickets').doc(publicDocumentId(bookingId));

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(bookingRef);
    if (!snap.exists) throw new Error(`Booking ${bookingId} not found`);
    const booking = snap.data();
    if (booking.status === 'cancelled') throw new Error(`Booking ${bookingId} is cancelled`);
    if (booking.paymentStatus !== 'pending') {
      throw new Error(`Booking ${bookingId} is not pending (paymentStatus: ${booking.paymentStatus})`);
    }

    tx.update(bookingRef, {
      paymentStatus: 'paid',
      paidAt: FieldValue.serverTimestamp(),
      paymentConfirmedBy: 'admin-script',
      ticketIssuedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(ticketRef, {
      ...publicTicketFor(bookingId, booking),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  console.log(`Confirmed ${bookingId}; ticket ${ticketRef.id} issued.`);
}

async function reject(db, bookingId) {
  const bookingRef = db.collection('bookings').doc(bookingId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(bookingRef);
    if (!snap.exists) throw new Error(`Booking ${bookingId} not found`);
    if (snap.data().paymentStatus !== 'pending') {
      throw new Error(`Booking ${bookingId} is not pending; refund/cancel paid bookings manually`);
    }
    tx.update(bookingRef, {
      status: 'cancelled',
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  console.log(`Cancelled unpaid booking ${bookingId}.`);
}

async function main() {
  const [command, bookingId] = process.argv.slice(2);
  if (!['list', 'confirm', 'reject'].includes(command) || (command !== 'list' && !bookingId)) {
    console.log('Usage: node scripts/payments.js list | confirm <bookingId> | reject <bookingId>');
    process.exit(1);
  }

  initializeApp({ credential: applicationDefault(), projectId: 'neon-flight' });
  const db = getFirestore();

  if (command === 'list') await list(db);
  if (command === 'confirm') await confirm(db, bookingId.trim());
  if (command === 'reject') await reject(db, bookingId.trim());
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

module.exports = { publicTicketFor };
