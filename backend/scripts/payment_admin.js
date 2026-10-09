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
//   node scripts/payment_admin.js list
//   node scripts/payment_admin.js confirm NF12345678
//   node scripts/payment_admin.js reject NF12345678
//
// The same functions back the admin web page (admin_api.js, /admin).
// A round trip is confirmed or rejected as a whole (both legs share tripId).

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

function toIso(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

// Plain summary of a booking for the admin list.
function summarize(b) {
  const flight = b.flight || {};
  return {
    id: b.id,
    tripId: b.tripId || null,
    userId: b.userId,
    createdAt: toIso(b.createdAt),
    flightNumber: text(flight.flightNumber),
    airline: text(flight.airline),
    from: text(b.departureCode || flight.departureCode),
    to: text(b.arrivalCode || flight.arrivalCode),
    departureTime: toIso(flight.departureTime),
    cabinClass: text(b.cabinClass),
    seats: (b.seats || []).map(String),
    passengers: (b.passengers || []).map((p) =>
      [p.title, p.firstName, p.lastName].map((v) => text(v, '')).filter(Boolean).join(' '),
    ),
    total: Number(b.fare?.total ?? 0),
    paymentMethod: text(b.paymentMethod),
    paymentLabel: b.paymentLabel ? text(b.paymentLabel) : null,
    paymentStatus: text(b.paymentStatus, 'paid'),
    status: text(b.status, 'upcoming'),
  };
}

const LIST_QUERIES = {
  pending: (db) => db.collection('bookings').where('paymentStatus', '==', 'pending'),
  paid: (db) => db.collection('bookings').where('paymentStatus', '==', 'paid'),
  cancelled: (db) => db.collection('bookings').where('status', '==', 'cancelled'),
};

// Bookings by state, newest first. "pending" excludes cancelled ones.
async function list(db, state = 'pending', limit = 100) {
  const query = LIST_QUERIES[state];
  if (!query) throw new Error(`Unknown state ${state}`);
  const snapshot = await query(db).get();
  return snapshot.docs
    .map((doc) => summarize({ id: doc.id, ...doc.data() }))
    .filter((b) => state !== 'pending' || b.status !== 'cancelled')
    .sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
    .slice(0, limit);
}

// The booking and, for a round trip, its other leg (paid together).
async function tripRefs(tx, db, bookingId) {
  const ref = db.collection('bookings').doc(bookingId);
  const snap = await tx.get(ref);
  if (!snap.exists) throw new Error(`Booking ${bookingId} not found`);
  const tripId = snap.data().tripId;
  if (!tripId) return [snap];
  const legs = await tx.get(db.collection('bookings').where('tripId', '==', tripId));
  return legs.docs;
}

// Marks the booking (both legs of a round trip) paid and issues the public
// ticket records. Returns the confirmed booking ids.
async function confirm(db, bookingId, confirmedBy = 'admin') {
  let confirmed = [];
  await db.runTransaction(async (tx) => {
    const legs = await tripRefs(tx, db, bookingId);
    for (const leg of legs) {
      const b = leg.data();
      if (b.status === 'cancelled') throw new Error(`Booking ${leg.id} is cancelled`);
      if (b.paymentStatus !== 'pending') {
        throw new Error(`Booking ${leg.id} is not pending (paymentStatus: ${b.paymentStatus})`);
      }
    }
    for (const leg of legs) {
      tx.update(leg.ref, {
        paymentStatus: 'paid',
        paidAt: FieldValue.serverTimestamp(),
        paymentConfirmedBy: confirmedBy,
        ticketIssuedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(db.collection('publicTickets').doc(publicDocumentId(leg.id)), {
        ...publicTicketFor(leg.id, leg.data()),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    confirmed = legs.map((leg) => leg.id);
  });
  return confirmed;
}

// Cancels an unpaid booking (both legs of a round trip) and frees its seats.
// Returns { cancelled: ids, released: seat count }.
async function reject(db, bookingId) {
  let result = { cancelled: [], released: 0 };
  await db.runTransaction(async (tx) => {
    const legs = await tripRefs(tx, db, bookingId);
    for (const leg of legs) {
      if (leg.data().paymentStatus !== 'pending') {
        throw new Error(`Booking ${leg.id} is not pending; refund/cancel paid bookings manually`);
      }
    }
    const ids = legs.map((leg) => leg.id);
    const locks = await tx.get(db.collection('seatLocks').where('bookingId', 'in', ids));
    for (const leg of legs) {
      tx.update(leg.ref, {
        status: 'cancelled',
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    locks.forEach((lock) => tx.delete(lock.ref));
    result = { cancelled: ids, released: locks.size };
  });
  return result;
}

// Shop payment settings read by the app (appConfig/payment, public read).
function validatePaymentConfig(input) {
  const promptPayId = String(input.promptPayId || '').replace(/\D/g, '');
  // Mobile number (10 digits, starts with 0) or national/tax ID (13 digits).
  if (!/^0\d{9}$/.test(promptPayId) && !/^\d{13}$/.test(promptPayId)) {
    throw new Error('Invalid PromptPay ID: use a 10-digit mobile number or a 13-digit ID');
  }
  const merchantName = String(input.merchantName || 'NEON FLIGHT').trim().slice(0, 40) || 'NEON FLIGHT';
  return { promptPayId, merchantName };
}

async function getPaymentConfig(db) {
  const snap = await db.collection('appConfig').doc('payment').get();
  return snap.exists ? snap.data() : {};
}

async function setPaymentConfig(db, input) {
  const config = validatePaymentConfig(input);
  await db.collection('appConfig').doc('payment').set({
    ...config,
    updatedAt: FieldValue.serverTimestamp(),
  });
  return config;
}

let firestore;
// Firestore through the Admin SDK (GOOGLE_APPLICATION_CREDENTIALS).
function adminDb() {
  if (!firestore) {
    initializeApp({ credential: applicationDefault(), projectId: 'neon-flight' });
    firestore = getFirestore();
  }
  return firestore;
}

async function main() {
  const [command, bookingId] = process.argv.slice(2);
  if (!['list', 'confirm', 'reject'].includes(command) || (command !== 'list' && !bookingId)) {
    console.log('Usage: node scripts/payment_admin.js list | confirm <bookingId> | reject <bookingId>');
    process.exit(1);
  }
  const db = adminDb();

  if (command === 'list') {
    const rows = await list(db, 'pending');
    if (rows.length === 0) console.log('No bookings waiting for payment.');
    for (const b of rows) {
      const total = b.total.toLocaleString('th-TH');
      const trip = b.tripId ? `  trip ${b.tripId}` : '';
      console.log(`${b.id}  ${total} THB  ${b.paymentMethod}  ${b.flightNumber}  created ${b.createdAt ?? '-'}${trip}`);
    }
  }
  if (command === 'confirm') {
    const ids = await confirm(db, bookingId.trim(), 'admin-script');
    console.log(`Confirmed ${ids.join(', ')}; tickets issued.`);
  }
  if (command === 'reject') {
    const { cancelled, released } = await reject(db, bookingId.trim());
    console.log(`Cancelled ${cancelled.join(', ')}; released ${released} seat(s).`);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

module.exports = {
  publicTicketFor,
  summarize,
  list,
  confirm,
  reject,
  adminDb,
  validatePaymentConfig,
  getPaymentConfig,
  setPaymentConfig,
};
