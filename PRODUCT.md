# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users
Primary audience is the course instructor and examination committee watching a live demo of the app on an Android emulator or phone during a class presentation. The modelled end user is a Thai traveller booking a domestic or regional flight on their own phone, reading Thai first, with English, Japanese, Chinese and Korean also supported.

## Product Purpose
Neon Flight is a university project: a complete flight-booking app built with Flutter and Firebase. It must demonstrate an end-to-end journey (search, passengers, seat, payment, e-ticket, airport transfer) that works for real and looks professional enough to be credible in a demo. Success is a smooth, legible walkthrough that makes every system visible and understandable to an audience in a few minutes.

## Positioning
Built around Thai aviation data: airports and airlines ranked from real AOT/DOA traffic statistics, fares estimated from great-circle distance plus the real AOT passenger service charge, PromptPay and Thai mobile banking payments, and airport transfers dispatched to drivers over LINE.

## Operating Context
Demoed live on an Android emulator (Pixel class device) in Android Studio, projected to a room, and also shown as screenshots in a Canva slide deck. Payments are confirmed by an admin on a separate web page (`backend/admin_web`). Debug builds on an emulator are slower than release builds.

## Capabilities and Constraints
- Flutter 3.47 / Material 3, Provider state management, Firebase Auth/Firestore/Hosting, Node/Express backend.
- Systems: account and profile, flight search (one-way/round trip), passengers and seat map with seat locks, take-off animation (NASA globe, OSM map), PromptPay/card/mobile-banking payment, admin payment confirmation, QR e-ticket with scanner and web verifier, booking history and notifications, airport transfer with real road distance (OSRM).
- Five languages (th, en, ja, zh, ko) through a hand-written string map; every UI string needs all five.
- Light and dark themes. The seat screen is always dark.
- Card data is display-only (brand and last four digits); fares are estimates, not live prices.
- Tests: Flutter widget tests, a screenshot harness (`test/screenshots`, including 320px narrow screens), backend and Firestore-rules tests. Changes must keep them passing.

## Brand Commitments
Name "Neon Flight". Existing brand blue with a cyan accent (`lib/core/theme.dart`), the airplane app mark, and the dark boarding-pass styling on the seat and take-off screens. The look is to be refined, not replaced; the Canva deck uses screenshots of the current identity.

## Evidence on Hand
Real airport and airline reference data (`lib/data/thai_airports.dart`, `thai_airlines.dart`), airline logos (`assets/airlines/`), NASA Blue Marble texture (`assets/earth/`). No real customers, testimonials or live fare feed exist; demo flights are generated.

## Product Principles
1. Every system must be visible and explainable in a short live demo.
2. Thai text first: layouts must hold up with long Thai strings and in all five languages.
3. Booking steps read as one continuous journey, with the current step and price always clear.
4. Honest data: estimates and demo values are never presented as live facts.
5. Refine the existing identity; do not break tests, screenshots or the slide deck.

## Accessibility & Inclusion
No formal standard was set. Baseline: legible text at projector distance, WCAG AA contrast in light and dark themes, 48dp touch targets, reduced-motion respected (the take-off animation already skips under it).
