// Uploads backend/seed/firestore_seed.json (built by tool/build_airport_data.py)
// to Firestore collections: airlines, airports, airportStats.
//
// Needs a service-account key for the Firebase project:
//   Firebase Console > Project settings > Service accounts > Generate new private key
//
// PowerShell:
//   $env:GOOGLE_APPLICATION_CREDENTIALS='C:\path\to\neon-flight-service-account.json'
//   node scripts/seed_firestore.js            # dry run: prints what would be written
//   node scripts/seed_firestore.js --write    # writes to Firestore

const fs = require('node:fs');
const path = require('node:path');

const seed = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'seed', 'firestore_seed.json'), 'utf8'),
);

const docs = [
  ...seed.airlines.map((a) => ['airlines', a.code, a]),
  ...seed.airports.map((a) => ['airports', a.code, { ...a, source: seed.source }]),
  ...seed.airportStats.map((s) => ['airportStats', s.code, { ...s, source: seed.source }]),
];

async function main() {
  const counts = {};
  for (const [collection] of docs) counts[collection] = (counts[collection] || 0) + 1;
  console.log('Documents:', counts, 'period12m:', seed.period12m);

  if (!process.argv.includes('--write')) {
    console.log('Dry run. Re-run with --write to upload.');
    return;
  }

  const { initializeApp, applicationDefault } = require('firebase-admin/app');
  const { getFirestore, FieldValue } = require('firebase-admin/firestore');

  initializeApp({ credential: applicationDefault(), projectId: 'neon-flight' });
  const db = getFirestore();

  // Firestore batches hold at most 500 writes.
  for (let i = 0; i < docs.length; i += 400) {
    const batch = db.batch();
    for (const [collection, id, data] of docs.slice(i, i + 400)) {
      batch.set(db.collection(collection).doc(id), {
        ...data,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
  console.log(`Wrote ${docs.length} documents to project neon-flight.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
