const test = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
const express = require('express');

const { createAdminRouter } = require('./admin');

async function start(router, t) {
  const app = express();
  app.use('/api/admin', router);
  const server = app.listen(0);
  await once(server, 'listening');
  t.after(() => server.close());
  return `http://127.0.0.1:${server.address().port}/api/admin`;
}

const fakeService = () => {
  const calls = [];
  return {
    calls,
    service: () => ({
      list: async (state) => { calls.push(['list', state]); return [{ id: 'NF1' }]; },
      confirm: async (id, by) => { calls.push(['confirm', id, by]); return [id]; },
      getPaymentConfig: async () => ({ promptPayId: '0812345678', merchantName: 'NEON FLIGHT' }),
      setPaymentConfig: async (input) => {
        calls.push(['setPaymentConfig', input.promptPayId]);
        if (input.promptPayId === 'bad') throw new Error('Invalid PromptPay ID');
        return input;
      },
      reject: async (id) => {
        if (id === 'NF404') throw new Error('Booking NF404 not found');
        calls.push(['reject', id]);
        return { cancelled: [id], released: 2 };
      },
    }),
  };
};

test('admin API is off without ADMIN_API_KEY', async (t) => {
  const base = await start(createAdminRouter({ adminKey: '', service: fakeService().service }), t);
  const res = await fetch(`${base}/bookings`, { headers: { 'X-Admin-Key': 'anything' } });
  assert.equal(res.status, 503);
});

test('admin API rejects a missing or wrong key', async (t) => {
  const { service, calls } = fakeService();
  const base = await start(createAdminRouter({ adminKey: 'secret-key', service }), t);
  assert.equal((await fetch(`${base}/bookings`)).status, 401);
  const wrong = await fetch(`${base}/bookings/NF1/confirm`, {
    method: 'POST',
    headers: { 'X-Admin-Key': 'secret-kez' },
  });
  assert.equal(wrong.status, 401);
  assert.deepEqual(calls, []);
});

test('admin API lists, confirms and rejects with the right key', async (t) => {
  const { service, calls } = fakeService();
  const base = await start(createAdminRouter({ adminKey: 'secret-key', service }), t);
  const headers = { 'X-Admin-Key': 'secret-key' };

  const listed = await (await fetch(`${base}/bookings?state=paid`, { headers })).json();
  assert.deepEqual(listed, { state: 'paid', bookings: [{ id: 'NF1' }] });

  const confirmed = await (await fetch(`${base}/bookings/NF1/confirm`, { method: 'POST', headers })).json();
  assert.deepEqual(confirmed, { confirmed: ['NF1'] });

  const rejected = await (await fetch(`${base}/bookings/NF2/reject`, { method: 'POST', headers })).json();
  assert.deepEqual(rejected, { cancelled: ['NF2'], released: 2 });

  const missing = await fetch(`${base}/bookings/NF404/reject`, { method: 'POST', headers });
  assert.equal(missing.status, 404);

  assert.deepEqual(calls, [
    ['list', 'paid'],
    ['confirm', 'NF1', 'admin-web'],
    ['reject', 'NF2'],
  ]);
});

test('admin API reads and validates the PromptPay settings', async (t) => {
  const { service } = fakeService();
  const base = await start(createAdminRouter({ adminKey: 'secret-key', service }), t);
  const headers = { 'X-Admin-Key': 'secret-key', 'Content-Type': 'application/json' };
  const got = await (await fetch(`${base}/config/payment`, { headers })).json();
  assert.equal(got.promptPayId, '0812345678');
  const bad = await fetch(`${base}/config/payment`, {
    method: 'PUT', headers, body: JSON.stringify({ promptPayId: 'bad' }),
  });
  assert.equal(bad.status, 400);
});

test('PromptPay ID must be a mobile number or 13-digit ID', () => {
  const { validatePaymentConfig } = require('./scripts/payments');
  assert.deepEqual(validatePaymentConfig({ promptPayId: '081-234-5678' }), {
    promptPayId: '0812345678', merchantName: 'NEON FLIGHT',
  });
  assert.equal(validatePaymentConfig({ promptPayId: '1234567890123', merchantName: 'Shop' }).merchantName, 'Shop');
  assert.throws(() => validatePaymentConfig({ promptPayId: '12345' }), /Invalid/);
});
