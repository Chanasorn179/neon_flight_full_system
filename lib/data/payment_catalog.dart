import 'package:flutter/material.dart';

/// Card networks the user can pick when saving a card.
class CardBrand {
  const CardBrand(this.name, this.colors);
  final String name;

  /// Gradient for the card preview.
  final List<Color> colors;
}

const cardBrands = <CardBrand>[
  CardBrand('Visa', [Color(0xFF1A1F71), Color(0xFF2D5BD6)]),
  CardBrand('Mastercard', [Color(0xFF222222), Color(0xFFB0281C)]),
  CardBrand('JCB', [Color(0xFF0E4C96), Color(0xFF1C8B45)]),
  CardBrand('American Express', [Color(0xFF1F5E9C), Color(0xFF3FA0D8)]),
  CardBrand('UnionPay', [Color(0xFF8A1020), Color(0xFF0B5C7A)]),
];

CardBrand cardBrandNamed(String name) => cardBrands.firstWhere(
      (b) => b.name.toLowerCase() == name.toLowerCase(),
      orElse: () => const CardBrand('Card', [Color(0xFF3A4252), Color(0xFF5B6475)]),
    );

/// Thai banks offered for mobile banking.
class BankOption {
  const BankOption(this.nameEn, this.nameTh, this.app, this.color);
  final String nameEn;
  final String nameTh;
  final String app;
  final Color color;

  /// Stored as the method detail (no account numbers).
  String get stored => '$nameEn ($app)';
}

const thaiBanks = <BankOption>[
  BankOption('Kasikornbank', 'กสิกรไทย', 'K PLUS', Color(0xFF138F2D)),
  BankOption('SCB', 'ไทยพาณิชย์', 'SCB EASY', Color(0xFF4E2E7F)),
  BankOption('Bangkok Bank', 'กรุงเทพ', 'Bualuang mBanking', Color(0xFF1E4598)),
  BankOption('Krungthai', 'กรุงไทย', 'Krungthai NEXT', Color(0xFF1287C4)),
  BankOption('Krungsri', 'กรุงศรี', 'KMA', Color(0xFF8A6A00)),
  BankOption('ttb', 'ทีทีบี', 'ttb touch', Color(0xFF0050F0)),
  BankOption('GSB', 'ออมสิน', 'MyMo', Color(0xFFC2177A)),
];

BankOption? bankFromStored(String detail) {
  for (final bank in thaiBanks) {
    if (detail.startsWith(bank.nameEn)) return bank;
  }
  return null;
}
