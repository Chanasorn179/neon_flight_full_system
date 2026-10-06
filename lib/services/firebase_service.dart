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

  /// Merges profile fields (name, phone, address, passport) into users/{uid}.
  static Future<void> saveProfile(String id, Map<String, dynamic> data) async {
    if (!enabled) return;
    await firestore.collection('users').doc(id).set(
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ---------------------------------------------------------------------------
  // Bookings
  // ---------------------------------------------------------------------------

  /// Writes [bookings] (id -> data) and one seat lock per seat in a single
  /// batch, so a round trip is saved all-or-nothing. firestore.rules only
  /// accepts new bookings with paymentStatus 'pending' and every seat locked,
  /// and never lets a lock be overwritten: two people cannot book one seat
  /// even if they press pay at the same moment.
  static Future<void> saveBookings(
    Map<String, Map<String, dynamic>> bookings,
  ) async {
    if (!enabled) return;

    final batch = firestore.batch();
    final wanted = <String, Set<String>>{}; // flightKey -> seats

    for (final entry in bookings.entries) {
      final id = entry.key;
      final data = Map<String, dynamic>.from(entry.value);
      // Normalize createdAt so bookings sort as Firestore Timestamps.
      data['createdAt'] = _toFirestoreTimestamp(data['createdAt']);
      final flightKey = data['flightKey'].toString();
      final seats = List<String>.from(data['seats'] as List);
      wanted.putIfAbsent(flightKey, () => {}).addAll(seats);

      batch.set(firestore.collection('bookings').doc(id), {
        ...data,
        'id': id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final seat in seats) {
        batch.set(firestore.collection('seatLocks').doc('${flightKey}_$seat'), {
          'flightKey': flightKey,
          'seat': seat,
          'bookingId': id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    Future<Set<String>> clashes() async => {
          for (final e in wanted.entries)
            ...(await takenSeats(e.key)).intersection(e.value),
        };

    // Fail fast with a clear error when a seat is already gone.
    final early = await clashes();
    if (early.isNotEmpty) throw SeatTakenException(early);

    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        final lost = await clashes();
        if (lost.isNotEmpty) throw SeatTakenException(lost);
      }
      rethrow;
    }
  }

  /// Owner cancels unpaid bookings; their seat locks are deleted in the same
  /// batch (rules only allow that delete once the booking is cancelled).
  static Future<void> cancelBookings(List<String> ids) async {
    if (!enabled || ids.isEmpty) return;
    final locks = await firestore
        .collection('seatLocks')
        .where('bookingId', whereIn: ids)
        .get();
    final batch = firestore.batch();
    for (final id in ids) {
      batch.update(firestore.collection('bookings').doc(id), {
        'status': BookingStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    for (final lock in locks.docs) {
      batch.delete(lock.reference);
    }
    await batch.commit();
  }

  static Future<Set<String>> takenSeats(String flightKey) async {
    if (!enabled) return {};
    final snapshot = await firestore
        .collection('seatLocks')
        .where('flightKey', isEqualTo: flightKey)
        .get();
    return {for (final doc in snapshot.docs) doc.data()['seat'].toString()};
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
  // Payment confirmation and public E-Ticket verification
  //
  // The app never writes publicTickets or paymentStatus = 'paid'. Both are set
  // by backend/scripts/payments.js after an admin confirms the payment, and
  // firestore.rules rejects client writes to them.
  // ---------------------------------------------------------------------------

  /// Emits the booking's payment status whenever it changes.
  static Stream<PaymentStatus> watchPaymentStatus(String bookingId) {
    if (!enabled) return const Stream<PaymentStatus>.empty();

    return firestore
        .collection('bookings')
        .doc(bookingId)
        .snapshots()
        .map(
          (doc) => doc.data()?['paymentStatus'] == PaymentStatus.pending.name
              ? PaymentStatus.pending
              : PaymentStatus.paid,
        );
  }

  /// Reads the public verification record. Anyone may `get` a single ticket by
  /// its tokenized ID, so this works for staff scanning another user's ticket.
  static Future<Map<String, dynamic>?> publicTicket(String bookingId) async {
    if (!enabled) return null;

    final doc = await firestore
        .collection('publicTickets')
        .doc(TicketQrService.publicDocumentId(bookingId))
        .get();

    return doc.data();
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
