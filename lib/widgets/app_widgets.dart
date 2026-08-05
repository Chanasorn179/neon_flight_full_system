import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.icon});
  final String title;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Row(children: [if (icon != null) Icon(icon, color: Theme.of(context).colorScheme.primary), if (icon != null) const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))]);
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 16), Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)), if (action != null) ...[const SizedBox(height: 20), action!]])));
}

String money(double value) => 'THB ${value.toStringAsFixed(0)}';
String two(int v) => v.toString().padLeft(2, '0');
String timeOf(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String dateOf(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';
