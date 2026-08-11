# Neon Flight API

## Driver notifications through LINE

The Flutter app sends a transfer booking to this API. The API stores the
booking once, then sends the assigned driver:

- passenger name;
- passenger phone number;
- pickup GPS coordinates;
- a call button;
- a Google Maps navigation button; and
- a LINE location message.

The LINE Channel Access Token stays on the server and is never included in the
Flutter application.

### 1. Prepare LINE

1. Create a LINE Official Account and enable Messaging API.
2. Set the public HTTPS webhook URL to
   `https://your-api.example.com/api/line/webhook`.
3. Ask the driver to add the account as a friend and send it a message.
4. Copy the verified `LINE driver target ID` printed by the API. A group ID can
   also be used when the Official Account has joined that group.
5. Create a long-lived Channel Access Token in LINE Developers Console.

LINE Notify cannot be used because the service was discontinued in 2025.

### 2. Run the API in PowerShell

```powershell
cd backend
npm install
$env:JWT_SECRET='replace-with-a-long-random-value'
$env:DISPATCH_API_KEY='replace-with-an-app-api-key'
$env:LINE_CHANNEL_ACCESS_TOKEN='your-line-channel-access-token'
$env:LINE_CHANNEL_SECRET='your-line-channel-secret'
$env:LINE_DRIVER_TARGET_ID='Uxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
npm run dev
```

API: `http://localhost:5000/api`  
SQLite database: `backend/neon-flight.db`

### 3. Run Flutter

Android emulator automatically uses `http://10.0.2.2:5000/api`:

```powershell
flutter run -d emulator-5554 --dart-define=NEON_DISPATCH_API_KEY=replace-with-an-app-api-key
```

For a physical phone, point the app to the computer's LAN address:

```powershell
flutter run --dart-define=NEON_API_BASE_URL=http://192.168.1.10:5000/api --dart-define=NEON_DISPATCH_API_KEY=replace-with-an-app-api-key
```

Use HTTPS for every deployed environment. The dispatch API key is suitable for
an initial controlled pilot; production should authenticate the signed-in user
with a short-lived server token instead of relying only on a key embedded in an
application build.

Included schema: users, airports, flights, promotions, bookings, passengers,
booking seats and transfer bookings.
