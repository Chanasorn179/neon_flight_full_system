const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const test = require('node:test');

const {
  LINE_PUSH_ENDPOINT,
  buildLineMessages,
  pushDriverNotification,
  validateTransferPayload,
  verifyLineSignature,
} = require('./line_dispatch');

const payload = {
  bookingId: 'NT123',
  userId: 'u1',
  passengerName: 'Somchai Jaidee',
  passengerPhone: '081-234-5678',
  latitude: 13.914372,
  longitude: 100.605692,
};

test('builds Flex and location messages with call and map actions', () => {
  const messages = buildLineMessages(payload);

  assert.equal(messages.length, 2);
  assert.equal(messages[0].type, 'flex');
  assert.equal(messages[0].contents.footer.contents[0].action.uri, 'tel:0812345678');
  assert.match(
    messages[0].contents.footer.contents[1].action.uri,
    /google\.com\/maps\/dir/,
  );
  assert.equal(messages[1].type, 'location');
  assert.equal(messages[1].latitude, payload.latitude);
  assert.equal(messages[1].longitude, payload.longitude);
});

test('rejects invalid coordinates', () => {
  assert.throws(
    () => validateTransferPayload({ ...payload, latitude: 100 }),
    /invalid latitude/,
  );
});

test('verifies LINE webhook signatures', () => {
  const body = Buffer.from('{events:[]}');
  const secret = 'channel-secret';
  const signature = crypto
    .createHmac('sha256', secret)
    .update(body)
    .digest('base64');

  assert.equal(verifyLineSignature(body, secret, signature), true);
  assert.equal(verifyLineSignature(body, secret, 'invalid'), false);
});

test('sends a LINE push request with the backend token', async () => {
  let capturedUrl;
  let capturedOptions;
  const fetchImpl = async (url, options) => {
    capturedUrl = url;
    capturedOptions = options;
    return { ok: true, status: 200, text: async () => '' };
  };

  await pushDriverNotification({
    channelAccessToken: 'secret-token',
    targetId: 'U123',
    payload,
    fetchImpl,
  });

  assert.equal(capturedUrl, LINE_PUSH_ENDPOINT);
  assert.equal(
    capturedOptions.headers.Authorization,
    'Bearer secret-token',
  );
  const body = JSON.parse(capturedOptions.body);
  assert.equal(body.to, 'U123');
  assert.equal(body.messages.length, 2);
});
