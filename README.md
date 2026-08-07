# Neon Flight — Full Booking Flow

Flutter airline booking demo refactored into normal Dart imports (no `part/part of`).

## Included
- Login, register, forgot-password mock flow
- One-way / round-trip search controls
- Airport, date, passengers, cabin class
- Price filter and cheapest/earliest/fastest sorting
- Special deals instead of auctions
- Passenger + passport information with validation
- Seat map and seat selection
- PromptPay / Card / Mobile Banking payment UI
- Fare/tax/service/seat breakdown
- Booking confirmation and E-Ticket with QR-style code
- Booking History tabs: Upcoming / Completed / Cancelled
- Profile, dark mode, notifications, language toggle
- Responsive layouts, loading / empty / error states
- Repository architecture with in-memory MockApi
- `backend/` sample Express + SQLite + JWT API and database schema

## Run Flutter
```bash
flutter pub get
flutter analyze
flutter run
```

Demo login: `demo@neonflight.app` / `123456`

## Architecture
`models/` → entities  
`repositories/` → contracts + mock implementations  
`data/` → MockApi  
`providers/` → application state  
`screens/` → feature UI  
`widgets/` → reusable UI

The Flutter app intentionally starts in Mock mode so it can run without starting the backend. The repository layer is the seam for replacing Mock implementations with REST implementations.
