import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/payment_methods_provider.dart';
import '../../models/entities.dart';
import '../../providers/settings_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final lang = context.watch<LanguageProvider>().languageCode;
    final user = auth.currentUser;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: Text(tr(lang, 'profile'), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _Header(
                    name: user?.name ?? 'Aero Traveler',
                    email: user?.email ?? 'demo@neonflight.app',
                    onEdit: () => _openPersonal(context, lang, user?.name ?? 'Aero Traveler', user?.email ?? 'demo@neonflight.app'),
                  ),
                  const SizedBox(height: 26),
                  _Section(tr(lang, 'my_account')),
                  const SizedBox(height: 10),
                  Card(
                    child: Column(
                      children: [
                        _Menu(
                          icon: Icons.badge_outlined,
                          color: Colors.blue,
                          title: tr(lang, 'personal_info'),
                          subtitle: tr(lang, 'personal_info_sub'),
                          onTap: () => _openPersonal(context, lang, user?.name ?? 'Aero Traveler', user?.email ?? 'demo@neonflight.app'),
                        ),
                        _divider(),
                        _Menu(
                          icon: Icons.group_outlined,
                          color: Colors.indigo,
                          title: tr(lang, 'saved_passengers'),
                          subtitle: tr(lang, 'saved_passengers_sub'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => _SavedPassengersScreen(lang: lang)),
                          ),
                        ),
                        _divider(),
                        _Menu(
                          icon: Icons.menu_book_outlined,
                          color: Colors.teal,
                          title: tr(lang, 'passport'),
                          subtitle: tr(lang, 'passport_sub'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => _PassportScreen(lang: lang)),
                          ),
                        ),
                        _divider(),
                        _Menu(
                          icon: Icons.credit_card_outlined,
                          color: Colors.orange,
                          title: tr(lang, 'payment_methods'),
                          subtitle: tr(lang, 'payment_methods_sub'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => _PaymentMethodsScreen(lang: lang)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  _Section(tr(lang, 'preferences')),
                  const SizedBox(height: 10),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.dark_mode_outlined),
                          title: Text(tr(lang, 'dark_mode')),
                          value: settings.darkMode,
                          onChanged: context.read<SettingsProvider>().setDarkMode,
                        ),
                        _divider(),
                        SwitchListTile(
                          secondary: const Icon(Icons.notifications_none_rounded),
                          title: Text(tr(lang, 'notifications')),
                          value: settings.notifications,
                          onChanged: context.read<SettingsProvider>().setNotifications,
                        ),
                        _divider(),
                        _Menu(
                          icon: Icons.language_rounded,
                          color: Colors.deepPurple,
                          title: tr(lang, 'language'),
                          subtitle: _currentLanguage(lang),
                          onTap: () => _showLanguageSheet(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(tr(lang, 'logout')),
                            content: Text(tr(lang, 'logout_confirm')),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(tr(lang, 'cancel')),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(tr(lang, 'logout')),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          context.read<AuthProvider>().logout();
                        }
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(tr(lang, 'logout')),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _divider() => const Padding(
        padding: EdgeInsets.only(left: 68),
        child: Divider(height: 1),
      );

  static void _openPersonal(BuildContext context, String lang, String name, String email) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PersonalInfoScreen(lang: lang, initialName: name, initialEmail: email),
      ),
    );
  }

  static String _currentLanguage(String code) {
    final l = supportedLanguages.firstWhere((e) => e.code == code, orElse: () => supportedLanguages.first);
    return '${l.flag} ${l.nativeName}';
  }

  static void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer<LanguageProvider>(
        builder: (context, provider, _) {
          final current = provider.languageCode;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(current, 'choose_language'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  ...supportedLanguages.map((language) {
                    final selected = language.code == current;
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      tileColor: selected ? Theme.of(context).colorScheme.primaryContainer : null,
                      leading: Text(language.flag, style: const TextStyle(fontSize: 28)),
                      title: Text(language.nativeName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(language.name),
                      trailing: selected ? const Icon(Icons.check_circle_rounded) : null,
                      onTap: () {
                        provider.setLanguage(language.code);
                        Navigator.pop(sheetContext);
                      },
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.email, required this.onEdit});
  final String name, email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.primary, c.primary.withValues(alpha: .72)]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: c.primary.withValues(alpha: .18), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: .8))),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: Colors.white)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      );
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
      );
}

class _PersonalInfoScreen extends StatefulWidget {
  const _PersonalInfoScreen({required this.lang, required this.initialName, required this.initialEmail});
  final String lang, initialName, initialEmail;

  @override
  State<_PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<_PersonalInfoScreen> {
  late final TextEditingController name;
  late final TextEditingController email;
  final phone = TextEditingController();
  final address = TextEditingController();

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initialName);
    email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr(widget.lang, 'personal_info'))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(controller: name, decoration: InputDecoration(labelText: tr(widget.lang, 'full_name'), prefixIcon: const Icon(Icons.person_outline))),
            const SizedBox(height: 14),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
            const SizedBox(height: 14),
            TextField(controller: phone, decoration: InputDecoration(labelText: tr(widget.lang, 'phone'), prefixIcon: const Icon(Icons.phone_outlined))),
            const SizedBox(height: 14),
            TextField(controller: address, maxLines: 3, decoration: InputDecoration(labelText: tr(widget.lang, 'address'), prefixIcon: const Icon(Icons.location_on_outlined))),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(widget.lang, 'saved')))),
              icon: const Icon(Icons.save_outlined),
              label: Text(tr(widget.lang, 'save')),
            ),
          ],
        ),
      );
}

