import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/app_localizations.dart';
import '../../models/entities.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/payment_methods_provider.dart';
import '../../providers/settings_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final paymentMethods = context.watch<PaymentMethodsProvider>();
    final lang = context.watch<LanguageProvider>().languageCode;
    final user = auth.currentUser;
    final name = user?.name ?? 'Aero Traveler';
    final email = user?.email ?? 'demo@neonflight.app';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                tr(lang, 'profile'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _Header(
                    name: name,
                    email: email,
                    lang: lang,
                    onEdit: () => _openPersonal(context, lang, name, email),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickStatCard(
                          icon: Icons.credit_card_rounded,
                          title: tr(lang, 'payment_methods'),
                          value: '${paymentMethods.methods.length}',
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickStatCard(
                          icon: Icons.language_rounded,
                          title: tr(lang, 'language'),
                          value: _currentLanguage(lang),
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  _Section(tr(lang, 'my_account')),
                  const SizedBox(height: 12),
                  _GroupCard(
                    children: [
                      _Menu(
                        icon: Icons.badge_outlined,
                        color: Colors.blue,
                        title: tr(lang, 'personal_info'),
                        subtitle: tr(lang, 'personal_info_sub'),
                        onTap: () => _openPersonal(context, lang, name, email),
                      ),
                      _divider(),
                      _Menu(
                        icon: Icons.group_outlined,
                        color: Colors.indigo,
                        title: tr(lang, 'saved_passengers'),
                        subtitle: tr(lang, 'saved_passengers_sub'),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _SavedPassengersScreen(lang: lang),
                          ),
                        ),
                      ),
                      _divider(),
                      _Menu(
                        icon: Icons.menu_book_outlined,
                        color: Colors.teal,
                        title: tr(lang, 'passport'),
                        subtitle: tr(lang, 'passport_sub'),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _PassportScreen(lang: lang),
                          ),
                        ),
                      ),
                      _divider(),
                      _Menu(
                        icon: Icons.credit_card_outlined,
                        color: Colors.orange,
                        title: tr(lang, 'payment_methods'),
                        subtitle: tr(lang, 'payment_methods_sub'),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _PaymentMethodsScreen(lang: lang),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  _Section(tr(lang, 'preferences')),
                  const SizedBox(height: 12),
                  _GroupCard(
                    children: [
                      _SwitchTile(
                        icon: Icons.dark_mode_outlined,
                        title: tr(lang, 'dark_mode'),
                        subtitle: lang == 'th'
                            ? 'ปรับโทนสีของแอปให้เหมาะกับการใช้งานกลางคืน'
                            : 'Use a darker appearance for nighttime viewing',
                        value: settings.darkMode,
                        onChanged: context.read<SettingsProvider>().setDarkMode,
                      ),
                      _divider(),
                      _SwitchTile(
                        icon: Icons.notifications_none_rounded,
                        title: tr(lang, 'notifications'),
                        subtitle: lang == 'th'
                            ? 'รับการแจ้งเตือนเกี่ยวกับเที่ยวบินและการรับส่ง'
                            : 'Receive updates about flights and transfers',
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
                  const SizedBox(height: 26),
                  SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error.withValues(alpha: .35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
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
                      label: Text(
                        tr(lang, 'logout'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
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
        padding: EdgeInsets.only(left: 72),
        child: Divider(height: 1),
      );

  static void _openPersonal(
    BuildContext context,
    String lang,
    String name,
    String email,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PersonalInfoScreen(
          lang: lang,
          initialName: name,
          initialEmail: email,
        ),
      ),
    );
  }

  static String _currentLanguage(String code) {
    final language = supportedLanguages.firstWhere(
      (item) => item.code == code,
      orElse: () => supportedLanguages.first,
    );
    return '${language.flag} ${language.nativeName}';
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
                  Text(
                    tr(current, 'choose_language'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 14),
                  ...supportedLanguages.map((language) {
                    final selected = language.code == current;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      tileColor: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      leading: Text(
                        language.flag,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(
                        language.nativeName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
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
  const _Header({
    required this.name,
    required this.email,
    required this.lang,
    required this.onEdit,
  });

  final String name;
  final String email;
  final String lang;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .17),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: .25)),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 38),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: .86)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeaderPill(
                  icon: Icons.workspace_premium_outlined,
                  text: lang == 'th' ? 'สมาชิก Neon' : 'Neon Member',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderPill(
                  icon: Icons.verified_user_outlined,
                  text: lang == 'th' ? 'บัญชีปลอดภัย' : 'Account secured',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        // Border keeps the card visible in dark mode, where the card colour
        // is the same as the page background.
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // A Material (not a decorated Container) so the ListTiles inside get
    // their tap ripple; the border keeps the group visible in dark mode.
    return Material(
      color: colors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
      child: Column(children: children),
    );
  }
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
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PersonalInfoScreen extends StatefulWidget {
  const _PersonalInfoScreen({
    required this.lang,
    required this.initialName,
    required this.initialEmail,
  });

  final String lang;
  final String initialName;
  final String initialEmail;

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(widget.lang, 'personal_info'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _FormCard(
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: tr(widget.lang, 'full_name'),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phone,
                decoration: InputDecoration(
                  labelText: tr(widget.lang, 'phone'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: address,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: tr(widget.lang, 'address'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr(widget.lang, 'saved'))),
            ),
            icon: const Icon(Icons.save_outlined),
            label: Text(tr(widget.lang, 'save')),
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Scaffold(
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
              itemBuilder: (context, index) => Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(passengers[index]),
                  trailing: IconButton(
                    onPressed: () => setState(() => passengers.removeAt(index)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _add() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(widget.lang, 'add_passenger')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: tr(widget.lang, 'full_name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(widget.lang, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(tr(widget.lang, 'save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.isNotEmpty) {
      setState(() => passengers.add(value));
    }
  }
}

class _PassportScreen extends StatelessWidget {
  const _PassportScreen({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'passport'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _FormCard(
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: tr(lang, 'passport_number'),
                  prefixIcon: const Icon(Icons.menu_book_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                decoration: InputDecoration(
                  labelText: tr(lang, 'nationality'),
                  prefixIcon: const Icon(Icons.public),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr(lang, 'saved'))),
            ),
            icon: const Icon(Icons.save_outlined),
            label: Text(tr(lang, 'save')),
          ),
        ],
      ),
    );
  }
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
            TextField(
              controller: label,
              decoration: InputDecoration(
                labelText: type == SavedPaymentType.card
                    ? 'ชื่อบนบัตร / ชื่อเรียก'
                    : 'ชื่อวิธีชำระเงิน',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detail,
              keyboardType: type == SavedPaymentType.card
                  ? TextInputType.number
                  : TextInputType.text,
              maxLength: type == SavedPaymentType.card ? 4 : null,
              decoration: InputDecoration(
                labelText: type == SavedPaymentType.card
                    ? 'เลขบัตร 4 หลักท้าย'
                    : 'รายละเอียด',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    await context.read<PaymentMethodsProvider>().add(
          SavedPaymentMethodEntity(
            id: '${type.name}-${DateTime.now().millisecondsSinceEpoch}',
            type: type,
            label: label.text.trim(),
            detail: detail.text.trim(),
          ),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(widget.lang, 'saved'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaymentMethodsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(tr(widget.lang, 'payment_methods'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMethod,
        icon: const Icon(Icons.add_rounded),
        label: Text(tr(widget.lang, 'add')),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: provider.methods.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final method = provider.methods[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  switch (method.type) {
                    SavedPaymentType.promptPay => Icons.qr_code_rounded,
                    SavedPaymentType.card => Icons.credit_card_rounded,
                    SavedPaymentType.mobileBanking => Icons.account_balance_rounded,
                  },
                ),
              ),
              title: Text(method.label, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(method.detail),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => context.read<PaymentMethodsProvider>().remove(method.id),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
