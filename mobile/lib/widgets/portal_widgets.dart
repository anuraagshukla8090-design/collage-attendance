import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class SectionEyebrow extends StatelessWidget {
  const SectionEyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppPalette.plum,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
      );
}

class ProfileStrip extends StatelessWidget {
  const ProfileStrip({
    super.key,
    required this.name,
    required this.subtitle,
    required this.initials,
  });

  final String name;
  final String subtitle;
  final String initials;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: AppPalette.coralSoft,
                foregroundColor: AppPalette.plum,
                child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.highlight = false,
  });

  final String value;
  final String label;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          constraints: const BoxConstraints(minHeight: 105),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: highlight ? AppPalette.coralSoft : AppPalette.surface,
            border: Border.all(color: AppPalette.border),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppPalette.plum),
                const SizedBox(height: 12),
              ],
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

class PortalBottomBar extends StatelessWidget {
  const PortalBottomBar({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppPalette.surface,
            border: Border.all(color: AppPalette.border),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: onChanged,
            height: 68,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            indicatorColor: AppPalette.coralSoft,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Dashboard'),
              NavigationDestination(icon: Icon(Icons.sensors_outlined), selectedIcon: Icon(Icons.sensors), label: 'Attendance'),
              NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Timetable'),
            ],
          ),
        ),
      );
}

class SoftIconBox extends StatelessWidget {
  const SoftIconBox(this.icon, {super.key, this.size = 54});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppPalette.peach,
          borderRadius: BorderRadius.circular(17),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppPalette.plum, size: size * .48),
      );
}
