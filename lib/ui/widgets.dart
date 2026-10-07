import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, required this.onTap});
  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = pastel(event.color);
    final when = event.start != null ? '${event.start}${event.end != null ? ' – ${event.end}' : ''}' : 'Cả ngày';
    return Material(
      color: p.bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(children: [
            Container(width: 4, height: 38, decoration: BoxDecoration(color: p.fg, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.fg, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(when, style: TextStyle(color: p.fg.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w600)),
                if (event.note.isNotEmpty)
                  Text(event.note,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.fg.withValues(alpha: 0.8), fontSize: 12)),
              ]),
            ),
            if (event.repeat != Repeat.none) Icon(Icons.repeat_rounded, size: 17, color: p.fg),
            if (event.remind != null) Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.notifications_active_rounded, size: 17, color: p.fg)),
          ]),
        ),
      ),
    );
  }
}

class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 6});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, margin: const EdgeInsets.symmetric(horizontal: 1.2), decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Hàng chấm màu thể hiện lịch/việc của một ngày.
Widget dayDots(List<Event> events, int todos, {double size = 6}) {
  final dots = <Widget>[
    for (final e in events.take(3)) Dot(pastel(e.color).fg, size: size),
    if (events.length < 3 && todos > 0) Dot(const Color(0xFFE0B83A), size: size),
  ];
  return Row(mainAxisSize: MainAxisSize.min, children: dots);
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text, style: const TextStyle(color: kMuted, fontWeight: FontWeight.w800, fontSize: 12)),
      );
}

String dayLabel(DateTime d) {
  final t = dateOnly(DateTime.now());
  final dm = '${two(d.day)}/${two(d.month)}';
  if (d == t) return 'Hôm nay, $dm';
  if (d == t.add(const Duration(days: 1))) return 'Ngày mai, $dm';
  return '${weekdayLong[d.weekday - 1]}, $dm';
}
