import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();

    final displayName = name.text.trim();
    final userEmail = email.text.trim();
    final userPassword = password.text;

    if (displayName.isEmpty || userEmail.isEmpty || userPassword.isEmpty) {
      _showMessage('กรุณากรอกข้อมูลให้ครบ');
      return;
    }

    if (userPassword.length < 6) {
      _showMessage('Password ต้องมีอย่างน้อย 6 ตัวอักษร');
      return;
    }

    if (userPassword != confirmPassword.text) {
      _showMessage('Password และยืนยัน Password ไม่ตรงกัน');
      return;
    }

    if (!_acceptedTerms) {
      _showMessage('กรุณายอมรับเงื่อนไขการใช้งานก่อนสมัครสมาชิก');
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(displayName, userEmail, userPassword);

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    _showMessage(auth.error ?? 'Register failed');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -45,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: .10),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton.filledTonal(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _RegisterLogo(),
                      const SizedBox(height: 18),
                      Text(
                        tr(lang, 'register_title'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        lang == 'th'
                            ? 'สร้างบัญชี Neon Flight เพื่อจองและจัดการทุกการเดินทางของคุณ'
                            : 'Create your Neon Flight account and manage every trip in one place',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(alpha: .7),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: theme.brightness == Brightness.dark ? .20 : .05,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _FieldCaption(
                              icon: Icons.person_outline_rounded,
                              text: tr(lang, 'full_name'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: name,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: lang == 'th' ? 'ชื่อและนามสกุล' : 'Full name',
                                prefixIcon: const Icon(Icons.badge_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _FieldCaption(
                              icon: Icons.email_outlined,
                              text: 'Email',
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                hintText: 'you@example.com',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _FieldCaption(
                              icon: Icons.lock_outline_rounded,
                              text: tr(lang, 'password_min'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: password,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.password_rounded),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _FieldCaption(
                              icon: Icons.verified_user_outlined,
                              text: lang == 'th' ? 'ยืนยัน Password' : 'Confirm password',
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: confirmPassword,
                              obscureText: _obscureConfirm,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              onSubmitted: (_) {
                                if (!auth.loading) submit();
                              },
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_reset_rounded),
                                suffixIcon: IconButton(
                                  tooltip: _obscureConfirm ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirm = !_obscureConfirm;
                                    });
                                  },
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _acceptedTerms = !_acceptedTerms;
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: _acceptedTerms,
                                      onChanged: (value) {
                                        setState(() {
                                          _acceptedTerms = value ?? false;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(
                                          lang == 'th'
                                              ? 'ฉันยอมรับเงื่อนไขการใช้งานและนโยบายความเป็นส่วนตัว'
                                              : 'I agree to the Terms of Use and Privacy Policy',
                                          style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (auth.error != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.errorContainer.withValues(alpha: .55),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  auth.error!,
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: auth.loading ? null : submit,
                              icon: auth.loading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.person_add_alt_1_rounded),
                              label: Text(tr(lang, 'register')),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  lang == 'th' ? 'มีบัญชีอยู่แล้ว?' : 'Already have an account?',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                TextButton(
                                  onPressed: auth.loading
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  child: Text(tr(lang, 'login')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterLogo extends StatelessWidget {
  const _RegisterLogo();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: .2),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 42),
      ),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  const _FieldCaption({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
