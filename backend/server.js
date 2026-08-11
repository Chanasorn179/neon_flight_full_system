const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());
const db = new Database(path.join(__dirname, 'neon-flight.db'));
db.exec(fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8'));
const JWT_SECRET = process.env.JWT_SECRET || 'change-this-in-production';

const count = db.prepare('SELECT COUNT(*) c FROM airports').get().c;
if (!count) {
  const add = db.prepare('INSERT INTO airports(code,city,name) VALUES(?,?,?)');
  [['BKK','Bangkok','Suvarnabhumi'],['CNX','Chiang Mai','Chiang Mai'],['HKT','Phuket','Phuket'],['NRT','Tokyo','Narita'],['ICN','Seoul','Incheon'],['SIN','Singapore','Changi']].forEach(a=>add.run(...a));
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

const port=process.env.PORT||5000;
app.listen(port,()=>console.log(`Neon Flight API http://localhost:${port}`));
