import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../widgets/portal_widgets.dart';

class TimetableView extends StatelessWidget {
  const TimetableView({super.key, required this.teacherMode});
  final bool teacherMode;

  static const _classes = [
    ('09:00', '09:50', 'Machine Learning', 'Lab 3', 'Dr. Meera Kapoor'),
    ('10:00', '10:50', 'Data Structures', 'C-204', 'Dr. Meera Kapoor'),
    ('11:10', '12:00', 'Computer Networks', 'B-112', 'Dr. Meera Kapoor'),
    ('13:00', '13:50', 'AI Ethics', 'Seminar Hall', 'Dr. Meera Kapoor'),
  ];

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionEyebrow('Monday · 24 June'),
                    const SizedBox(height: 8),
                    Text("Today's classes", style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 5),
                    Text('4 classes scheduled', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(color: AppPalette.coralSoft, borderRadius: BorderRadius.circular(18)),
                child: const Column(
                  children: [
                    Text('JUN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    Text('24', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: const [
                  _DayChip(day: 'M', date: '24', selected: true),
                  _DayChip(day: 'T', date: '25'),
                  _DayChip(day: 'W', date: '26'),
                  _DayChip(day: 'T', date: '27'),
                  _DayChip(day: 'F', date: '28'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          ...List.generate(_classes.length, (index) {
            final item = _classes[index];
            return _ClassTimelineCard(
              start: item.$1,
              end: item.$2,
              subject: item.$3,
              room: item.$4,
              teacher: teacherMode ? 'CSE AI/ML' : item.$5,
              active: index == 0,
              isLast: index == _classes.length - 1,
            );
          }),
        ],
      );
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.date, this.selected = false});
  final String day;
  final String date;
  final bool selected;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppPalette.plum : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(day, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selected ? Colors.white70 : AppPalette.muted)),
              const SizedBox(height: 4),
              Text(date, style: TextStyle(fontWeight: FontWeight.w900, color: selected ? Colors.white : AppPalette.ink)),
            ],
          ),
        ),
      );
}

class _ClassTimelineCard extends StatelessWidget {
  const _ClassTimelineCard({
    required this.start,
    required this.end,
    required this.subject,
    required this.room,
    required this.teacher,
    required this.active,
    required this.isLast,
  });

  final String start;
  final String end;
  final String subject;
  final String room;
  final String teacher;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 68,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(start, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(end, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: active ? AppPalette.coral : AppPalette.border, shape: BoxShape.circle)),
                if (!isLast) Expanded(child: Container(width: 1, color: AppPalette.border)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: active ? AppPalette.coral : AppPalette.surface,
                  border: Border.all(color: active ? AppPalette.coral : AppPalette.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (active) const SectionEyebrow('Now'),
                    if (active) const SizedBox(height: 4),
                    Text(subject, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16),
                        const SizedBox(width: 4),
                        Text(room, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 14),
                        const Icon(Icons.schedule, size: 15),
                        const SizedBox(width: 4),
                        Text('50 min', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(teacher, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
