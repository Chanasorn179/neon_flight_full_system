// Firestore security rules tests. Needs the emulator (Java 11+):
//   npm run test:rules
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch } = require('firebase/firestore');

let env;

const booking = (overrides = {}) => ({
  id: 'NF1',
  userId: 'alice',
  status: 'upcoming',
  paymentStatus: 'pending',
  flightKey: 'FD385_20261120',
  seats: ['12C'],
  fare: { total: 3200 },
  ...overrides,
});

// The app's write: booking + one seat lock per seat in one batch.
function bookWithLocks(db, data, { lockSeats = data.seats } = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, `bookings/${data.id}`), data);
  for (const seat of lockSeats) {
    batch.set(doc(db, `seatLocks/${data.flightKey}_${seat}`), {
      flightKey: data.flightKey,
      seat,
      bookingId: data.id,
    });
  }
  return batch.commit();
}

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-neon-flight',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8'),
    },
  });
});

test.after(() => env.cleanup());
test.beforeEach(() => env.clearFirestore());

const alice = () => env.authenticatedContext('alice').firestore();
const anon = () => env.unauthenticatedContext().firestore();

async function seed(path, data) {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));
}

test('user can create their own pending booking with seat locks', async () => {
  await assertSucceeds(bookWithLocks(alice(), booking()));
});

test('booking without seat locks is rejected', async () => {
  await assertFails(setDoc(doc(alice(), 'bookings/NF1'), booking()));
  await assertFails(bookWithLocks(alice(), booking({ seats: ['12C', '12D'] }), { lockSeats: ['12C'] }));
});

test('a seat cannot be booked twice', async () => {
  await assertSucceeds(bookWithLocks(alice(), booking()));
  const bob = env.authenticatedContext('bob').firestore();
  await assertFails(bookWithLocks(bob, booking({ id: 'NF2', userId: 'bob' })));
  // A different seat on the same flight is fine.
  await assertSucceeds(bookWithLocks(bob, booking({ id: 'NF3', userId: 'bob', seats: ['14A'] })));
});

test('nine seats can be booked in one go', async () => {
  const seats = ['1A', '1B', '1C', '1D', '1E', '1F', '2A', '2B', '2C'];
  await assertSucceeds(bookWithLocks(alice(), booking({ seats })));
  await assertFails(bookWithLocks(alice(), booking({ id: 'NF2', seats: [...seats.map((s) => `9${s}`), '3A'] })));
});

test('a full round trip (2 bookings, 9 seats each) fits in one batch', async () => {
  const seats = ['1A', '1B', '1C', '1D', '1E', '1F', '2A', '2B', '2C'];
  const db = alice();
  const batch = writeBatch(db);
  for (const b of [
    booking({ id: 'NF1', tripId: 'NF1', seats }),
    booking({ id: 'NF1R', tripId: 'NF1', seats, flightKey: 'FD386_20261123' }),
  ]) {
    batch.set(doc(db, `bookings/${b.id}`), b);
    for (const seat of b.seats) {
      batch.set(doc(db, `seatLocks/${b.flightKey}_${seat}`), {
        flightKey: b.flightKey,
        seat,
        bookingId: b.id,
      });
    }
  }
  await assertSucceeds(batch.commit());
});

test("locks cannot point at someone else's booking or be removed", async () => {
  await seed('bookings/NF9', booking({ id: 'NF9', userId: 'bob' }));
  await assertFails(setDoc(doc(alice(), 'seatLocks/FD385_20261120_12C'), {
    flightKey: 'FD385_20261120', seat: '12C', bookingId: 'NF9',
  }));
  await seed('seatLocks/FD385_20261120_1A', { flightKey: 'FD385_20261120', seat: '1A', bookingId: 'NF9' });
  await assertFails(deleteDoc(doc(alice(), 'seatLocks/FD385_20261120_1A')));
  await assertSucceeds(getDoc(doc(anon(), 'seatLocks/FD385_20261120_1A')));
});

test('user cannot create a booking that is already paid', async () => {
  await assertFails(bookWithLocks(alice(), booking({ paymentStatus: 'paid' })));
  await assertFails(bookWithLocks(alice(), booking({ paidAt: new Date() })));
});

test('user cannot create a booking for someone else or under another ID', async () => {
  await assertFails(bookWithLocks(alice(), booking({ userId: 'bob' })));
  await assertFails(setDoc(doc(alice(), 'bookings/NF2'), booking()));
});

test('user cannot mark a pending booking paid, edit it or delete it', async () => {
  await seed('bookings/NF1', booking());
  await assertFails(updateDoc(doc(alice(), 'bookings/NF1'), { paymentStatus: 'paid' }));
  await assertFails(updateDoc(doc(alice(), 'bookings/NF1'), { 'fare.total': 1 }));
  await assertFails(deleteDoc(doc(alice(), 'bookings/NF1')));
});

test('user reads only their own bookings', async () => {
  await seed('bookings/NF1', booking());
  await seed('bookings/NF2', booking({ id: 'NF2', userId: 'bob' }));
  await assertSucceeds(getDoc(doc(alice(), 'bookings/NF1')));
  await assertFails(getDoc(doc(alice(), 'bookings/NF2')));
});

test('nobody but the server can write public tickets; anyone can get one', async () => {
  await seed('bookings/NF1', booking());
  await assertFails(setDoc(doc(alice(), 'publicTickets/NF1_ABC'), { bookingId: 'NF1', status: 'upcoming' }));

  await seed('publicTickets/NF1_ABC', { bookingId: 'NF1', status: 'upcoming' });
  await assertSucceeds(getDoc(doc(anon(), 'publicTickets/NF1_ABC')));
  await assertFails(updateDoc(doc(alice(), 'publicTickets/NF1_ABC'), { status: 'upcoming' }));
});
