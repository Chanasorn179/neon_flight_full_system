# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Neon Flight: a Flutter airline booking app (flight search, seat selection, payment UI, QR e-tickets, airport transfers) backed by Firebase Auth/Firestore/Hosting, plus an optional Node/Express backend in `backend/`. See `README.md` for the full feature list and Firestore layout.

**The Dart package name is `mini_projects`** (inherited from the template), not `neon_flight`. Test and package imports use `package:mini_projects/...`.

## Commands

Flutter app (run from repo root; targets Flutter 3.44 / Dart 3.12, JDK 17):

```bash
flutter pub get
flutter analyze                 # expected: "No issues found!"
flutter test
flutter test test/transfer_dispatch_service_test.dart     # single file
flutter test --plain-name "some test name"                 # single test
flutter test test/screenshots --run-skipped --update-goldens  # PNGs of main screens, light+dark (Windows fonts) -> test/screenshots/out/
flutter run -d emulator-5554
```

Build-time config goes through `--dart-define` (read via `String/bool.fromEnvironment`):

| Define | Used in | Purpose |
|---|---|---|
| `NEON_API_BASE_URL` | `aviation_api_service.dart`, `transfer_dispatch_service.dart` | Backend URL. Default `http://10.0.2.2:5000/api` (Android emulator → host). Use the LAN IP for a physical phone. |
| `ALLOW_MOCK_FLIGHTS` | `aviation_api_service.dart` | Fall back to mock flights when the API fails (default on). |
| `NEON_DISPATCH_API_KEY` | `transfer_dispatch_service.dart` | Must match backend `DISPATCH_API_KEY`. |
| `PROMPTPAY_ID` | `promptpay_service.dart` | PromptPay receiving ID for QR generation. |
| `TICKET_SIGNING_SECRET` | `ticket_qr_service.dart` | HMAC key for e-ticket tokens (plain SHA-256 if empty). Must equal the env var of the same name used by `backend/scripts/payments.js`. |

Backend (`backend/`, Express 5 + better-sqlite3, port 5000, DB file `backend/neon-flight.db`, schema in `schema.sql`):

```bash
cd backend && npm install
npm run dev        # node server.js
npm test           # node --test (*.test.js)
npm run test:rules # firestore.rules tests in the emulator; needs Java 11+ (e.g. JAVA_HOME=~/.jdks/openjdk-26.0.1)
```

Payment confirmation (admin, needs `GOOGLE_APPLICATION_CREDENTIALS`):

```bash
cd backend
node scripts/payments.js list                # bookings waiting for payment
node scripts/payments.js confirm <bookingId> # mark paid + issue publicTickets record
node scripts/payments.js reject <bookingId>  # cancel an unpaid booking
```

Or use the admin web page: start the backend with `ADMIN_API_KEY` (and `GOOGLE_APPLICATION_CREDENTIALS`) set, open `http://localhost:5000/admin`, sign in with that key. It calls `/api/admin/*` (`backend/admin.js`), which reuses the `payments.js` functions. To try it without touching production, run the Firestore emulator and start the backend with `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080`.

Backend env vars: `AVIATIONSTACK_API_KEY`, `JWT_SECRET`, `DISPATCH_API_KEY`, `LINE_CHANNEL_ACCESS_TOKEN`, `LINE_CHANNEL_SECRET`, `LINE_DRIVER_TARGET_ID`, `PORT`. `GET /api/health` reports whether Aviationstack is configured.

Airport/airline reference data (regenerate when the statistics CSV is updated):

```bash
python tool/build_airport_data.py "<path to Air_Transport_Statistics_External_Monthly(All_External_Data).csv>"
cd backend && node scripts/seed_firestore.js --write   # needs GOOGLE_APPLICATION_CREDENTIALS (service-account key)
```

Firebase (project `neon-flight`):

```bash
firebase deploy --only hosting,firestore:rules
```

## Architecture

