import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_localizations.dart';
import '../../providers/language_provider.dart';
import '../booking/booking_history_screen.dart';
import '../profile/profile_screen.dart';
import 'home_search_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  final pages = const [
    DashboardScreen(),
    BookingHistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      // Material 3 navigation bar: 48dp+ targets, selection semantics and
      // the indicator come from the platform component and the app theme.
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _setIndex,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: tr(lang, 'home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.airplane_ticket_outlined),
            selectedIcon: const Icon(Icons.airplane_ticket_rounded),
            label: tr(lang, 'bookings'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: tr(lang, 'profile'),
          ),
        ],
      ),
    );
  }

  void _setIndex(int value) {
    if (index == value) return;
    setState(() => index = value);
  }
}
