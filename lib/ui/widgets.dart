import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'clay.dart';

enum ItemKind { event, routine, todo }

/// Một mục trong ngày: lịch, khung giờ cố định hoặc việc đến hạn.
class DayItem {
  DayItem.event(Event e)
    : kind = ItemKind.event,
      title = e.title,
      start = e.start,
      end = e.end,
      color = e.color,
      event = e,
      routine = null,
      todo = null;
  DayItem.routine(RoutineBlock b)
    : kind = ItemKind.routine,
      title = b.title,
      start = b.start,
      end = b.end,
      color = b.color,
      event = null,
      routine = b,
      todo = null;
  DayItem.todo(Todo t)
    : kind = ItemKind.todo,
      title = t.text,
      start = null,
      end = null,
      color = 'yellow',
      event = null,
      routine = null,
      todo = t;

  final ItemKind kind;
  final String title;
  final String? start;
  final String? end;
  final String color;
  final Event? event;
  final RoutineBlock? routine;
  final Todo? todo;

  (int, int)? get span => event?.span ?? routine?.span;
}

List<DayItem> itemsOn(AppStore s, DateTime d) {
  final timed = <DayItem>[...s.eventsOn(d).map(DayItem.event), ...s.routinesOn(d).map(DayItem.routine)]
    ..sort((a, b) => (a.start ?? '').compareTo(b.start ?? ''));
  return [...timed, ...s.todosDueOn(d).map(DayItem.todo)];
}

/// Màu chấm dưới mỗi ngày: lịch riêng & việc đến hạn (khung giờ cố định lặp mỗi tuần nên không đánh chấm).
List<Color> dotsFor(AppStore s, DateTime d) =>
    [...s.eventsOn(d).map((e) => pastel(e.color).dot), if (s.todosDueOn(d).isNotEmpty) pastel('yellow').dot].take(3).toList();

Widget dots(List<Color> colors, {double size = 5}) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final c in colors)
      Container(
        width: size,
        height: size,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
  ],
);

String dayLabel(DateTime d) {
  final t = dateOnly(DateTime.now());
  final dm = '${d.day} tháng ${d.month}';
  if (d == t) return 'Hôm nay';
  if (d == t.add(const Duration(days: 1))) return 'Ngày mai';
  if (d == t.subtract(const Duration(days: 1))) return 'Hôm qua';
  return '${weekdayLong[d.weekday - 1]}, $dm';
}

String fullDate(DateTime d) => '${weekdayLong[d.weekday - 1]}, ${d.day} tháng ${d.month}';

IconData kindIcon(ItemKind k) => switch (k) {
  ItemKind.event => Ic.calendarClock,
  ItemKind.routine => Ic.repeat,
  ItemKind.todo => Ic.squareCheck,
};

/// Dòng một mục trong danh sách của ngày.
class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.item, this.onTap, this.onToggle});
  final DayItem item;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final done = item.todo?.done ?? false;
    final time = item.start == null
        ? (item.kind == ItemKind.todo ? 'Việc đến hạn' : 'Cả ngày')
        : '${item.start}${item.end != null ? ' – ${item.end}' : ''}';
    final extra = switch (item.kind) {
      ItemKind.routine => ' · Cố định',
      ItemKind.event => (item.event!.remind != null ? ' · Có nhắc' : ''),
      ItemKind.todo => '',
    };
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      label: item.title,
      child: Clay(
        radius: 20,
        depth: 0.6,
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        child: Row(
          children: [
            if (item.kind == ItemKind.todo)
              ClayCheck(value: done, onChanged: (v) => onToggle?.call(v), label: item.title, size: 42)
            else
              IconTile(icon: kindIcon(item.kind), color: item.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(15, w: FontWeight.w700, c: done ? kMuted : kInk, deco: done ? TextDecoration.lineThrough : null),
                  ),
                  const SizedBox(height: 2),
                  Text('$time$extra', style: ts(12, c: kMuted)),
                ],
              ),
            ),
            if (item.kind == ItemKind.event && item.event!.repeat != Repeat.none) const Icon(Ic.repeat2, size: 17, color: kMuted),
            if (item.kind == ItemKind.event && item.event!.remind != null)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Ic.bell, size: 17, color: kMuted),
              ),
            if (item.kind == ItemKind.routine && item.routine!.lockScreen)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Ic.lock, size: 16, color: kMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key, this.icon = Ic.sparkles});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Column(
      children: [
        Float3D(
          tiltX: 0.2,
          lift: 4,
          child: IconTile(icon: icon, color: 'lavender', size: 52),
        ),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: ts(14, c: kMuted),
        ),
      ],
    ),
  );
}