- **Composition root is `lib/main.dart`.** It calls `FirebaseService.initialize()`. If that succeeds, `FirebaseService.enabled` is true and the Firebase repositories are used. If it fails, the app silently switches to the `Mock*Repository` implementations backed by `data/mock_api.dart`. When auth or bookings "don't persist", check `FirebaseService.initializationError` first.
- **Layers:** `screens/` → `providers/` (ChangeNotifier, via `provider`'s `MultiProvider`) → `repositories/` (abstract interface + Firebase/Mock/Hybrid implementations) → `services/` (Firebase, HTTP, QR, PromptPay). All models are in `models/entities.dart`. The code uses normal imports only, with no `part`/`part of`.
- **Reference data:** `lib/data/thai_airports.dart` is generated from AOT/DOA airport traffic statistics (ranked by passengers over the latest 12 months). The same data is seeded into the Firestore collections `airports`, `airlines` and `airportStats`, which are public read-only. `FlightRepository.airports()` reads Firestore and falls back to the bundled list. `lib/data/thai_airlines.dart` holds the Thai carriers and must stay in sync with `AIRLINES` in the generator. Airline logos live in `assets/airlines/<CODE>.png` (256px white tiles) and are shown through `widgets/airline_logo.dart`, which rounds them and falls back to a colored code badge. They are built by `tool/build_airline_logos.py` from the user-supplied `thai_airline_logos_split.zip` plus a separate `Thai_AirAsia_X.png` (crop boxes are hard-coded per source image). The dataset has no airlines, routes or fares, so mock schedules (`MockApi.searchFlights`) assign carriers by hub (`airlinesForRoute`) and are demo data.
- **Flights:** `HybridFlightRepository` goes through the backend (which proxies Aviationstack so the key stays server-side) and falls back to mock data. Aviationstack has no fares, so prices are demo values (`pricingSource: demo`).
- **Seat locks and round trips:** every booking writes `seatLocks/{flightKey}_{seat}` docs in the same batch (`FirebaseService.saveBookings`); rules require all seats locked (max 9) and never allow overwriting a lock, so the first booking wins. `flightKey` is `FlightEntity.scheduleKey` (flight number + date), which is why `MockApi.searchFlights` must stay deterministic per route/day. A round trip is two bookings (`id` and `${id}R`) sharing `tripId`, saved in one batch, and confirmed/rejected/cancelled as a unit. Locks are deleted by `payments.js reject`, or by the owner's cancel (`FirebaseService.cancelBookings`, same batch as setting `status: cancelled` — the only booking update the rules allow clients).
- **Payment → ticket flow:** the app creates `bookings/{id}` with `paymentStatus: 'pending'`, the only state the rules accept from clients (bookings cannot be updated or deleted by clients). An admin runs `backend/scripts/payments.js confirm`, which sets `paymentStatus: 'paid'` and writes `publicTickets/{bookingId_token}` via the Admin SDK. `TicketScreen` shows a waiting panel and listens to `FirebaseService.watchPaymentStatus` until it flips to paid. Bookings without a `paymentStatus` field predate this flow and are treated as paid. Mock mode (no Firebase) marks bookings paid immediately.
- **E-tickets:** `TicketQrService` derives a 12-char token from the booking ID; `backend/ticket_token.js` must compute the same value (both are pinned by tests). The QR encodes `https://neon-flight.web.app/t/{bookingId}?token=...`. Only the server writes `publicTickets`; the scanner screen and the hosted page read it by exact ID (public `get`, no `list`). Firebase Hosting serves `web_ticket/` (static verifier page) and rewrites `/t/**` → `index.html`. Changing the token scheme breaks tickets that were already issued.
- **Airport transfers:** `TransferDispatchService` POSTs to the backend `/api/transfer-bookings`. The backend stores the booking and pushes it to the driver through the LINE Messaging API (`line_dispatch.js`). The LINE token never ships in the app.
- **Security rules:** `firestore.rules` restricts users to their own `users/{uid}` subtree and to bookings where `userId == uid`. Update the rules and `backend/rules-tests/firestore-rules.spec.js` whenever you add a collection or field access pattern.
- **Profile data:** personal info and passport are merged into `users/{uid}` via `ProfileStore` (in-memory in mock mode); saved passengers live in `users/{uid}/savedPassengers` and are written during booking.
- **Payments:** only display metadata is stored (card brand plus last 4 digits). Never persist full card numbers, CVV, OTP, PINs, or bank credentials. PromptPay is QR generation only; settlement is checked by a human before `payments.js confirm`. The fare is computed client-side, so the admin must compare the amount received with `fare.total`.
- **Visual system:** colors come from `core/theme.dart` (fidelity scheme from the brand blue, cyan tertiary). Hero headers use `AppTheme.heroGradient` (fixed in both modes so white text stays readable) and "pending" states use `AppTheme.pendingBackground/Foreground`. Don't hard-code light colors like `Colors.white` for surfaces; use `colorScheme.surfaceContainer*` so dark mode works.
- **i18n:** `core/app_localizations.dart` contains a hand-written string map for th, en, ja, zh, and ko, selected through `LanguageProvider`. When you add a UI string, add a key for every language; use `trArgs(lang, key, {'name': value})` for `{name}` placeholders. Service-level messages (e.g. `TicketQrService`) return translation keys, not text.

## Gotchas

- Source files contain Thai text. Keep them UTF-8. Earlier edits caused mojibake that had to be repaired (see the `FIX_THAI_ENCODING.ps1` history). This matters most when writing files from PowerShell, which should use `-Encoding utf8`.
- `lib/` contains stray `*.backup_*` / `*.mojibake_backup_*` files, and the root contains `FIX_*.ps1` / `REPAIR_*.ps1` scripts. They are gitignored local repair artifacts, not live code, so ignore them when reading code.
- `SETUP_5_6.md` (gitignored) documents `FIREBASE_*` dart-defines, which are outdated. Firebase config now comes from the FlutterFire-generated `lib/firebase_options.dart` (regenerate with `flutterfire configure`).
- `android_old/` and `build/` are stale. The active Android project is `android/`.
