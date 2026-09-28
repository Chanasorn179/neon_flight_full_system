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
const { doc, getDoc, setDoc, updateDoc, deleteDoc } = require('firebase/firestore');

let env;

const booking = (overrides = {}) => ({
  id: 'NF1',
  userId: 'alice',
  status: 'upcoming',
  paymentStatus: 'pending',
  fare: { total: 3200 },
  ...overrides,
});

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

test('user can create their own pending booking', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'bookings/NF1'), booking()));
});

test('user cannot create a booking that is already paid', async () => {
  await assertFails(setDoc(doc(alice(), 'bookings/NF1'), booking({ paymentStatus: 'paid' })));
  await assertFails(setDoc(doc(alice(), 'bookings/NF1'), booking({ paidAt: new Date() })));
});

test('user cannot create a booking for someone else or under another ID', async () => {
  await assertFails(setDoc(doc(alice(), 'bookings/NF1'), booking({ userId: 'bob' })));
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
