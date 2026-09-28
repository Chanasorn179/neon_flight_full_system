import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/mock_api.dart';
import '../models/entities.dart';
import '../services/firebase_service.dart';

abstract class BookingRepository {
  Future<BookingEntity> create(BookingEntity booking);

  Future<List<BookingEntity>> forUser(String userId);
}

/// ใช้สำหรับโหมด Mock / Offline fallback
class MockBookingRepository implements BookingRepository {
  MockBookingRepository(this.api);

  final MockApi api;

  @override
  Future<BookingEntity> create(BookingEntity booking) {
    // Offline/mock mode has no server to confirm payment.
    return api.createBooking(booking.withPaymentStatus(PaymentStatus.paid));
  }

  @override
  Future<List<BookingEntity>> forUser(String userId) {
    return api.bookings(userId);
  }
}

/// ใช้ Firebase Firestore จริง
class FirebaseBookingRepository implements BookingRepository {
  @override
  Future<BookingEntity> create(BookingEntity booking) async {
    if (!FirebaseService.enabled) {
      throw StateError('Firebase is not initialized');
    }

    final data = _bookingToMap(booking);

    await FirebaseService.saveBooking(
      data,
      booking.id,
    );

    return booking;
  }

  @override
  Future<List<BookingEntity>> forUser(String userId) async {
    if (!FirebaseService.enabled) {
      return [];
    }

    final rows = await FirebaseService.bookingsForUser(userId);

    final bookings = <BookingEntity>[];

    for (final row in rows) {
      try {
        bookings.add(
          _bookingFromMap(row),
        );
      } catch (_) {
        // ข้าม document เก่าหรือข้อมูลไม่ครบ
        // เพื่อไม่ให้หน้ารายการจองพังทั้งหมด
      }
    }

    bookings.sort(
          (a, b) => b.createdAt.compareTo(
        a.createdAt,
      ),
    );

    return bookings;
  }
}

Map<String, dynamic> _bookingToMap(
    BookingEntity booking,
    ) {
  final departureCode =
  booking.flight.departure.code.trim().toUpperCase();

  final arrivalCode =
  booking.flight.arrival.code.trim().toUpperCase();

  return {
    'id': booking.id,
    'userId': booking.userId,

    // เก็บ route ไว้บน booking โดยตรง
    // ทำให้ public ticket อ่านค่าได้แน่นอน
    'departureCode': departureCode,
    'arrivalCode': arrivalCode,

    'flight': _flightToMap(
      booking.flight,
    ),

    'cabinClass': booking.cabinClass.name,

    'passengers': booking.passengers
        .map(
      _passengerToMap,
    )
        .toList(),

    'seats': booking.seats,

    'fare': _fareToMap(
      booking.fare,
    ),

    'paymentMethod':
    booking.paymentMethod.name,

    'status':
    booking.status.name,

    // Firestore rules only accept 'pending' from the app.
    'paymentStatus':
    PaymentStatus.pending.name,

    'createdAt': Timestamp.fromDate(
      booking.createdAt,
    ),
  };
}

BookingEntity _bookingFromMap(
    Map<String, dynamic> json,
    ) {
  final flightRaw = json['flight'];

  if (flightRaw is! Map) {
    throw const FormatException(
      'Booking flight data is missing',
    );
  }

  final flightJson =
  Map<String, dynamic>.from(
    flightRaw,
  );

  final passengersRaw =
      (json['passengers'] as List?) ??
          const [];

  final fareRaw = json['fare'];

  if (fareRaw is! Map) {
    throw const FormatException(
      'Booking fare data is missing',
    );
  }

  final fareJson =
  Map<String, dynamic>.from(
    fareRaw,
  );

  return BookingEntity(
    id:
    json['id']?.toString() ?? '',

    userId:
    json['userId']?.toString() ?? '',

    flight: _flightFromMap(
      flightJson,
    ),

    cabinClass:
    CabinClass.values.firstWhere(
          (value) =>
      value.name ==
          json['cabinClass']?.toString(),
      orElse: () =>
      CabinClass.economy,
    ),

    passengers: passengersRaw
        .whereType<Map>()
        .map(
          (item) => _passengerFromMap(
        Map<String, dynamic>.from(
          item,
        ),
      ),
    )
        .toList(),

    seats:
    ((json['seats'] as List?) ??
        const [])
        .map(
          (item) =>
          item.toString(),
    )
        .toList(),

    fare: _fareFromMap(
      fareJson,
    ),

    paymentMethod:
    PaymentMethod.values.firstWhere(
          (value) =>
      value.name ==
          json['paymentMethod']?.toString(),
      orElse: () =>
      PaymentMethod.promptPay,
    ),

    status:
    BookingStatus.values.firstWhere(
          (value) =>
      value.name ==
          json['status']?.toString(),
      orElse: () =>
      BookingStatus.upcoming,
    ),

    createdAt: _dateFromFirestore(
      json['createdAt'],
    ),

    // Bookings created before payment confirmation existed have no
    // paymentStatus; their tickets were already issued, so treat them as paid.
    paymentStatus: json['paymentStatus'] == PaymentStatus.pending.name
        ? PaymentStatus.pending
        : PaymentStatus.paid,
  );
}

