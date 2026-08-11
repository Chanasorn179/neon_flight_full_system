const assert = require('node:assert/strict');
const test = require('node:test');
const { once } = require('node:events');

process.env.NEON_DB_PATH = ':memory:';
const { app, db } = require('./server');

test('starts the API, creates transfer schema and fails closed without LINE config', async (t) => {
  const table = db
    .prepare(
      `SELECT name FROM sqlite_master
       WHERE type='table' AND name='transfer_bookings'`,
    )
    .get();
  assert.equal(table.name, 'transfer_bookings');

  const server = app.listen(0);
  await once(server, 'listening');
  t.after(() => {
    server.close();
    db.close();
  });

  const address = server.address();
  const baseUrl = `http://127.0.0.1:${address.port}/api`;
  const healthResponse = await fetch(`${baseUrl}/health`);
  assert.equal(healthResponse.status, 200);
  assert.deepEqual(await healthResponse.json(), {
    ok: true,
    service: 'neon-flight-api',
  });

  const dispatchResponse = await fetch(`${baseUrl}/transfer-bookings`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{}',
  });
  assert.equal(dispatchResponse.status, 503);
});
