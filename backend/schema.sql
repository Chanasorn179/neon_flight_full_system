PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, email TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS airports (code TEXT PRIMARY KEY, city TEXT NOT NULL, name TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS flights (id INTEGER PRIMARY KEY AUTOINCREMENT, flight_number TEXT NOT NULL, airline TEXT NOT NULL, departure_code TEXT NOT NULL REFERENCES airports(code), arrival_code TEXT NOT NULL REFERENCES airports(code), departure_time TEXT NOT NULL, arrival_time TEXT NOT NULL, base_price REAL NOT NULL, available_seats INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS promotions (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, from_code TEXT NOT NULL, to_code TEXT NOT NULL, cabin_class TEXT NOT NULL, discount_percent INTEGER NOT NULL, seats_left INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS bookings (id TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), flight_id INTEGER NOT NULL REFERENCES flights(id), cabin_class TEXT NOT NULL, payment_method TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'upcoming', total REAL NOT NULL, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS passengers (id INTEGER PRIMARY KEY AUTOINCREMENT, booking_id TEXT NOT NULL REFERENCES bookings(id), title TEXT, first_name TEXT NOT NULL, last_name TEXT NOT NULL, birth_date TEXT, nationality TEXT, passport_number TEXT, passport_expiry TEXT, phone TEXT, email TEXT);
CREATE TABLE IF NOT EXISTS booking_seats (booking_id TEXT NOT NULL REFERENCES bookings(id), seat TEXT NOT NULL, PRIMARY KEY (booking_id, seat));
CREATE TABLE IF NOT EXISTS transfer_bookings (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  passenger_name TEXT NOT NULL,
  passenger_phone TEXT NOT NULL,
  pickup_latitude REAL NOT NULL,
  pickup_longitude REAL NOT NULL,
  notification_status TEXT NOT NULL DEFAULT 'pending',
  notification_error TEXT,
  line_notified_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