Map<String, dynamic> _flightToMap(
    FlightEntity flight,
    ) {
  final departureCode =
  flight.departure.code.trim().toUpperCase();

  final arrivalCode =
  flight.arrival.code.trim().toUpperCase();

  return {
    'id': flight.id,
    'airline': flight.airline,
    'flightNumber':
    flight.flightNumber,

    // เก็บทั้ง nested และ flat
    // เพื่อให้รองรับโค้ดส่วนอื่นในอนาคต
    'departureCode':
    departureCode,

    'arrivalCode':
    arrivalCode,

    'departure': _airportToMap(
      flight.departure,
    ),

    'arrival': _airportToMap(
      flight.arrival,
    ),

    'departureTime':
    Timestamp.fromDate(
      flight.departureTime,
    ),

    'arrivalTime':
    Timestamp.fromDate(
      flight.arrivalTime,
    ),

    'basePrice':
    flight.basePrice,

    'availableSeats':
    flight.availableSeats,
  };
}

FlightEntity _flightFromMap(
    Map<String, dynamic> json,
    ) {
  final departureRaw =
  json['departure'];

  final arrivalRaw =
  json['arrival'];

  if (departureRaw is! Map ||
      arrivalRaw is! Map) {
    throw const FormatException(
      'Airport data is missing',
    );
  }

  return FlightEntity(
    id:
    json['id']?.toString() ?? '',

    airline:
    json['airline']?.toString() ??
        '',

    flightNumber:
    json['flightNumber']?.toString() ??
        '',

    departure:
    _airportFromMap(
      Map<String, dynamic>.from(
        departureRaw,
      ),
    ),

    arrival:
    _airportFromMap(
      Map<String, dynamic>.from(
        arrivalRaw,
      ),
    ),

    departureTime:
    _dateFromFirestore(
      json['departureTime'],
    ),

    arrivalTime:
    _dateFromFirestore(
      json['arrivalTime'],
    ),

    basePrice:
    (json['basePrice'] as num?)
        ?.toDouble() ??
        0,

    availableSeats:
    (json['availableSeats']
    as num?)
        ?.toInt() ??
        0,
  );
}

Map<String, dynamic> _airportToMap(
    AirportEntity airport,
    ) {
  return {
    'code':
    airport.code.trim().toUpperCase(),

    'cityEn':
    airport.cityEn,

    'cityTh':
    airport.cityTh,

    'nameEn':
    airport.nameEn,

    'nameTh':
    airport.nameTh,
  };
}

AirportEntity _airportFromMap(
    Map<String, dynamic> json,
    ) {
  return AirportEntity(
    code:
    json['code']
        ?.toString()
        .trim()
        .toUpperCase() ??
        '',

    cityEn:
    json['cityEn']?.toString() ??
        '',

    cityTh:
    json['cityTh']?.toString() ??
        '',

    nameEn:
    json['nameEn']?.toString() ??
        '',

    nameTh:
    json['nameTh']?.toString() ??
        '',
  );
}

Map<String, dynamic> _passengerToMap(
    PassengerEntity passenger,
    ) {
  return {
    'title':
    passenger.title,

    'firstName':
    passenger.firstName,

    'lastName':
    passenger.lastName,

    'birthDate':
    Timestamp.fromDate(
      passenger.birthDate,
    ),

    'nationality':
    passenger.nationality,

    'passportNumber':
    passenger.passportNumber,

    'passportExpiry':
    Timestamp.fromDate(
      passenger.passportExpiry,
    ),

    'phone':
    passenger.phone,

    'email':
    passenger.email,
  };
}

PassengerEntity _passengerFromMap(
    Map<String, dynamic> json,
    ) {
  return PassengerEntity(
    title:
    json['title']?.toString() ??
        '',

    firstName:
    json['firstName']?.toString() ??
        '',

    lastName:
    json['lastName']?.toString() ??
        '',

    birthDate:
    _dateFromFirestore(
      json['birthDate'],
    ),

    nationality:
    json['nationality']?.toString() ??
        '',

    passportNumber:
    json['passportNumber']
        ?.toString() ??
        '',

    passportExpiry:
    _dateFromFirestore(
      json['passportExpiry'],
    ),

    phone:
    json['phone']?.toString() ??
        '',

    email:
    json['email']?.toString() ??
        '',
  );
}

Map<String, dynamic> _fareToMap(
    FareBreakdown fare,
    ) {
  return {
    'fare':
    fare.fare,

    'tax':
    fare.tax,

    'service':
    fare.service,

    'seatFee':
    fare.seatFee,

    'total':
    fare.total,
  };
}

FareBreakdown _fareFromMap(
    Map<String, dynamic> json,
    ) {
  return FareBreakdown(
    fare:
    (json['fare'] as num?)
        ?.toDouble() ??
        0,

    tax:
    (json['tax'] as num?)
        ?.toDouble() ??
        0,

    service:
    (json['service'] as num?)
        ?.toDouble() ??
        0,

    seatFee:
    (json['seatFee'] as num?)
        ?.toDouble() ??
        0,
  );
}

DateTime _dateFromFirestore(
    dynamic value,
    ) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(
      value,
    ) ??
        DateTime.now();
  }

  return DateTime.now();
}