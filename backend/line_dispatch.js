const crypto = require('crypto');

const LINE_PUSH_ENDPOINT = 'https://api.line.me/v2/bot/message/push';

function normalizePhone(phone) {
  return String(phone ?? '')
    .trim()
    .replace(/[^\d+]/g, '');
}

function validateTransferPayload(payload) {
  const bookingId = String(payload.bookingId ?? '').trim();
  const userId = String(payload.userId ?? '').trim();
  const passengerName = String(payload.passengerName ?? '').trim();
  const passengerPhone = String(payload.passengerPhone ?? '').trim();
  const latitude = Number(payload.latitude);
  const longitude = Number(payload.longitude);
  const phoneForUri = normalizePhone(passengerPhone);

  if (!bookingId || bookingId.length > 80) {
    throw new Error('invalid bookingId');
  }
  if (!userId || userId.length > 80) {
    throw new Error('invalid userId');
  }
  if (!passengerName || passengerName.length > 120) {
    throw new Error('invalid passengerName');
  }
  if (!phoneForUri || phoneForUri.length > 20) {
    throw new Error('invalid passengerPhone');
  }
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    throw new Error('invalid latitude');
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new Error('invalid longitude');
  }

  return {
    bookingId,
    userId,
    passengerName,
    passengerPhone,
    phoneForUri,
    latitude,
    longitude,
  };
}

function verifyLineSignature(rawBody, channelSecret, signature) {
  if (!rawBody || !channelSecret || !signature) return false;
  const expected = crypto
    .createHmac('sha256', channelSecret)
    .update(rawBody)
    .digest('base64');
  const expectedBuffer = Buffer.from(expected);
  const suppliedBuffer = Buffer.from(String(signature));
  return (
    expectedBuffer.length === suppliedBuffer.length &&
    crypto.timingSafeEqual(expectedBuffer, suppliedBuffer)
  );
}

function buildLineMessages(rawPayload) {
  const payload = validateTransferPayload(rawPayload);
  const coordinates =
    `${payload.latitude.toFixed(6)}, ${payload.longitude.toFixed(6)}`;
  const mapUrl =
    'https://www.google.com/maps/dir/?api=1&destination=' +
    encodeURIComponent(`${payload.latitude},${payload.longitude}`);

  return [
    {
      type: 'flex',
      altText: `งานรับรถใหม่จาก ${payload.passengerName}`,
      contents: {
        type: 'bubble',
        header: {
          type: 'box',
          layout: 'vertical',
          backgroundColor: '#5B21B6',
          contents: [
            {
              type: 'text',
              text: 'งานรับรถใหม่',
              color: '#FFFFFF',
              weight: 'bold',
              size: 'lg',
            },
          ],
        },
        body: {
          type: 'box',
          layout: 'vertical',
          spacing: 'md',
          contents: [
            {
              type: 'box',
              layout: 'vertical',
              spacing: 'xs',
              contents: [
                { type: 'text', text: 'ชื่อผู้โดยสาร', size: 'sm', color: '#6B7280' },
                {
                  type: 'text',
                  text: payload.passengerName,
                  weight: 'bold',
                  wrap: true,
                },
              ],
            },
            {
              type: 'box',
              layout: 'vertical',
              spacing: 'xs',
              contents: [
                { type: 'text', text: 'เบอร์โทร', size: 'sm', color: '#6B7280' },
                {
                  type: 'text',
                  text: payload.passengerPhone,
                  weight: 'bold',
                  wrap: true,
                },
              ],
            },
            {
              type: 'box',
              layout: 'vertical',
              spacing: 'xs',
              contents: [
                { type: 'text', text: 'ตำแหน่งรับรถ', size: 'sm', color: '#6B7280' },
                { type: 'text', text: coordinates, wrap: true },
              ],
            },
          ],
        },
        footer: {
          type: 'box',
          layout: 'horizontal',
          spacing: 'sm',
          contents: [
            {
              type: 'button',
              style: 'secondary',
              action: {
                type: 'uri',
                label: 'โทรหา',
                uri: `tel:${payload.phoneForUri}`,
              },
            },
            {
              type: 'button',
              style: 'primary',
              color: '#5B21B6',
              action: {
                type: 'uri',
                label: 'เปิดแผนที่',
                uri: mapUrl,
              },
            },
          ],
        },
      },
    },
    {
      type: 'location',
      title: 'จุดรับผู้โดยสาร',
      address: 'ตำแหน่งที่ผู้โดยสารเรียกรถ',
      latitude: payload.latitude,
      longitude: payload.longitude,
    },
  ];
}

async function pushDriverNotification({
  channelAccessToken,
  targetId,
  payload,
  fetchImpl = fetch,
}) {
  if (!channelAccessToken || !targetId) {
    throw new Error('LINE Messaging API is not configured');
  }

  const abortController = new AbortController();
  const timeout = setTimeout(() => abortController.abort(), 10000);
  let response;
  try {
    response = await fetchImpl(LINE_PUSH_ENDPOINT, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${channelAccessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: targetId,
        messages: buildLineMessages(payload),
      }),
      signal: abortController.signal,
    });
  } finally {
    clearTimeout(timeout);
  }

  if (!response.ok) {
    const responseBody = await response.text();
    throw new Error(
      `LINE Messaging API returned ${response.status}: ${responseBody}`,
    );
  }
}

module.exports = {
  LINE_PUSH_ENDPOINT,
  buildLineMessages,
  normalizePhone,
  pushDriverNotification,
  validateTransferPayload,
  verifyLineSignature,
};
