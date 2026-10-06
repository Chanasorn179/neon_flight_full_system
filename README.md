# Neon Flight — Full Airline Booking System

Neon Flight is a Flutter airline booking application with Firebase integration, Firestore persistence, QR-based E-Ticket verification, multiple payment options, saved passenger profiles, and external flight API support.

The project uses normal Dart imports and does not rely on `part` / `part of`.

## Features

### Authentication
- Email / Password registration
- Login
- Logout
- Forgot-password flow
- User profile stored in Firestore

### Flight Search
- One-way and round-trip search
- Departure and arrival airport selection
- Travel date selection
- Passenger count
- Cabin class selection
- Price filtering
- Cheapest / earliest / fastest sorting
- Flight API integration
- Mock flight fallback when the external API is unavailable or restricted

### Cabin Classes
Supported cabin classes:
- Economy
- Premium Economy
- Business
- First Class

Each cabin class can have different:
- Seat layout
- Fare multiplier
- Seat selection fee

### Passenger Information
Passenger forms support:
- Title
- First name
- Last name
- Date of birth
- Nationality
- Passport number
- Passport expiry date
- Phone number
- Email
- Form validation

Passenger information can optionally be saved to Firestore and reused for future bookings.

Saved passenger data:

```text
users/{uid}/savedPassengers/{passengerId}
```

### Seat Selection
Seat selection supports different layouts depending on the selected cabin class.

Example:

```text
Economy
3 - 3

Premium Economy
2 - 3 - 2

Business
2 - 2

First Class
1 - 1
```

### Payment
Supported payment methods:
- PromptPay
- Card
- Mobile Banking

The application stores only safe payment display metadata.

It does not intentionally store:
- Full card numbers
- CVV / CVC
- OTP
- PIN
- Bank passwords
- Full bank account numbers
- Customer PromptPay identifiers

For cards, only limited display information such as the card brand and last four digits should be stored.

Example:

```text
Visa
•••• 1234
```

Payment methods are stored under:

```text
users/{uid}/paymentMethods/{methodId}
```

### PromptPay QR
The application can generate PromptPay-compatible QR payment data.

Run with a PromptPay receiving ID:

```bash
flutter run --dart-define=PROMPTPAY_ID=YOUR_PROMPTPAY_ID
```

Important: the current application demonstrates QR generation and payment UI. It does not yet include full bank/payment-gateway settlement confirmation or webhook verification.

### Booking
Bookings are stored in Firebase Firestore.

```text
bookings/{bookingId}
```

Booking information includes:
- User ID
- Flight
- Departure airport
- Arrival airport
- Cabin class
- Passengers
- Seats
- Fare
- Payment method
- Booking status
- Creation date

Airport route codes are also stored directly:

```text
departureCode
arrivalCode
```

### E-Ticket
After a successful booking, Neon Flight generates an E-Ticket with a QR verification URL.

Example:

```text
https://neon-flight.web.app/t/{BOOKING_ID}?token={TOKEN}
```

The QR can be scanned using:
- Neon Flight
- A smartphone camera
- An external QR scanner

### Public E-Ticket Verification
Public verification records are stored in:

```text
publicTickets/{bookingId_token}
```

The verification page can display:
- VALID / INVALID status
- Booking ID
- Passenger
- Flight number
- Route
- Seat
- Cabin class

Example:

```text
Booking: NF12345678
Flight: NF124
Route: CNX → SIN
Passenger: Mr. Example User
Seat: 5G
Cabin: Premium Economy
Status: VALID
```

The public verification document is separated from the private booking document so the public page does not need access to the full booking data.

### Booking History
Booking history supports:
- Upcoming
- Completed
- Cancelled

Bookings are retrieved from Firestore for the authenticated user.

### Profile and Preferences
- User profile
- Dark mode
- Notifications
- Language switching
- Responsive layouts
- Loading states
- Empty states
- Error states

## Firebase
The application uses:
- Firebase Authentication
- Cloud Firestore
- Firebase Hosting

FlutterFire configuration:

```text
lib/firebase_options.dart
```

Firebase initialization:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## Firestore Structure

```text
users
└── {uid}
    ├── uid
    ├── name
    ├── email
    ├── savedPassengers
    │   └── {passengerId}
    └── paymentMethods
        └── {methodId}

bookings
└── {bookingId}

publicTickets
└── {bookingId_token}
```

## Flight API
The application supports an external flight API through a local backend.

Default API base URL for the Android emulator:

```text
http://10.0.2.2:5000/api
```

