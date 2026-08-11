import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/entities.dart';

class TransferDispatchException implements Exception {
  const TransferDispatchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TransferDispatchService {
  TransferDispatchService({
    http.Client? client,
    String? apiBaseUrl,
    String? dispatchApiKey,
  }) : _client = client ?? http.Client(),
       _apiBaseUrl = _normalizeBaseUrl(apiBaseUrl ?? _defaultApiBaseUrl()),
       _dispatchApiKey =
           dispatchApiKey ??
           const String.fromEnvironment('NEON_DISPATCH_API_KEY');

  final http.Client _client;
  final String _apiBaseUrl;
  final String _dispatchApiKey;

  Future<void> notifyDriver({
    required TransferBookingEntity booking,
    required String passengerName,
    required String passengerPhone,
  }) async {
    final normalizedName = passengerName.trim();
    final normalizedPhone = passengerPhone.trim();
    if (_dispatchApiKey.isEmpty) {
      throw const TransferDispatchException(
        'NEON_DISPATCH_API_KEY is not configured',
      );
    }
    if (normalizedName.isEmpty || normalizedPhone.isEmpty) {
      throw const TransferDispatchException(
        'Passenger name and phone are required',
      );
    }

    final response = await _client
        .post(
          Uri.parse('$_apiBaseUrl/transfer-bookings'),
          headers: {
            'Content-Type': 'application/json',
            'x-dispatch-key': _dispatchApiKey,
          },
          body: jsonEncode({
            'bookingId': booking.id,
            'userId': booking.userId,
            'passengerName': normalizedName,
            'passengerPhone': normalizedPhone,
            'latitude': booking.pickupLocation.latitude,
            'longitude': booking.pickupLocation.longitude,
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TransferDispatchException(
        'Driver notification failed with status ${response.statusCode}',
      );
    }
  }
}

String _defaultApiBaseUrl() {
  const configured = String.fromEnvironment('NEON_API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:5000/api';
  }
  return 'http://127.0.0.1:5000/api';
}

String _normalizeBaseUrl(String value) =>
    value.endsWith('/') ? value.substring(0, value.length - 1) : value;
