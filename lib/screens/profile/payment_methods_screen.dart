import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../data/payment_catalog.dart';
import '../../models/entities.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/payment_methods_provider.dart';

/// Profile > Payment methods: saved cards, banks and PromptPay. The payment
/// screen preselects the default one.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      Future.microtask(() {
        if (mounted) context.read<PaymentMethodsProvider>().load(user.id);
      });
    }
  }

  Future<void> _add(String lang) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const AddPaymentMethodSheet(),
    );
    if (added == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr(lang, 'payment_method_added'))));
    }
  }

  Future<void> _remove(SavedPaymentMethodEntity method, String lang) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(tr(lang, 'remove_payment_method')),
          content: Text(method.summary),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr(lang, 'cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr(lang, 'delete')),
            ),
          ],
        );
      },
    );
    if (ok == true && mounted) {
      await context.read<PaymentMethodsProvider>().remove(method.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final provider = context.watch<PaymentMethodsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'payment_methods'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(lang),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr(lang, 'add_payment_method')),
      ),
      body: provider.loading && provider.methods.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              children: [
                for (final method in provider.methods) ...[
                  _MethodCard(
                    method: method,
                    lang: lang,
                    onDefault: method.isDefault
                        ? null
                        : () => context
                              .read<PaymentMethodsProvider>()
                              .setDefault(method.id),
                    onRemove: () => _remove(method, lang),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(lang, 'payment_privacy_note'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.method,
    required this.lang,
    required this.onDefault,
    required this.onRemove,
  });

  final SavedPaymentMethodEntity method;
  final String lang;
  final VoidCallback? onDefault;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final Widget art = switch (method.type) {
      SavedPaymentType.card => CardPreview(
        brand: cardBrandNamed(method.label),
        last4: RegExp(r'\d{4}').firstMatch(method.detail)?.group(0),
        expiry: RegExp(r'\d{2}/\d{2}').firstMatch(method.detail)?.group(0),
        compact: true,
      ),
      SavedPaymentType.mobileBanking => _IconBadge(
        icon: Icons.account_balance_rounded,
        color: bankFromStored(method.detail)?.color ?? colors.primary,
      ),
      SavedPaymentType.promptPay => _IconBadge(
        icon: Icons.qr_code_2_rounded,
        color: const Color(0xFF1C4E8C),
      ),
    };

    final title = switch (method.type) {
      SavedPaymentType.card => method.label,
      SavedPaymentType.mobileBanking => _bankTitle(method.detail, lang),
      SavedPaymentType.promptPay => 'PromptPay',
    };
    final subtitle = switch (method.type) {
      SavedPaymentType.card => method.detail,
      SavedPaymentType.mobileBanking => 'Mobile Banking',
      SavedPaymentType.promptPay => tr(lang, 'promptpay_scan'),
    };

    return Material(
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: method.isDefault ? colors.primary : colors.outlineVariant,
          width: method.isDefault ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDefault,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              art,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (method.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tr(lang, 'default_method'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else
                      Text(
                        tr(lang, 'tap_to_make_default'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr(lang, 'delete'),
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _bankTitle(String stored, String lang) {
  final bank = bankFromStored(stored);
  if (bank == null) return stored;
  return lang == 'th' ? 'ธนาคาร${bank.nameTh}' : bank.nameEn;
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 46,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

/// Credit-card mock-up showing only brand, last 4 and expiry.
class CardPreview extends StatelessWidget {
  const CardPreview({
    super.key,
    required this.brand,
    this.last4,
    this.expiry,
    this.compact = false,
  });

  final CardBrand brand;
  final String? last4;
  final String? expiry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number =
        '•••• •••• •••• ${last4 == null || last4!.isEmpty ? '••••' : last4!.padRight(4, '•')}';

    if (compact) {
      return Container(
        width: 72,
        height: 46,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: brand.colors),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.bottomRight,
        child: Text(
          brand.name == 'American Express' ? 'AMEX' : brand.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.fade,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1.586, // ISO/IEC 7810 ID-1
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: brand.colors,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: brand.colors.last.withValues(alpha: .35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8C66A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const Spacer(),
                Text(
                  brand.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              number,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              expiry == null || expiry!.isEmpty ? 'MM/YY' : expiry!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: .9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet to add a card, a bank or PromptPay.
class AddPaymentMethodSheet extends StatefulWidget {
  const AddPaymentMethodSheet({super.key});

  @override
  State<AddPaymentMethodSheet> createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends State<AddPaymentMethodSheet> {
  final _form = GlobalKey<FormState>();
  final _last4 = TextEditingController();
  final _expiry = TextEditingController();
  late SavedPaymentType type;
  CardBrand brand = cardBrands.first;
  BankOption? bank;
  bool makeDefault = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PaymentMethodsProvider>();
    type = SavedPaymentType.card;
    makeDefault = provider.methods.isEmpty;
  }

  @override
  void dispose() {
    _last4.dispose();
    _expiry.dispose();
    super.dispose();
  }

  String? _validateExpiry(String? value, String lang) {
    final match = RegExp(r'^(0[1-9]|1[0-2])/(\d{2})$').firstMatch(value ?? '');
    if (match == null) return tr(lang, 'invalid_expiry');
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    final now = DateTime.now();
    // Valid through the end of the expiry month.
    if (DateTime(
      year,
      month + 1,
    ).isBefore(DateTime(now.year, now.month, now.day))) {
      return tr(lang, 'card_expired');
    }
    return null;
  }

  Future<void> _save(String lang) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (type == SavedPaymentType.mobileBanking && bank == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr(lang, 'choose_bank'))));
      return;
    }
    setState(() => saving = true);
    final id = '${type.name}-${DateTime.now().millisecondsSinceEpoch}';
    final method = switch (type) {
      SavedPaymentType.card => SavedPaymentMethodEntity(
        id: id,
        type: type,
        label: brand.name,
        detail: '•••• ${_last4.text} · ${_expiry.text}',
      ),
      SavedPaymentType.mobileBanking => SavedPaymentMethodEntity(
        id: id,
        type: type,
        label: 'Mobile Banking',
        detail: bank!.stored,
      ),
      SavedPaymentType.promptPay => SavedPaymentMethodEntity(
        id: id,
        type: type,
        label: 'PromptPay',
        detail: PaymentMethodsProvider.promptPayDetail,
      ),
    };
    try {
      await context.read<PaymentMethodsProvider>().add(
        method,
        makeDefault: makeDefault,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr(lang, 'save_failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final provider = context.watch<PaymentMethodsProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget typeOption(
      SavedPaymentType value,
      IconData icon,
      String label, {
      bool enabled = true,
    }) {
      final selected = type == value;
      return Expanded(
        child: Opacity(
          opacity: enabled ? 1 : .45,
          child: Material(
            color: selected
                ? colors.primaryContainer
                : colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: enabled ? () => setState(() => type = value) : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 70),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: selected
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final form = switch (type) {
      SavedPaymentType.card => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardPreview(brand: brand, last4: _last4.text, expiry: _expiry.text),
          const SizedBox(height: 16),
          Text(tr(lang, 'card_brand'), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in cardBrands)
                ChoiceChip(
                  label: Text(b.name),
                  selected: brand == b,
                  onSelected: (_) => setState(() => brand = b),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _last4,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: tr(lang, 'card_last4'),
                    counterText: '',
                  ),
                  validator: (v) => RegExp(r'^\d{4}$').hasMatch(v ?? '')
                      ? null
                      : tr(lang, 'invalid_last4'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _expiry,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  inputFormatters: [_ExpiryFormatter()],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: tr(lang, 'card_expiry'),
                    hintText: 'MM/YY',
                    counterText: '',
                  ),
                  validator: (v) => _validateExpiry(v, lang),
                ),
              ),
            ],
          ),
        ],
      ),
      SavedPaymentType.mobileBanking => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(lang, 'choose_bank'), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          RadioGroup<BankOption>(
            groupValue: bank,
            onChanged: (v) => setState(() => bank = v),
            child: Column(
              children: [
                for (final b in thaiBanks)
                  RadioListTile<BankOption>(
                    value: b,
                    contentPadding: EdgeInsets.zero,
                    secondary: CircleAvatar(
                      backgroundColor: b.color,
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(lang == 'th' ? 'ธนาคาร${b.nameTh}' : b.nameEn),
                    subtitle: Text(b.app),
                  ),
              ],
            ),
          ),
        ],
      ),
      SavedPaymentType.promptPay => Row(
        children: [
          const Icon(Icons.qr_code_2_rounded, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Text(tr(lang, 'promptpay_add_hint'))),
        ],
      ),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              tr(lang, 'add_payment_method'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                typeOption(
                  SavedPaymentType.card,
                  Icons.credit_card_rounded,
                  tr(lang, 'method_card'),
                ),
                const SizedBox(width: 10),
                typeOption(
                  SavedPaymentType.mobileBanking,
                  Icons.account_balance_rounded,
                  tr(lang, 'method_mobile_banking'),
                ),
                const SizedBox(width: 10),
                typeOption(
                  SavedPaymentType.promptPay,
                  Icons.qr_code_2_rounded,
                  'PromptPay',
                  enabled: !provider.hasPromptPay,
                ),
              ],
            ),
            const SizedBox(height: 18),
            form,
            const SizedBox(height: 8),
            CheckboxListTile(
              value: makeDefault,
              onChanged: (v) => setState(() => makeDefault = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(tr(lang, 'set_as_default')),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: saving ? null : () => _save(lang),
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(tr(lang, 'save')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Types "1228" as "12/28".
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 4 ? digits.substring(0, 4) : digits;
    final text = clipped.length > 2
        ? '${clipped.substring(0, 2)}/${clipped.substring(2)}'
        : clipped;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
