import 'package:flutter_test/flutter_test.dart';
import 'package:mini_projects/models/travel_models.dart';
import 'package:mini_projects/providers/payment_methods_provider.dart';

SavedPaymentMethodEntity method(String id, SavedPaymentType type, String label, String detail) =>
    SavedPaymentMethodEntity(id: id, type: type, label: label, detail: detail);

void main() {
  test('cards keep only brand, last 4 and expiry', () {
    final safe = PaymentMethodsProvider.sanitize(
      method('c1', SavedPaymentType.card, 'Visa', '4111111111111111 · 12/28 cvv 123'),
    );
    // A pasted full number has no standalone 4-digit group, so nothing leaks.
    expect(safe.detail, isNot(contains('4111')));
    expect(safe.detail, '12/28');

    final card = PaymentMethodsProvider.sanitize(
      method('c2', SavedPaymentType.card, 'Mastercard', '•••• 1234 · 09/30'),
    );
    expect(card.label, 'Mastercard');
    expect(card.detail, '•••• 1234 · 09/30');
    expect(card.summary, 'Mastercard •••• 1234');
  });

  test('banks keep only a known bank name; PromptPay keeps no identifier', () {
    final bank = PaymentMethodsProvider.sanitize(
      method('b1', SavedPaymentType.mobileBanking, 'x', 'Kasikornbank (K PLUS) acct 1234567890'),
    );
    expect(bank.detail, 'Kasikornbank (K PLUS)');

    final unknown = PaymentMethodsProvider.sanitize(
      method('b2', SavedPaymentType.mobileBanking, 'x', '123-4-56789-0'),
    );
    expect(unknown.detail, 'Bank');

    final pp = PaymentMethodsProvider.sanitize(
      method('p1', SavedPaymentType.promptPay, 'x', '0812345678'),
    );
    expect(pp.detail, PaymentMethodsProvider.promptPayDetail);
  });

  test('exactly one default; removing it promotes another', () async {
    final provider = PaymentMethodsProvider();
    await provider.load('u1');
    expect(provider.methods.single.type, SavedPaymentType.promptPay);
    expect(provider.defaultMethod!.type, SavedPaymentType.promptPay);

    await provider.add(
      method('card-1', SavedPaymentType.card, 'Visa', '•••• 4242 · 12/29'),
      makeDefault: true,
    );
    expect(provider.methods.where((m) => m.isDefault).map((m) => m.id), ['card-1']);

    // A second PromptPay is ignored.
    await provider.add(method('pp-2', SavedPaymentType.promptPay, 'PromptPay', ''));
    expect(provider.ofType(SavedPaymentType.promptPay), hasLength(1));

    await provider.remove('card-1');
    expect(provider.defaultMethod!.type, SavedPaymentType.promptPay);
    expect(provider.methods.where((m) => m.isDefault), hasLength(1));
  });
}
