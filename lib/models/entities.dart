enum CabinClass { economy, premiumEconomy, business, first }

enum TripType { oneWay, roundTrip }

enum BookingStatus { upcoming, completed, cancelled }

enum PaymentMethod { promptPay, card, mobileBanking }

/// Only the server (backend/scripts/payments.js) may set [paid]; Firestore
/// rules reject any client write that changes it.
enum PaymentStatus { pending, paid }

extension CabinClassX on CabinClass {
  String get labelEn => switch (this) {
    CabinClass.economy => 'Economy',
    CabinClass.premiumEconomy => 'Premium Economy',
    CabinClass.business => 'Business',
    CabinClass.first => 'First Class',
  };
  String get labelTh => switch (this) {
    CabinClass.economy => 'ชั้นประหยัด',
    CabinClass.premiumEconomy => 'ชั้นประหยัดพรีเมียม',
    CabinClass.business => 'ชั้นธุรกิจ',
    CabinClass.first => 'ชั้นหนึ่ง',
  };
  double get multiplier => switch (this) {
    CabinClass.economy => 1,
    CabinClass.premiumEconomy => 1.45,
    CabinClass.business => 2.8,
    CabinClass.first => 4.6,
  };
  double get seatFee => switch (this) {
    CabinClass.economy => 200,
    CabinClass.premiumEconomy => 350,
    CabinClass.business => 800,
    CabinClass.first => 1500,
  };
}

class UserEntity {
  const UserEntity({required this.id, required this.name, required this.email});
  final String id;
  final String name;
  final String email;
}

class AirportEntity {
  const AirportEntity({
    required this.code,
    required this.cityEn,
    required this.cityTh,
    required this.nameEn,
    required this.nameTh,
    this.icao = '',
    this.countryCode = 'TH',
    this.rank = 0,
    this.passengers12m = 0,
  });
  final String code;
  final String cityEn;
  final String cityTh;
  final String nameEn;
  final String nameTh;
  final String icao;
  final String countryCode;

  /// Rank by passengers over the last 12 months (0 = no statistics).
  final int rank;
  final int passengers12m;

  bool get isDomestic => countryCode == 'TH';

  factory AirportEntity.fromJson(Map<String, dynamic> json) => AirportEntity(
        code: json['code'].toString(),
        cityEn: json['cityEn']?.toString() ?? json['code'].toString(),
        cityTh: json['cityTh']?.toString() ?? json['code'].toString(),
        nameEn: json['nameEn']?.toString() ?? json['code'].toString(),
        nameTh: json['nameTh']?.toString() ?? json['code'].toString(),
        icao: json['icao']?.toString() ?? '',
        countryCode: json['countryCode']?.toString() ?? 'TH',
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        passengers12m: (json['passengers12m'] as num?)?.toInt() ?? 0,
      );
}

class AirlineEntity {
  const AirlineEntity({
    required this.code,
    required this.nameEn,
    required this.nameTh,
    required this.hubs,
    required this.international,
    required this.color,
  });
  final String code;
  final String nameEn;
  final String nameTh;
  final List<String> hubs;
  final bool international;

  /// ARGB brand-ish color used for the airline badge.
  final int color;

  /// White square logo tile built by tool/build_airline_logos.py.
  String get logoAsset => 'assets/airlines/$code.png';
}

class FlightEntity {
  const FlightEntity({
    required this.id,
    required this.airline,
    required this.flightNumber,
    required this.departure,
    required this.arrival,
    required this.departureTime,
    required this.arrivalTime,
    required this.basePrice,
    required this.availableSeats,
  });
  final String id;
  final String airline;
  final String flightNumber;
  final AirportEntity departure;
  final AirportEntity arrival;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final double basePrice;
  final int availableSeats;

  Duration get duration => arrivalTime.difference(departureTime);
  double price(CabinClass cabinClass) => basePrice * cabinClass.multiplier;
}

class PassengerEntity {
  const PassengerEntity({
    required this.title,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.nationality,
    required this.passportNumber,
    required this.passportExpiry,
    required this.phone,
    required this.email,
  });
  final String title;
  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final String nationality;
  final String passportNumber;
  final DateTime passportExpiry;
  final String phone;
  final String email;
  String get fullName => '$title $firstName $lastName';
}

class FareBreakdown {
  const FareBreakdown({
    required this.fare,
    required this.tax,
    required this.service,
    required this.seatFee,
  });
  final double fare;
  final double tax;
  final double service;
  final double seatFee;
  double get total => fare + tax + service + seatFee;
}

class BookingEntity {
  const BookingEntity({
    required this.id,
    required this.userId,
    required this.flight,
    required this.cabinClass,
    required this.passengers,
    required this.seats,
    required this.fare,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.paymentStatus = PaymentStatus.pending,
  });
  final String id;
  final String userId;
  final FlightEntity flight;
  final CabinClass cabinClass;
  final List<PassengerEntity> passengers;
  final List<String> seats;
  final FareBreakdown fare;
  final PaymentMethod paymentMethod;
  final BookingStatus status;
  final DateTime createdAt;
  final PaymentStatus paymentStatus;

  bool get isPaid => paymentStatus == PaymentStatus.paid;

  BookingEntity withPaymentStatus(PaymentStatus value) => BookingEntity(
        id: id,
        userId: userId,
        flight: flight,
        cabinClass: cabinClass,
        passengers: passengers,
        seats: seats,
        fare: fare,
        paymentMethod: paymentMethod,
        status: status,
        createdAt: createdAt,
        paymentStatus: value,
      );
}

class GpsLocationEntity {
  const GpsLocationEntity({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

class TransferBookingEntity {
  const TransferBookingEntity({
    required this.id,
    required this.userId,
    required this.airportCode,
    required this.airportNameEn,
    required this.airportNameTh,
    required this.pickupEn,
    required this.pickupTh,
    required this.pickupLocation,
    required this.distanceToAirportKm,
    required this.pickupTime,
    required this.flightDepartureTime,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String airportCode;
  final String airportNameEn;
  final String airportNameTh;
  final String pickupEn;
  final String pickupTh;
  final GpsLocationEntity pickupLocation;
  final double distanceToAirportKm;
  final DateTime pickupTime;
  final DateTime flightDepartureTime;
  final BookingStatus status;
  final DateTime createdAt;
}

class PromotionEntity {
  const PromotionEntity({
    required this.title,
    required this.from,
    required this.to,
    required this.cabinClass,
    required this.discountPercent,
    required this.seatsLeft,
  });
  final String title;
  final String from;
  final String to;
  final CabinClass cabinClass;
  final int discountPercent;
  final int seatsLeft;
}

enum SavedPaymentType { promptPay, card, mobileBanking }

class SavedPaymentMethodEntity {
  const SavedPaymentMethodEntity({
    required this.id,
    required this.type,
    required this.label,
    required this.detail,
  });
  final String id;
  final SavedPaymentType type;
  final String label;
  final String detail;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'label': label,
        'detail': detail,
      };

  factory SavedPaymentMethodEntity.fromJson(Map<String, dynamic> json) => SavedPaymentMethodEntity(
        id: json['id']?.toString() ?? '',
        type: SavedPaymentType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => SavedPaymentType.card,
        ),
        label: json['label']?.toString() ?? '',
        detail: json['detail']?.toString() ?? '',
      );
}
