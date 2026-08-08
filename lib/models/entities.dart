enum CabinClass { economy, premiumEconomy, business, first }

enum TripType { oneWay, roundTrip }

enum BookingStatus { upcoming, completed, cancelled }

enum PaymentMethod { promptPay, card, mobileBanking }

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
  });
  final String code;
  final String cityEn;
  final String cityTh;
  final String nameEn;
  final String nameTh;
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
