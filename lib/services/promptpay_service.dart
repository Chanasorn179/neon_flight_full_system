import 'firebase_service.dart';

class PromptPayService {
  /// Build-time override; otherwise the admin sets it in appConfig/payment.
  static const _buildMerchantId = String.fromEnvironment(
    'PROMPTPAY_ID',
    defaultValue: '',
  );

  static String _remoteMerchantId = '';

  /// Shop name shown under the QR (from appConfig/payment).
  static String merchantName = 'NEON FLIGHT';

  static String get merchantId =>
      _buildMerchantId.trim().isNotEmpty ? _buildMerchantId : _remoteMerchantId;

  static bool get configured => merchantId.trim().isNotEmpty;

  /// Receiving number with all but the last 4 digits hidden.
  static String get maskedMerchantId {
    final digits = merchantId.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return digits;
    return '${'•' * (digits.length - 4)}${digits.substring(digits.length - 4)}';
  }

  /// Loads the shop's PromptPay number set from the admin page.
  static Future<void> loadConfig() async {
    try {
      final config = await FirebaseService.paymentConfig();
      if (config == null) return;
      _remoteMerchantId = (config['promptPayId'] ?? '').toString().trim();
      final name = (config['merchantName'] ?? '').toString().trim();
      if (name.isNotEmpty) merchantName = name;
    } catch (_) {
      // Keep whatever was configured before.
    }
  }

  static String payload({required double amount, String? promptPayId}) {
    final target = (promptPayId ?? merchantId).replaceAll(RegExp(r'\D'), '');
    if (target.isEmpty) throw StateError('PROMPTPAY_ID is not configured');

    final merchantAccount = _merchantAccount(target);
    final body = StringBuffer()
      ..write(_field('00', '01'))
      ..write(_field('01', '11'))
      ..write(_field('29', merchantAccount))
      ..write(_field('58', 'TH'))
      ..write(_field('53', '764'))
      ..write(_field('54', amount.toStringAsFixed(2)))
      ..write(_field('63', ''));

    final raw = body.toString();
    final withoutEmptyCrc = '${raw.substring(0, raw.length - 4)}6304';
    return withoutEmptyCrc + _crc16(withoutEmptyCrc);
  }

  static String _merchantAccount(String id) {
    final aid = _field('00', 'A000000677010111');
    String target;
    if (id.length == 13) {
      target = _field('02', id);
    } else {
      var phone = id;
      if (phone.startsWith('0')) phone = '66${phone.substring(1)}';
      target = _field('01', phone.padLeft(13, '0'));
    }
    return aid + target;
  }

  static String _field(String id, String value) =>
      '$id${value.length.toString().padLeft(2, '0')}$value';

  static String _crc16(String input) {
    var crc = 0xFFFF;
    for (final c in input.codeUnits) {
      crc ^= c << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
