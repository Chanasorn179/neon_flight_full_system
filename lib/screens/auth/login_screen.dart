import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: 'demo@neonflight.app');
  final password = TextEditingController(text: '123456');

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(email.text, password.text);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Login failed')));
  }

  Future<void> _forgot() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.forgot(email.text);
    if (!mounted) return;
    final lang = context.read<LanguageProvider>().languageCode;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? tr(lang, 'reset_sent') : (auth.error ?? 'Error'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LanguageProvider>().languageCode;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.flight_takeoff_rounded, size: 58, color: Color(0xFF0A66C2)),
                      const SizedBox(height: 12),
                      Text('NEON FLIGHT', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(tr(lang, 'login_tagline'), textAlign: TextAlign.center),
                      const SizedBox(height: 28),
                      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                      const SizedBox(height: 12),
                      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
                      Row(
                        children: [
                          Checkbox(value: auth.rememberMe, onChanged: (v) => auth.setRemember(v ?? true)),
                          Text(tr(lang, 'remember_me')),
                          const Spacer(),
                          TextButton(onPressed: auth.loading ? null : _forgot, child: Text(tr(lang, 'forgot_password'))),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: auth.loading ? null : _login,
                        icon: auth.loading
                            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.login),
                        label: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(tr(lang, 'login'))),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: Text(tr(lang, 'create_account')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