class _SavedPassengersScreen extends StatefulWidget {
  const _SavedPassengersScreen({required this.lang});
  final String lang;

  @override
  State<_SavedPassengersScreen> createState() => _SavedPassengersScreenState();
}

class _SavedPassengersScreenState extends State<_SavedPassengersScreen> {
  final passengers = <String>[];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr(widget.lang, 'saved_passengers'))),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.person_add_alt_1),
          label: Text(tr(widget.lang, 'add')),
        ),
        body: passengers.isEmpty
            ? Center(child: Text(tr(widget.lang, 'no_passengers')))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: passengers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(passengers[i]),
                    trailing: IconButton(
                      onPressed: () => setState(() => passengers.removeAt(i)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
              ),
      );

  Future<void> _add() async {
    final c = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(widget.lang, 'add_passenger')),
        content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: tr(widget.lang, 'full_name'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr(widget.lang, 'cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: Text(tr(widget.lang, 'save'))),
        ],
      ),
    );
    c.dispose();
    if (value != null && value.isNotEmpty) setState(() => passengers.add(value));
  }
}

class _PassportScreen extends StatelessWidget {
  const _PassportScreen({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr(lang, 'passport'))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(decoration: InputDecoration(labelText: tr(lang, 'passport_number'), prefixIcon: const Icon(Icons.menu_book_outlined))),
            const SizedBox(height: 14),
            TextField(decoration: InputDecoration(labelText: tr(lang, 'nationality'), prefixIcon: const Icon(Icons.public))),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(lang, 'saved')))),
              icon: const Icon(Icons.save_outlined),
              label: Text(tr(lang, 'save')),
            ),
          ],
        ),
      );
}

class _PaymentMethodsScreen extends StatefulWidget {
  const _PaymentMethodsScreen({required this.lang});
  final String lang;

  @override
  State<_PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<_PaymentMethodsScreen> {
  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      final user = context.read<AuthProvider>().currentUser;
      final paymentMethods = context.read<PaymentMethodsProvider>();
      if (user != null) {
        Future.microtask(() => paymentMethods.load(user.id));
      }
    }
  }

  Future<void> _addMethod() async {
    final type = await showModalBottomSheet<SavedPaymentType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.qr_code_rounded)),
                title: const Text('PromptPay'),
                subtitle: const Text('บันทึกเป็นวิธีชำระเงินที่ต้องการ'),
                onTap: () => Navigator.pop(context, SavedPaymentType.promptPay),
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.credit_card_rounded)),
                title: const Text('บัตรเครดิต / เดบิต'),
                subtitle: const Text('เก็บเฉพาะชื่อและเลข 4 หลักท้าย ไม่เก็บ CVV'),
                onTap: () => Navigator.pop(context, SavedPaymentType.card),
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.account_balance_rounded)),
                title: const Text('Mobile Banking'),
                subtitle: const Text('บันทึกชื่อธนาคารที่ใช้งาน'),
                onTap: () => Navigator.pop(context, SavedPaymentType.mobileBanking),
              ),
            ],
          ),
        ),
      ),
    );
    if (type == null || !mounted) return;

    final label = TextEditingController();
    final detail = TextEditingController();
    if (type == SavedPaymentType.promptPay) {
      label.text = 'PromptPay';
      detail.text = 'สแกน QR ตอนชำระเงิน';
    } else if (type == SavedPaymentType.mobileBanking) {
      label.text = 'Mobile Banking';
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เพิ่มวิธีชำระเงิน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: label, decoration: InputDecoration(labelText: type == SavedPaymentType.card ? 'ชื่อบนบัตร / ชื่อเรียก' : 'ชื่อวิธีชำระเงิน')),
            const SizedBox(height: 12),
            TextField(
              controller: detail,
              keyboardType: type == SavedPaymentType.card ? TextInputType.number : TextInputType.text,
              maxLength: type == SavedPaymentType.card ? 4 : null,
              decoration: InputDecoration(labelText: type == SavedPaymentType.card ? 'เลขบัตร 4 หลักท้าย' : 'รายละเอียด'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('เพิ่ม')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final d = detail.text.trim();
    if (type == SavedPaymentType.card && (d.length != 4 || int.tryParse(d) == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรอกเลขบัตร 4 หลักท้ายให้ถูกต้อง')));
      return;
    }
    await context.read<PaymentMethodsProvider>().add(
          SavedPaymentMethodEntity(
            id: 'pm_${DateTime.now().millisecondsSinceEpoch}',
            type: type,
            label: label.text.trim().isEmpty ? type.name : label.text.trim(),
            detail: type == SavedPaymentType.card ? '•••• $d' : d,
          ),
        );
  }

  IconData _icon(SavedPaymentType type) => switch (type) {
        SavedPaymentType.promptPay => Icons.qr_code_rounded,
        SavedPaymentType.card => Icons.credit_card_rounded,
        SavedPaymentType.mobileBanking => Icons.account_balance_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaymentMethodsProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(tr(widget.lang, 'payment_methods'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMethod,
        icon: const Icon(Icons.add_card),
        label: Text(tr(widget.lang, 'add')),
      ),
      body: provider.methods.isEmpty
          ? const Center(child: Text('ยังไม่มีวิธีชำระเงิน'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.methods.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final method = provider.methods[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(_icon(method.type))),
                    title: Text(method.label),
                    subtitle: method.detail.isEmpty ? null : Text(method.detail),
                    trailing: IconButton(
                      onPressed: () => provider.remove(method.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

