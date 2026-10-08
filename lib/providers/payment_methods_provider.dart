import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/payment_catalog.dart';
import '../models/entities.dart';
import '../services/firebase_service.dart';

/// The user's saved payment methods (Profile > Payment methods), used to
/// preselect and label the payment on the payment screen.
///
/// Only display metadata is ever stored. Never: full card numbers, CVV/CVC,
/// OTP, PIN, bank passwords, account numbers, or the payer's PromptPay ID.
/// firestore.rules enforces the same shape on users/{uid}/paymentMethods.
class PaymentMethodsProvider extends ChangeNotifier {
  SharedPreferencesAsync? _prefsInstance;
  SharedPreferencesAsync get _prefs => _prefsInstance ??= SharedPreferencesAsync();

  /// Must equal the PromptPay detail string required by firestore.rules.
  static const promptPayDetail = 'สแกน QR เพื่อชำระเงิน';

  static const _defaultPromptPay = SavedPaymentMethodEntity(
    id: 'promptpay-default',
    type: SavedPaymentType.promptPay,
    label: 'PromptPay',
    detail: promptPayDetail,
    isDefault: true,
  );

  List<SavedPaymentMethodEntity> methods = [];
  String? _userId;
  bool loading = false;

  SavedPaymentMethodEntity? get defaultMethod {
    for (final m in methods) {
      if (m.isDefault) return m;
    }
    return methods.isEmpty ? null : methods.first;
  }

  bool get hasPromptPay => methods.any((m) => m.type == SavedPaymentType.promptPay);

  List<SavedPaymentMethodEntity> ofType(SavedPaymentType type) =>
      methods.where((m) => m.type == type).toList();

  Future<void> load(String userId) async {
    if (loading) return;
    _userId = userId;
    loading = true;
    notifyListeners();

    var local = <SavedPaymentMethodEntity>[];
    try {
      final raw = await _prefs.getString('payment_methods_$userId');
      if (raw != null) {
        local = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((e) => sanitize(SavedPaymentMethodEntity.fromJson(Map<String, dynamic>.from(e))))
            .toList();
      }
    } catch (_) {
      local = [];
    }

    var cloud = <SavedPaymentMethodEntity>[];
    if (FirebaseService.enabled) {
      try {
        cloud = (await FirebaseService.paymentMethods(userId))
            .map(SavedPaymentMethodEntity.fromJson)
            .map(sanitize)
            .toList();
      } catch (_) {
        cloud = [];
      }
    }

    methods = cloud.isNotEmpty ? cloud : local;
    if (methods.isEmpty) methods = [_defaultPromptPay];
    _normalizeDefault();
    loading = false;

    // Re-save: migrates legacy entries to the sanitized shape.
    try {
      await _persist();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> add(SavedPaymentMethodEntity method, {bool makeDefault = false}) async {
    final safe = sanitize(method);
    if (safe.type == SavedPaymentType.promptPay && hasPromptPay) return;
    methods = [
      for (final m in methods)
        if (m.id != safe.id) makeDefault ? m.copyWith(isDefault: false) : m,
      safe.copyWith(isDefault: makeDefault),
    ];
    _normalizeDefault();
    await _persist();
    notifyListeners();
  }

  Future<void> setDefault(String id) async {
    methods = [for (final m in methods) m.copyWith(isDefault: m.id == id)];
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    methods = methods.where((m) => m.id != id).toList();
    _normalizeDefault();
    await _persist();
    notifyListeners();
  }

  /// Exactly one default while any method exists.
  void _normalizeDefault() {
    if (methods.isEmpty) return;
    final index = methods.indexWhere((m) => m.isDefault);
    final keep = index == -1 ? 0 : index;
    methods = [
      for (var i = 0; i < methods.length; i++) methods[i].copyWith(isDefault: i == keep),
    ];
  }

  Future<void> _persist() async {
    final userId = _userId;
    if (userId == null) return;
    methods = methods.map(sanitize).toList();
    final maps = methods.map((e) => e.toJson()).toList();
    try {
      await _prefs.setString('payment_methods_$userId', jsonEncode(maps));
    } catch (_) {
      // No local storage available (tests); Firestore is the source of truth.
    }
    if (FirebaseService.enabled) {
      await FirebaseService.savePaymentMethods(userId, maps);
    }
  }

  /// Reduces a method to the fields we are allowed to keep.
  @visibleForTesting
  static SavedPaymentMethodEntity sanitize(SavedPaymentMethodEntity method) {
    final id = _safeId(method.id);
    switch (method.type) {
      case SavedPaymentType.promptPay:
        // Paying a merchant QR never needs the payer's own PromptPay ID.
        return SavedPaymentMethodEntity(
          id: id,
          type: SavedPaymentType.promptPay,
          label: 'PromptPay',
          detail: promptPayDetail,
          isDefault: method.isDefault,
        );

      case SavedPaymentType.card:
        final brand = cardBrands
            .where((b) => '${method.label} ${method.detail}'.toLowerCase().contains(b.name.toLowerCase()))
            .map((b) => b.name)
            .firstOrNull;
        // First group of exactly four digits = last 4 of the card.
        final last4 = RegExp(r'(?<!\d)(\d{4})(?!\d)').firstMatch(method.detail)?.group(1);
        final expiry = RegExp(r'(?<!\d)(0[1-9]|1[0-2])/(\d{2})(?!\d)').firstMatch(method.detail);
        return SavedPaymentMethodEntity(
          id: id,
          type: SavedPaymentType.card,
          label: brand ?? 'Card',
          detail: [
            if (last4 != null) '•••• $last4',
            if (expiry != null) '${expiry.group(1)}/${expiry.group(2)}',
          ].join(' · '),
          isDefault: method.isDefault,
        );

      case SavedPaymentType.mobileBanking:
        // Only a known bank name; never an account number.
        final bank = bankFromStored(method.detail);
        return SavedPaymentMethodEntity(
          id: id,
          type: SavedPaymentType.mobileBanking,
          label: 'Mobile Banking',
          detail: bank?.stored ?? 'Bank',
          isDefault: method.isDefault,
        );
    }
  }

  static String _safeId(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_').trim();
    if (cleaned.isEmpty) return 'method_${DateTime.now().microsecondsSinceEpoch}';
    return cleaned.length <= 80 ? cleaned : cleaned.substring(0, 80);
  }
}
