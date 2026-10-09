import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/offline_mock_api.dart';
import '../models/travel_models.dart';

class AviationApiService {
  AviationApiService(this.mock);

  final MockApi mock;

  static const String apiBaseUrl = String.fromEnvironment(
    'NEON_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );

  static const bool allowMockFallback = bool.fromEnvironment(
    'ALLOW_MOCK_FLIGHTS',
    defaultValue: true,
  );

  Future<bool> liveApiReady() async {
    try {
      final response = await http
          .get(
        Uri.parse('$apiBaseUrl/health'),
      )
          .timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode != 200) {
        return false;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      return decoded['aviationConfigured'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<FlightEntity>> search(
      String from,
      String to,
      DateTime date,
      ) async {
    final dateString =
        '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    try {
      final uri = Uri.parse(
        '$apiBaseUrl/flights',
      ).replace(
        queryParameters: {
          'from': from,
          'to': to,
          'date': dateString,
        },
      );

      final response = await http
          .get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      )
          .timeout(
        const Duration(seconds: 20),
      );

      if (response.statusCode != 200) {
        if (allowMockFallback) {
          return await mock.searchFlights(
            from,
            to,
            date,
          );
        }

        final message = _apiMessage(
          response.body,
        );

        throw Exception(
          message.isEmpty
              ? 'Flight API returned HTTP ${response.statusCode}'
              : message,
        );
      }

      final decoded = jsonDecode(
        response.body,
      );

      if (decoded is! List) {
        if (allowMockFallback) {
          return await mock.searchFlights(
            from,
            to,
            date,
          );
        }

        throw Exception(
          'Flight API returned an invalid response',
        );
      }

      final flights = decoded
          .whereType<Map>()
          .map(
            (raw) => _flightFromApi(
          Map<String, dynamic>.from(raw),
        ),
      )
          .whereType<FlightEntity>()
          .toList();

      if (flights.isEmpty &&
          allowMockFallback) {
        return await mock.searchFlights(
          from,
          to,
          date,
        );
      }

      return flights;
    } catch (_) {
      if (allowMockFallback) {
        return mock.searchFlights(
          from,
          to,
          date,
        );
      }

      rethrow;
    }
  }

  FlightEntity? _flightFromApi(
      Map<String, dynamic> json,
      ) {
    final departureTime =
    DateTime.tryParse(
      json['departureTime']?.toString() ?? '',
    );

    final arrivalTime =
    DateTime.tryParse(
      json['arrivalTime']?.toString() ?? '',
    );

    if (departureTime == null ||
        arrivalTime == null) {
      return null;
    }

    final departureCode =
        json['departureCode']
            ?.toString()
            .trim()
            .toUpperCase() ??
            '';

    final arrivalCode =
        json['arrivalCode']
            ?.toString()
            .trim()
            .toUpperCase() ??
            '';

    if (departureCode.isEmpty ||
        arrivalCode.isEmpty) {
      return null;
    }

    final basePrice =
        (json['basePrice'] as num?)
            ?.toDouble() ??
            0;

    final availableSeats =
        (json['availableSeats'] as num?)
            ?.toInt() ??
            0;

    return FlightEntity(
      id: json['id']?.toString() ??
          '${json['flightNumber']}_'
              '${departureTime.millisecondsSinceEpoch}',
      airline:
      json['airline']?.toString() ??
          'Airline',
      flightNumber:
      json['flightNumber']?.toString() ??
          'N/A',
      departure: _airport(
        departureCode,
      ),
      arrival: _airport(
        arrivalCode,
      ),
      departureTime:
      departureTime.toLocal(),
      arrivalTime:
      arrivalTime.toLocal(),

      // Aviationstack ให้ข้อมูลเที่ยวบิน
      // ไม่ใช่ระบบ inventory/ราคาจองของสายการบิน
      // ถ้า backend ไม่มีราคา จะใช้ค่า 0
      // หรือ fallback ไป Mock ตามเงื่อนไขด้านบน
      basePrice: basePrice,

      availableSeats: availableSeats,
    );
  }

  AirportEntity _airport(
      String code,
      ) {
    for (final airport in mock.airports) {
      if (airport.code.toUpperCase() ==
          code.toUpperCase()) {
        return airport;
      }
    }

    return AirportEntity(
      code: code.toUpperCase(),
      cityEn: code.toUpperCase(),
      cityTh: code.toUpperCase(),
      nameEn: code.toUpperCase(),
      nameTh: code.toUpperCase(),
    );
  }

  String _apiMessage(
      String raw,
      ) {
    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map &&
          decoded['message'] != null) {
        return decoded['message']
            .toString();
      }

      if (decoded is Map &&
          decoded['error'] is Map) {
        final error = Map<String, dynamic>.from(
          decoded['error'] as Map,
        );

        if (error['message'] != null) {
          return error['message']
              .toString();
        }
      }
    } catch (_) {}

    return '';
  }
}