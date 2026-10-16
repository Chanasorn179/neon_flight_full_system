import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/bottom_nav_shell.dart';

class NeonFlightApp extends StatelessWidget {
  const NeonFlightApp({super.key});

  @override
  Widget build(BuildContext context) {
    // select, not watch: rebuild the app root only when these values change,
    // not on every login spinner or notification toggle.
    final darkMode = context.select<SettingsProvider, bool>((s) => s.darkMode);
    final locale = context.select<LanguageProvider, Locale>((l) => l.locale);
    final signedIn = context.select<AuthProvider, bool>(
      (a) => a.currentUser != null,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NEON FLIGHT',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: theme.scaffoldBackgroundColor,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: signedIn ? const MainShell() : const LoginScreen(),
    );
  }
}
