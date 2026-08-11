const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const Database = require('better-sqlite3');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const {
  pushDriverNotification,
  validateTransferPayload,
  verifyLineSignature,
} = require('./line_dispatch');

const app = express();
app.use(cors());
app.use(
  express.json({
    verify: (request, _response, buffer) => {
      request.rawBody = buffer;
    },
  }),
);
const databasePath =
  process.env.NEON_DB_PATH || path.join(__dirname, 'neon-flight.db');
const db = new Database(databasePath);
db.exec(fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8'));
const JWT_SECRET = process.env.JWT_SECRET || 'change-this-in-production';
const DISPATCH_API_KEY = process.env.DISPATCH_API_KEY || '';
const LINE_CHANNEL_ACCESS_TOKEN =
  process.env.LINE_CHANNEL_ACCESS_TOKEN || '';
const LINE_CHANNEL_SECRET = process.env.LINE_CHANNEL_SECRET || '';
const LINE_DRIVER_TARGET_ID = process.env.LINE_DRIVER_TARGET_ID || '';

const addAirport = db.prepare(
  'INSERT OR IGNORE INTO airports(code,city,name) VALUES(?,?,?)',
);
[
  ['BKK', 'Bangkok', 'Suvarnabhumi'],
  ['DMK', 'Bangkok', 'Don Mueang'],
  ['CNX', 'Chiang Mai', 'Chiang Mai'],
  ['HKT', 'Phuket', 'Phuket'],
  ['NRT', 'Tokyo', 'Narita'],
  ['ICN', 'Seoul', 'Incheon'],
  ['SIN', 'Singapore', 'Changi'],
].forEach((airport) => addAirport.run(...airport));

function hasValidDispatchKey(request) {
  if (!DISPATCH_API_KEY) return false;
  const suppliedKey = String(request.get('x-dispatch-key') || '');
  const expected = Buffer.from(DISPATCH_API_KEY);
  const supplied = Buffer.from(suppliedKey);
  return (
    expected.length === supplied.length &&
    crypto.timingSafeEqual(expected, supplied)
  );
}

app.get('/api/health', (_,res)=>res.json({ok:true,service:'neon-flight-api'}));
app.post('/api/auth/register', (req,res)=>{
  const {name,email,password}=req.body;
  if(!name||!email||!password||password.length<6) return res.status(400).json({message:'invalid input'});
  try { const hash=bcrypt.hashSync(password,10); const info=db.prepare('INSERT INTO users(name,email,password_hash) VALUES(?,?,?)').run(name,email,hash); const token=jwt.sign({sub:info.lastInsertRowid,email},JWT_SECRET,{expiresIn:'7d'}); res.status(201).json({token,user:{id:String(info.lastInsertRowid),name,email}}); }
  catch(e){ res.status(409).json({message:'email already exists'}); }
});
app.post('/api/auth/login', (req,res)=>{
  const {email,password}=req.body; const u=db.prepare('SELECT * FROM users WHERE email=?').get(email);
  if(!u||!bcrypt.compareSync(password,u.password_hash)) return res.status(401).json({message:'invalid credentials'});
  const token=jwt.sign({sub:u.id,email:u.email},JWT_SECRET,{expiresIn:'7d'}); res.json({token,user:{id:String(u.id),name:u.name,email:u.email}});
});
app.get('/api/airports', (_,res)=>res.json(db.prepare('SELECT * FROM airports ORDER BY code').all()));
app.get('/api/flights', (req,res)=>{ const {from,to,date}=req.query; const rows=db.prepare('SELECT * FROM flights WHERE departure_code=? AND arrival_code=? AND substr(departure_time,1,10)=? ORDER BY base_price').all(from,to,date); res.json(rows); });
app.get('/api/promotions', (_,res)=>res.json(db.prepare('SELECT * FROM promotions').all()));
app.get('/api/bookings/:userId', (req,res)=>res.json(db.prepare('SELECT * FROM bookings WHERE user_id=? ORDER BY created_at DESC').all(req.params.userId)));

app.post('/api/line/webhook', (req, res) => {
  if (!LINE_CHANNEL_SECRET) {
    return res.status(503).json({
      message: 'LINE webhook is not configured on the server',
    });
  }
  const isAuthentic = verifyLineSignature(
    req.rawBody,
    LINE_CHANNEL_SECRET,
    req.get('x-line-signature'),
  );
  if (!isAuthentic) {
    return res.status(401).json({ message: 'invalid LINE signature' });
  }

  for (const event of req.body.events || []) {
    const source = event.source || {};
    const targetId = source.userId || source.groupId || source.roomId;
    if (targetId) {
      console.log('Verified LINE driver target ID:', targetId);
    }
  }
  return res.sendStatus(200);
});

app.post('/api/transfer-bookings', async (req, res) => {
  if (
    !DISPATCH_API_KEY ||
    !LINE_CHANNEL_ACCESS_TOKEN ||
    !LINE_DRIVER_TARGET_ID
  ) {
    return res.status(503).json({
      message: 'LINE dispatch is not configured on the server',
    });
  }
  if (!hasValidDispatchKey(req)) {
    return res.status(401).json({ message: 'invalid dispatch key' });
  }

  let payload;
  try {
    payload = validateTransferPayload(req.body);
  } catch (error) {
    return res.status(400).json({ message: error.message });
  }

  db.prepare(
    `INSERT OR IGNORE INTO transfer_bookings(
      id,
      user_id,
      passenger_name,
      passenger_phone,
      pickup_latitude,
      pickup_longitude
    ) VALUES(?,?,?,?,?,?)`,
  ).run(
    payload.bookingId,
    payload.userId,
    payload.passengerName,
    payload.passengerPhone,
    payload.latitude,
    payload.longitude,
  );

  const existing = db
    .prepare(
      'SELECT notification_status FROM transfer_bookings WHERE id=?',
    )
    .get(payload.bookingId);
  if (existing.notification_status === 'sent') {
    return res.json({ ok: true, alreadyNotified: true });
  }

  const claimed = db
    .prepare(
      `UPDATE transfer_bookings
       SET notification_status='sending', notification_error=NULL
       WHERE id=? AND notification_status IN ('pending','failed')`,
    )
    .run(payload.bookingId);
  if (!claimed.changes) {
    return res.status(202).json({
      ok: true,
      notificationStatus: 'sending',
    });
  }

  try {
    await pushDriverNotification({
      channelAccessToken: LINE_CHANNEL_ACCESS_TOKEN,
      targetId: LINE_DRIVER_TARGET_ID,
      payload,
    });
    db.prepare(
      `UPDATE transfer_bookings
       SET notification_status='sent',
           line_notified_at=CURRENT_TIMESTAMP,
           notification_error=NULL
       WHERE id=?`,
    ).run(payload.bookingId);
    return res.status(201).json({
      ok: true,
      notificationStatus: 'sent',
    });
  } catch (error) {
    db.prepare(
      `UPDATE transfer_bookings
       SET notification_status='failed', notification_error=?
       WHERE id=?`,
    ).run(String(error.message).slice(0, 500), payload.bookingId);
    console.error('LINE dispatch failed:', error.message);
    return res.status(502).json({
      message: 'Unable to notify the driver through LINE',
    });
  }
});

const port=process.env.PORT||5000;
if (require.main === module) {
  app.listen(port, () =>
    console.log(`Neon Flight API http://localhost:${port}`),
  );
}

module.exports = { app, db };
