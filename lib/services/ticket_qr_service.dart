import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/travel_models.dart';

class TicketQrService {
  static const _secret = String.fromEnvironment(
    'TICKET_SIGNING_SECRET',
    defaultValue: '',
  );

  static const _legacyPrefix = 'NEON';
  static const _publicBaseUrl = 'https://neon-flight.web.app';

  /// Creates the short verification token used by both the QR and the
  /// Firestore public-ticket document ID.
  static String tokenForBookingId(String bookingId) {
    final normalized = bookingId.trim();
    final bytes = utf8.encode(normalized);

    final digest = _secret.isEmpty
        ? sha256.convert(bytes)
        : Hmac(sha256, utf8.encode(_secret)).convert(bytes);

    return digest.toString().substring(0, 12).toUpperCase();
  }

  static String publicDocumentId(String bookingId) {
    final id = bookingId.trim();
    return '${id}_${tokenForBookingId(id)}';
  }

  /// The QR is now a normal HTTPS URL.
  /// iPhone Camera / Google Lens / generic QR apps can open it directly.
  static String encode(BookingEntity booking) {
    final bookingId = booking.id.trim();
    final token = tokenForBookingId(bookingId);

    return '$_publicBaseUrl/t/'
        '${Uri.encodeComponent(bookingId)}'
        '?token=${Uri.encodeQueryComponent(token)}';
  }

  /// Supports both the new HTTPS QR and old NEON|ID|TOKEN QR values.
  static TicketVerification verify(String raw) {
    try {
      final value = raw.trim();

      if (value.startsWith('https://') || value.startsWith('http://')) {
        return _verifyUrl(value);
      }

      return _verifyLegacy(value);
    } catch (_) {
      return const TicketVerification(
        valid: false,
        message: 'qr_unreadable',
      );
    }
  }

  static TicketVerification _verifyUrl(String value) {
    final uri = Uri.tryParse(value);

    if (uri == null) {
      return const TicketVerification(
        valid: false,
        message: 'qr_bad_url',
      );
    }

    if (uri.host != 'neon-flight.web.app') {
      return const TicketVerification(
        valid: false,
        message: 'qr_wrong_site',
      );
    }

    final segments = uri.pathSegments;

    if (segments.length != 2 || segments.first != 't') {
      return const TicketVerification(
        valid: false,
        message: 'qr_bad_format',
      );
    }

    final bookingId = segments[1].trim();
    final token = (uri.queryParameters['token'] ?? '').trim();

    return _verifyValues(bookingId, token);
  }

  static TicketVerification _verifyLegacy(String value) {
    final parts = value.split('|');

    if (parts.length != 3 || parts[0] != _legacyPrefix) {
      return const TicketVerification(
        valid: false,
        message: 'qr_not_ticket',
      );
    }

    return _verifyValues(parts[1].trim(), parts[2].trim());
  }

  static TicketVerification _verifyValues(
    String bookingId,
    String token,
  ) {
    if (bookingId.isEmpty || token.isEmpty) {
      return const TicketVerification(
        valid: false,
        message: 'qr_incomplete',
      );
    }

    final expected = tokenForBookingId(bookingId);

    if (token.toUpperCase() != expected) {
      return const TicketVerification(
        valid: false,
        message: 'qr_bad_token',
      );
    }

    return TicketVerification(
      valid: true,
      message: 'qr_ok',
      data: {
        'bookingId': bookingId,
        'token': token.toUpperCase(),
      },
    );
  }
}

class TicketVerification {
  const TicketVerification({
    required this.valid,
    required this.message,
    this.data,
  });

  final bool valid;

  /// Translation key for app_localizations.dart.
  final String message;
  final Map<String, dynamic>? data;
}