Override the API base URL:

```bash
flutter run --dart-define=NEON_API_BASE_URL=http://YOUR_SERVER/api
```

Mock flight fallback is enabled by default.

```bash
--dart-define=ALLOW_MOCK_FLIGHTS=true
```

If the external provider does not support future schedule queries on the current plan, the application may display mock fallback flights.

Mock fallback results must not be considered real airline schedule data.

## Architecture

```text
lib/
├── data/
│   └── mock_api.dart
├── models/
│   └── entities.dart
├── providers/
│   └── application state
├── repositories/
│   ├── authentication repository
│   ├── booking repository
│   └── flight repository
├── screens/
│   └── feature UI
├── services/
│   ├── aviation_api_service.dart
│   ├── firebase_service.dart
│   ├── promptpay_service.dart
│   └── ticket_qr_service.dart
└── widgets/
    └── reusable UI
```

The repository architecture allows implementations to be replaced without tightly coupling the UI to Firebase, REST APIs, or mock data.

## Backend
A sample backend is available under:

```text
backend/
```

It can be used for:
- External API proxying
- Keeping API keys outside the Flutter client
- REST endpoints
- Future secure payment processing
- Future server-side ticket signing

Do not store private API keys directly in Flutter source code.

## Requirements
Recommended development environment:
- Flutter 3.44.x
- Dart 3.12.x
- JDK 17
- Android SDK
- Firebase CLI
- FlutterFire CLI

Check the environment:

```bash
flutter doctor -v
```

## Install Dependencies

```bash
flutter pub get
```

## Analyze

```bash
flutter analyze
```

Expected result:

```text
No issues found!
```

## Run on Android Emulator

```bash
flutter run -d emulator-5554
```

With PromptPay:

```bash
flutter run -d emulator-5554 --dart-define=PROMPTPAY_ID=YOUR_PROMPTPAY_ID
```

With a custom backend:

```bash
flutter run -d emulator-5554 --dart-define=NEON_API_BASE_URL=http://10.0.2.2:5000/api
```

## Firebase Setup

Login:

```bash
firebase login
```

Configure FlutterFire:

```bash
flutterfire configure
```

Deploy Firestore rules:

```bash
firebase deploy --only firestore:rules
```

Deploy hosting:

```bash
firebase deploy --only hosting
```

Deploy both:

```bash
firebase deploy --only hosting,firestore:rules
```

## Android Java Configuration
Use JDK 17 for Android builds.

Example on Windows:

```powershell
flutter config --jdk-dir="C:\Program Files\Eclipse Adoptium\jdk-17.0.20.8-hotspot"
```

Verify:

```powershell
flutter doctor -v
```

The Android toolchain should report Java 17.

## Android Build Warnings
Some warnings can come from third-party Flutter plugins rather than application code.

Examples:
- `mobile_scanner` Kotlin Gradle Plugin migration warning
- Java warnings emitted by Firebase Android dependencies

Do not manually edit package files inside:

```text
C:\Users\Ciel\AppData\Local\Pub\Cache\
```

Update the affected package when the plugin author releases a compatible version.

## Security Notes
For a production deployment:
- Use a trusted payment gateway
- Perform payment verification on a backend
- Never store CVV
- Never store banking passwords
- Never store OTP
- Tokenize payment card data
- Use server-side ticket signing
- Protect private API keys on the server
- Use Firebase App Check where appropriate
- Implement staff/admin authorization separately

## Current System Flow

```text
Register / Login
        ↓
Firebase Authentication
        ↓
Search Flight
        ↓
Flight API / Mock Fallback
        ↓
Passenger Information
        ↓
Saved Passenger
        ↓
Seat Selection
        ↓
Payment
        ↓
Create Booking
        ↓
Cloud Firestore
        ↓
Generate E-Ticket
        ↓
QR Verification URL
        ↓
Firebase Hosting
        ↓
VALID / INVALID Ticket
```

## Project Status
- Firebase Authentication ✅
- Firestore user profiles ✅
- Flight search ✅
- Flight API integration ✅
- Mock API fallback ✅
- Passenger validation ✅
- Saved passengers ✅
- Cabin-specific seat selection ✅
- PromptPay QR ✅
- Card / Mobile Banking UI ✅
- Safe payment metadata storage ✅
- Firebase booking storage ✅
- Booking history ✅
- E-Ticket QR ✅
- External smartphone QR scanning ✅
- Firebase Hosting ticket verification ✅
- Public ticket verification records ✅
- Airport route display on E-Ticket ✅
