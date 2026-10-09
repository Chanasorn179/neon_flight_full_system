import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/app_localizations.dart';
import '../../widgets/common_widgets.dart';
import '../../services/user_profile_store.dart';
import 'payment_methods_screen.dart';
import '../../services/firebase_service.dart';
import '../../models/travel_models.dart';
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
                            builder: (_) => const PaymentMethodsScreen(),
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
  final _form = GlobalKey<FormState>();
  late final TextEditingController name;
  final phone = TextEditingController();
  final address = TextEditingController();
  bool loading = true;
  bool saving = false;

  String get lang => widget.lang;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initialName);
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      try {
        final data = await ProfileStore.load(user.id);
        name.text = (data['name'] as String?)?.trim().isNotEmpty == true
            ? data['name'] as String
            : name.text;
        phone.text = data['phone'] as String? ?? '';
        address.text = data['address'] as String? ?? '';
      } catch (_) {
        // Show the form anyway; saving reports its own errors.
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      await ProfileStore.save(user.id, {
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
      });
      auth.updateName(name.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(lang, 'saved'))),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(lang, 'save_failed'))),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'personal_info'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _FormCard(
                    children: [
                      TextFormField(
                        controller: name,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: tr(lang, 'full_name'),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? tr(lang, 'required') : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        initialValue: widget.initialEmail,
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          helperText: tr(lang, 'email_change_hint'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: tr(lang, 'phone'),
                          prefixIcon: const Icon(Icons.phone_outlined),
                          hintText: '0812345678',
                        ),
                        validator: (v) {
                          final digits = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
                          if (digits.isEmpty) return null;
                          return RegExp(r'^\+?\d{9,15}$').hasMatch(digits)
                              ? null
                              : tr(lang, 'invalid_phone');
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: address,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: tr(lang, 'address'),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(tr(lang, 'save')),
                  ),
                ],
              ),
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
  List<PassengerEntity> passengers = [];
  bool loading = true;

  String get lang => widget.lang;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().currentUser;
    try {
      if (user != null) {
        passengers = await FirebaseService.savedPassengers(user.id);
      }
    } catch (_) {
      passengers = [];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _delete(PassengerEntity p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(lang, 'delete_passenger')),
        content: Text(p.fullName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(lang, 'cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(lang, 'delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    try {
      await FirebaseService.deleteSavedPassenger(user.id, p.passportNumber);
      setState(() => passengers.remove(p));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(lang, 'save_failed'))),
      );
    }
  }

  String _masked(String passport) => passport.length <= 3
      ? passport
      : '${'•' * (passport.length - 3)}${passport.substring(passport.length - 3)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'saved_passengers'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(tr(lang, 'saved_passengers_hint'))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (passengers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(child: Text(tr(lang, 'no_passengers'))),
                  ),
                for (final p in passengers) ...[
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          p.firstName.isEmpty ? '?' : p.firstName.substring(0, 1).toUpperCase(),
                        ),
                      ),
                      title: Text(p.fullName),
                      subtitle: Text('${_masked(p.passportNumber)} · ${p.nationality}'),
                      trailing: IconButton(
                        tooltip: tr(lang, 'delete'),
                        onPressed: () => _delete(p),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

class _PassportScreen extends StatefulWidget {
  const _PassportScreen({required this.lang});
  final String lang;

  @override
  State<_PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<_PassportScreen> {
  final _form = GlobalKey<FormState>();
  final number = TextEditingController();
  final nationality = TextEditingController();
  DateTime? expiry;
  bool loading = true;
  bool saving = false;

  String get lang => widget.lang;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      try {
        final data = await ProfileStore.load(user.id);
        final passport = data['passport'];
        if (passport is Map) {
          number.text = passport['number']?.toString() ?? '';
          nationality.text = passport['nationality']?.toString() ?? '';
          expiry = DateTime.tryParse(passport['expiry']?.toString() ?? '');
        }
      } catch (_) {}
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: expiry ?? now.add(const Duration(days: 365 * 5)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 15)),
    );
    if (picked != null) setState(() => expiry = picked);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    setState(() => saving = true);
    try {
      await ProfileStore.save(user.id, {
        'passport': {
          'number': number.text.trim().toUpperCase(),
          'nationality': nationality.text.trim(),
          if (expiry != null) 'expiry': dateKey(expiry!),
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(lang, 'saved'))),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(lang, 'save_failed'))),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    number.dispose();
    nationality.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'passport'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _FormCard(
                    children: [
                      TextFormField(
                        controller: number,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: tr(lang, 'passport_number'),
                          prefixIcon: const Icon(Icons.menu_book_outlined),
                          hintText: 'AA1234567',
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return tr(lang, 'required');
                          return RegExp(r'^[A-Za-z0-9]{6,9}$').hasMatch(value)
                              ? null
                              : tr(lang, 'invalid_passport');
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: nationality,
                        decoration: InputDecoration(
                          labelText: tr(lang, 'nationality'),
                          prefixIcon: const Icon(Icons.public),
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? tr(lang, 'required') : null,
                      ),
                      const SizedBox(height: 14),
                      FormField<DateTime>(
                        validator: (_) => expiry == null ? tr(lang, 'required') : null,
                        builder: (field) => InkWell(
                          onTap: _pickExpiry,
                          borderRadius: BorderRadius.circular(18),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: tr(lang, 'passport_expiry'),
                              prefixIcon: const Icon(Icons.event_outlined),
                              errorText: field.errorText,
                            ),
                            child: Text(
                              expiry == null ? '-' : dateOf(expiry!),
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(tr(lang, 'save')),
                  ),
                ],
              ),
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

/// yyyy-MM-dd, for storing dates without a time zone.
String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
