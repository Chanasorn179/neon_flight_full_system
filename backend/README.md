# Neon Flight API

```bash
npm install
npm run dev
```

API: `http://localhost:5000/api`  
SQLite database is created as `backend/neon-flight.db`.

Included schema: users, airports, flights, promotions, bookings, passengers, booking_seats.
For production, set a strong `JWT_SECRET`, validate every payload, add refresh tokens, HTTPS, rate limiting and payment-gateway verification.
