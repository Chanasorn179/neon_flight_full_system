import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entities.dart';
import '../services/firebase_service.dart';

class PaymentMethodsProvider extends ChangeNotifier {
  final _prefs = SharedPreferencesAsync();

  List<SavedPaymentMethodEntity> methods = [];
  String? _userId;

  /// Loads only sanitized payment metadata.
  ///
  /// This provider intentionally never stores:
  /// - full card numbers
  /// - CVV/CVC
  /// - OTP
  /// - PIN
  /// - bank passwords
  /// - bank account numbers
  /// - the payer's PromptPay phone/national ID
  Future<void> load(String userId) async {
    _userId = userId;

    List<SavedPaymentMethodEntity> local = [];

    final raw = await _prefs.getString('payment_methods_$userId');

    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;

        local = list
            .whereType<Map>()
            .map(
              (e) => SavedPaymentMethodEntity.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .map(_sanitize)
            .toList();
      } catch (_) {
        local = [];
      }
    }

    List<SavedPaymentMethodEntity> cloud = [];

    if (FirebaseService.enabled) {
      try {
        final rows = await FirebaseService.paymentMethods(userId);

        cloud = rows
            .map(SavedPaymentMethodEntity.fromJson)
            .map(_sanitize)
            .toList();
      } catch (_) {
        cloud = [];
      }
    }

    methods = cloud.isNotEmpty ? cloud : local;

    if (methods.isEmpty) {
      methods = const [
        SavedPaymentMethodEntity(
          id: 'promptpay-default',
          type: SavedPaymentType.promptPay,
          label: 'PromptPay',
          detail: 'สแกน QR เพื่อชำระเงิน',
        ),
      ];
    }

    // Re-save after loading. This acts as a local migration:
    // legacy values are replaced with sanitized values.
    await _persist();
    notifyListeners();
  }

  Future<void> add(
    SavedPaymentMethodEntity method,
  ) async {
    final safe = _sanitize(method);

    methods.removeWhere(
      (item) => item.id == safe.id,
    );

    methods.add(safe);

    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    methods.removeWhere(
      (item) => item.id == id,
    );

    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    methods = const [
      SavedPaymentMethodEntity(
        id: 'promptpay-default',
        type: SavedPaymentType.promptPay,
        label: 'PromptPay',
        detail: 'สแกน QR เพื่อชำระเงิน',
      ),
    ];

    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final userId = _userId;

    if (userId == null) return;

    final safeMethods = methods
        .map(_sanitize)
        .toList();

    methods = safeMethods;

    final maps = safeMethods
        .map(
          (e) => e.toJson(),
        )
        .toList();

    await _prefs.setString(
      'payment_methods_$userId',
      jsonEncode(maps),
    );

    if (FirebaseService.enabled) {
      await FirebaseService.savePaymentMethods(
        userId,
        maps,
      );
    }
  }

  SavedPaymentMethodEntity _sanitize(
    SavedPaymentMethodEntity method,
  ) {
    switch (method.type) {
      case SavedPaymentType.promptPay:
        // A customer does not need to save their own PromptPay identifier
        // in order to pay a merchant QR. Discard any supplied identifier.
        return SavedPaymentMethodEntity(
          id: _safeId(method.id),
          type: SavedPaymentType.promptPay,
          label: 'PromptPay',
          detail: 'สแกน QR เพื่อชำระเงิน',
        );

      case SavedPaymentType.card:
        // If the UI accidentally passes a full card number, retain only
        // the final 4 digits. CVV/PIN/OTP are never retained.
        final combined = '${method.label} ${method.detail}';

        final digits = combined.replaceAll(
          RegExp(r'\D'),
          '',
        );

        final last4 = digits.length >= 4
            ? digits.substring(digits.length - 4)
            : '';

        final brand = _cardBrand(combined);

        return SavedPaymentMethodEntity(
          id: _safeId(method.id),
          type: SavedPaymentType.card,
          label: brand,
          detail: last4.isEmpty
              ? 'ไม่เก็บเลขบัตร'
              : '•••• $last4',
        );

      case SavedPaymentType.mobileBanking:
        // Keep only a short display name. Strip digits so an account
        // number cannot accidentally be stored as the "bank name".
        final bank = method.detail
            .replaceAll(RegExp(r'[0-9]'), '')
            .replaceAll(
              RegExp(
                r'cvv|cvc|otp|pin|password|passcode',
                caseSensitive: false,
              ),
              '',
            )
            .replaceAll(
              RegExp(
                r'รหัสผ่าน|รหัสโอทีพี|รหัส otp|รหัส pin',
              ),
              '',
            )
            .replaceAll(
              RegExp(r'\s+'),
              ' ',
            )
            .trim();

        final safeBank = bank.isEmpty
            ? 'ธนาคารที่บันทึกไว้'
            : _limit(bank, 40);

        return SavedPaymentMethodEntity(
          id: _safeId(method.id),
          type: SavedPaymentType.mobileBanking,
          label: 'Mobile Banking',
          detail: safeBank,
        );
    }
  }

  String _cardBrand(String raw) {
    final text = raw.toLowerCase();

    if (text.contains('visa')) {
      return 'Visa';
    }

    if (text.contains('mastercard') ||
        text.contains('master card')) {
      return 'Mastercard';
    }

    if (text.contains('amex') ||
        text.contains('american express')) {
      return 'American Express';
    }

    if (text.contains('jcb')) {
      return 'JCB';
    }

    return 'บัตร';
  }

  String _safeId(String raw) {
    final cleaned = raw
        .replaceAll(
          RegExp(r'[^A-Za-z0-9_-]'),
          '_',
        )
        .trim();

    if (cleaned.isNotEmpty) {
      return _limit(cleaned, 80);
    }

    return 'method_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _limit(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max);
  }
}
