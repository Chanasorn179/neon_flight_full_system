import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/entities.dart';
import 'ticket_qr_service.dart';

class FirebaseService {
  static bool enabled = false;
  static String? initializationError;

  // ---------------------------------------------------------------------------
  // Firebase initialization
  // ---------------------------------------------------------------------------

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );

      enabled = true;
      initializationError = null;
    } catch (error) {
      enabled = false;
      initializationError = error.toString();
    }
  }

  static FirebaseFirestore get firestore {
    if (!enabled) {
      throw StateError(
        initializationError ?? 'Firebase has not been initialized',
      );
    }

    return FirebaseFirestore.instance;
  }

  // ---------------------------------------------------------------------------
  // Reference data (seeded by backend/scripts/seed_firestore.js)
  // ---------------------------------------------------------------------------

  /// Thai airports ranked by passengers, followed by international ones.
  static Future<List<AirportEntity>> airports() async {
    final snapshot = await firestore.collection('airports').get();
    final list = snapshot.docs
        .map((doc) => AirportEntity.fromJson(doc.data()))
        .toList();
    int order(AirportEntity a) => a.rank == 0 ? 1 << 30 : a.rank;
    list.sort((a, b) => order(a).compareTo(order(b)));
    return list;
  }

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------

  static Future<void> saveUser({
    required String id,
    required String name,
    required String email,
  }) async {
    if (!enabled) return;

    await firestore.collection('users').doc(id).set(
      {
        'uid': id,
        'name': name.trim(),
        'email': email.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ---------------------------------------------------------------------------
  // Bookings
  // ---------------------------------------------------------------------------

  static Future<void> saveBooking(
      Map<String, dynamic> data,
      String id,
      ) async {
    if (!enabled) return;

    final bookingData = Map<String, dynamic>.from(data);

    // Normalize createdAt so new bookings can be sorted/query as Firestore
    // Timestamp even if a repository sends an ISO-8601 String.
    bookingData['createdAt'] = _toFirestoreTimestamp(
      bookingData['createdAt'],
    );

    await firestore.collection('bookings').doc(id).set(
      {
        ...bookingData,
        'id': id,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Public verification document used by the hosted ticket-check page.
    await _savePublicTicket(
      bookingData,
      id,
    );
  }

  static Future<Map<String, dynamic>?> bookingById(
      String bookingId,
      ) async {
    if (!enabled) return null;

    final doc = await firestore
        .collection('bookings')
        .doc(bookingId)
        .get();

    if (!doc.exists) return null;

    return {
      'id': doc.id,
      ...?doc.data(),
    };
  }

  static Future<List<Map<String, dynamic>>> bookingsForUser(
      String userId,
      ) async {
    if (!enabled) return const [];

    final snapshot = await firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .get();

    final rows = snapshot.docs
        .map(
          (doc) => {
        'id': doc.id,
        ...doc.data(),
      },
    )
        .toList();

    rows.sort((a, b) {
      final aDate = _dateFromFirestore(a['createdAt']);
      final bDate = _dateFromFirestore(b['createdAt']);
      return bDate.compareTo(aDate);
    });

    return rows;
  }

  static Stream<List<Map<String, dynamic>>> watchBookingsForUser(
      String userId,
      ) {
    if (!enabled) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }

    return firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final rows = snapshot.docs
          .map(
            (doc) => {
          'id': doc.id,
          ...doc.data(),
        },
      )
          .toList();

      rows.sort((a, b) {
        final aDate = _dateFromFirestore(a['createdAt']);
        final bDate = _dateFromFirestore(b['createdAt']);
        return bDate.compareTo(aDate);
      });

      return rows;
    });
  }

  // ---------------------------------------------------------------------------
  // Public E-Ticket verification
  // ---------------------------------------------------------------------------

  static Future<void> _savePublicTicket(
      Map<String, dynamic> data,
      String bookingId,
      ) async {
    final flight = _asStringMap(data['flight']);

    final departureCode = _readAirportCode(
      bookingData: data,
      flight: flight,
      nestedKeys: const [
        'departure',
        'origin',
        'from',
      ],
      flatKeys: const [
        'departureCode',
        'originCode',
        'fromCode',
        'depIata',
        'dep_iata',
      ],
    );

    final arrivalCode = _readAirportCode(
      bookingData: data,
      flight: flight,
      nestedKeys: const [
        'arrival',
        'destination',
        'to',
      ],
      flatKeys: const [
        'arrivalCode',
        'destinationCode',
        'toCode',
        'arrIata',
        'arr_iata',
      ],
    );

    final flightNumber = _firstText(
      [
        flight['flightNumber'],
        flight['number'],
        data['flightNumber'],
      ],
      fallback: '-',
    );

    final passengersRaw = data['passengers'];
    final passengers = passengersRaw is List
        ? passengersRaw
        : const [];

    String passengerName = '-';

    if (passengers.isNotEmpty) {
      final passenger = _asStringMap(passengers.first);

      passengerName = [
        passenger['title'],
        passenger['firstName'],
        passenger['lastName'],
      ]
          .where(
            (value) =>
        value != null &&
            value.toString().trim().isNotEmpty,
      )
          .map(
            (value) => value.toString().trim(),
      )
          .join(' ');

      if (passengerName.isEmpty) {
        passengerName = _firstText(
          [
            passenger['fullName'],
            passenger['name'],
          ],
          fallback: '-',
        );
      }
    }

    final seatsRaw = data['seats'];
    final seats = seatsRaw is List
        ? seatsRaw
        .map(
          (seat) => seat.toString().trim(),
    )
        .where(
          (seat) => seat.isNotEmpty,
    )
        .toList()
        : <String>[];

    final documentId = TicketQrService.publicDocumentId(
      bookingId,
    );

    await firestore
        .collection('publicTickets')
        .doc(documentId)
        .set(
      {
        'bookingId': bookingId,
        'flightNumber': flightNumber,
        'departureCode': departureCode,
        'arrivalCode': arrivalCode,
        'passengerName': passengerName,
        'seats': seats,
        'cabinClass': _firstText(
          [
            data['cabinClass'],
            data['class'],
          ],
          fallback: '-',
        ),
        'status': _firstText(
          [
            data['status'],
          ],
          fallback: 'upcoming',
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Rebuilds the public verification record for an existing booking.
  ///
  /// Useful for bookings created before `publicTickets` was introduced or
  /// before the airport-code extraction fix.
  static Future<bool> rebuildPublicTicket(
      String bookingId,
      ) async {
    if (!enabled) return false;

    final booking = await bookingById(bookingId);
    if (booking == null) return false;

    await _savePublicTicket(
      booking,
      bookingId,
    );

    return true;
  }

  static String _readAirportCode({
    required Map<String, dynamic> bookingData,
    required Map<String, dynamic> flight,
    required List<String> nestedKeys,
    required List<String> flatKeys,
  }) {
    // 1) flight.departure.code / flight.arrival.code
    //    and compatible alternatives.
    for (final key in nestedKeys) {
      final nested = _asStringMap(flight[key]);

      final code = _firstText(
        [
          nested['code'],
          nested['iata'],
          nested['iataCode'],
          nested['iata_code'],
          nested['airportCode'],
        ],
      );

      if (code.isNotEmpty) {
        return code.toUpperCase();
      }

      // Some sources use a String directly, for example:
      // "departure": "CNX"
      final direct = flight[key];

      if (direct is String) {
        final value = direct.trim();

        if (_looksLikeIata(value)) {
          return value.toUpperCase();
        }
      }
    }

    // 2) flight.departureCode / flight.arrivalCode etc.
    for (final key in flatKeys) {
      final value = flight[key]?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        return value.toUpperCase();
      }
    }

    // 3) Top-level booking fallback.
    for (final key in flatKeys) {
      final value = bookingData[key]?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        return value.toUpperCase();
      }
    }

    // 4) Top-level booking nested fallback.
    for (final key in nestedKeys) {
      final nested = _asStringMap(bookingData[key]);

      final code = _firstText(
        [
          nested['code'],
          nested['iata'],
          nested['iataCode'],
          nested['iata_code'],
          nested['airportCode'],
        ],
      );

      if (code.isNotEmpty) {
        return code.toUpperCase();
      }

      final direct = bookingData[key];

      if (direct is String) {
        final value = direct.trim();

        if (_looksLikeIata(value)) {
          return value.toUpperCase();
        }
      }
    }

    return '-';
  }

  // ---------------------------------------------------------------------------
  // Saved payment methods
  //
  // IMPORTANT:
  // - Never store a full card number, CVV/CVC, OTP, PIN, bank password,
  //   bank-account number, or payer PromptPay identifier.
  // - Only sanitized display metadata is stored here.
  // - Data is stored in users/{uid}/paymentMethods/{methodId}.
  // ---------------------------------------------------------------------------

  static Future<void> savePaymentMethods(
      String userId,
      List<Map<String, dynamic>> methods,
      ) async {
    if (!enabled) return;

    final collection = firestore
        .collection('users')
        .doc(userId)
        .collection('paymentMethods');

    final existing = await collection.get();
    final batch = firestore.batch();

    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    for (final raw in methods) {
      final id = raw['id']?.toString().trim() ?? '';
      final type = raw['type']?.toString().trim() ?? '';
      final label = raw['label']?.toString().trim() ?? '';
      final detail = raw['detail']?.toString().trim() ?? '';

      if (id.isEmpty) continue;

      final ref = collection.doc(id);

      batch.set(
        ref,
        {
          'id': id,
          'type': type,
          'label': label,
          'detail': detail,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    // Remove the old array field from users/{uid}, if it existed.
    // This avoids leaving legacy payment metadata in two places.
    batch.set(
      firestore.collection('users').doc(userId),
      {
        'paymentMethods': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  static Future<List<Map<String, dynamic>>> paymentMethods(
      String userId,
      ) async {
    if (!enabled) return const [];

    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('paymentMethods')
        .get();

    return snapshot.docs
        .map(
          (doc) => {
        'id': doc.id,
        ...doc.data(),
      },
    )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Saved passengers
  // users/{uid}/savedPassengers/{passengerId}
  // ---------------------------------------------------------------------------

  static Future<void> savePassenger(
      String userId,
      PassengerEntity passenger,
      ) async {
    if (!enabled) return;

    final passportKey = passenger.passportNumber
        .trim()
        .toUpperCase()
        .replaceAll(
      RegExp(r'[^A-Z0-9_-]'),
      '_',
    );

    final docId = passportKey.isEmpty
        ? 'passenger_${DateTime.now().millisecondsSinceEpoch}'
        : passportKey;

    await firestore
        .collection('users')
        .doc(userId)
        .collection('savedPassengers')
        .doc(docId)
        .set(
      {
        'title': passenger.title,
        'firstName': passenger.firstName,
        'lastName': passenger.lastName,
        'birthDate': Timestamp.fromDate(
          passenger.birthDate,
        ),
        'nationality': passenger.nationality,
        'passportNumber': passenger.passportNumber,
        'passportExpiry': Timestamp.fromDate(
          passenger.passportExpiry,
        ),
        'phone': passenger.phone,
        'email': passenger.email,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<List<PassengerEntity>> savedPassengers(
      String userId,
      ) async {
    if (!enabled) return const [];

    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('savedPassengers')
        .get();

    final result = <PassengerEntity>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      try {
        result.add(
          PassengerEntity(
            title: data['title']?.toString() ?? 'Mr.',
            firstName: data['firstName']?.toString() ?? '',
            lastName: data['lastName']?.toString() ?? '',
            birthDate: _dateFromFirestore(
              data['birthDate'],
            ),
            nationality: data['nationality']?.toString() ?? 'Thai',
            passportNumber:
            data['passportNumber']?.toString() ?? '',
            passportExpiry: _dateFromFirestore(
              data['passportExpiry'],
            ),
            phone: data['phone']?.toString() ?? '',
            email: data['email']?.toString() ?? '',
          ),
        );
      } catch (_) {
        // Ignore malformed legacy documents.
      }
    }

    result.sort(
          (a, b) => a.fullName
          .toLowerCase()
          .compareTo(
        b.fullName.toLowerCase(),
      ),
    );

    return result;
  }

  static Future<void> deleteSavedPassenger(
      String userId,
      String passportNumber,
      ) async {
    if (!enabled) return;

    final key = passportNumber
        .trim()
        .toUpperCase()
        .replaceAll(
      RegExp(r'[^A-Z0-9_-]'),
      '_',
    );

    if (key.isEmpty) return;

    await firestore
        .collection('users')
        .doc(userId)
        .collection('savedPassengers')
        .doc(key)
        .delete();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const <String, dynamic>{};
  }

  static String _firstText(
      List<dynamic> values, {
        String fallback = '',
      }) {
    for (final value in values) {
      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text != '-') {
        return text;
      }
    }

    return fallback;
  }

  static bool _looksLikeIata(String value) {
    return RegExp(r'^[A-Za-z]{3}$').hasMatch(value.trim());
  }

  static dynamic _toFirestoreTimestamp(dynamic value) {
    if (value == null) {
      return FieldValue.serverTimestamp();
    }

    if (value is Timestamp) {
      return value;
    }

    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return Timestamp.fromDate(parsed);
      }
    }

    return value;
  }

  static DateTime _dateFromFirestore(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime(2000, 1, 1);
    }

    return DateTime(2000, 1, 1);
  }
}
