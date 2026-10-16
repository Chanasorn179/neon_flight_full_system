import 'package:flutter/material.dart';

import '../core/theme.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.icon});
  final String title;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null)
        Icon(icon, color: Theme.of(context).colorScheme.primary),
      if (icon != null) const SizedBox(width: 8),
      Flexible(
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

/// Baht with thousands separators, e.g. THB 12,450.
String money(double value) {
  final digits = value.round().abs().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
  return 'THB ${value < 0 ? '-' : ''}$digits';
}
String two(int v) => v.toString().padLeft(2, '0');
String timeOf(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String dateOf(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';

/// Neon Flight app mark (login, register).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 92});

  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius: BorderRadius.circular(size * .3),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: .2),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          Icons.flight_takeoff_rounded,
          color: Colors.white,
          size: size * .42,
        ),
      ),
    );
  }
}

/// Icon + bold caption above a form field.
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
}
