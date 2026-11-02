import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'clay.dart';
import 'widgets.dart';

class MonthGrid extends StatelessWidget {
  const MonthGrid({super.key, required this.store, required this.current, required this.onSelect});
  final AppStore store;
  final DateTime current;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(current.year, current.month, 1);
    final offset = first.weekday - 1;
    final days = daysInMonth(current.year, current.month);
    final rows = ((offset + days) / 7).ceil();
    final today = dateOnly(DateTime.now());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    weekdayShort[i],
                    textAlign: TextAlign.center,
                    style: ts(11, w: FontWeight.w700, c: i == 6 ? kDanger : kMuted),
                  ),
                ),
              ),
          ],
        ),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final n = r * 7 + c - offset + 1;
                      if (n < 1 || n > days) return const SizedBox(height: 44);
                      final d = DateTime(current.year, current.month, n);
                      return _DayCell(
                        day: d,
                        today: d == today,
                        selected: d == current,
                        marks: dotsFor(store, d),
                        onTap: () => onSelect(d),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.today, required this.selected, required this.marks, required this.onTap});
  final DateTime day;
  final bool today;
  final bool selected;
  final List<Color> marks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = '${day.day}';
    Widget number;
    if (today) {
      number = Loop(
        period: const Duration(milliseconds: 1300),
        child: Clay(
          color: kPrimary,
          tint: kPrimary,
          radius: 11,
          depth: 0.7,
          width: 32,
          height: 32,
          child: Center(
            child: Text(
              label,
              style: ts(13, w: FontWeight.w800, c: Colors.white),
            ),
          ),
        ),
        builder: (_, t, c) => Transform.translate(offset: Offset(0, -3 * t), child: c),
      );
    } else if (selected) {
      number = Clay(
        radius: 11,
        depth: 0.5,
        width: 32,
        height: 32,
        child: Center(
          child: Text(
            label,
            style: ts(13, w: FontWeight.w800, c: kPrimary),
          ),
        ),
      );
    } else {
      number = SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Text(
            label,
            style: ts(13, w: FontWeight.w600, c: day.weekday == 7 ? kDanger : kInk),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: fullDate(day),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              number,
              const SizedBox(height: 2),
              SizedBox(height: 5, child: today ? null : dots(marks)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Danh sách mục của một ngày (lịch, khung giờ cố định, việc đến hạn).
class DayAgenda extends StatelessWidget {
  const DayAgenda({super.key, required this.store, required this.day, required this.onEditEvent, required this.onEditRoutine});
  final AppStore store;
  final DateTime day;
  final ValueChanged<Event> onEditEvent;
  final ValueChanged<RoutineBlock> onEditRoutine;

  @override
  Widget build(BuildContext context) {
    final items = itemsOn(store, day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          dayLabel(day),
          trailing: items.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: kPrimarySoft, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '${items.length} mục',
                    style: ts(12, w: FontWeight.w800, c: kPrimary),
                  ),
                ),
        ),
        if (items.isEmpty) const EmptyNote('Ngày trống — thư giãn chút nhé', icon: Ic.coffee),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeUp(
              key: ValueKey('${isoDate(day)}-${items[i].title}-$i'),
              delay: Duration(milliseconds: 60 * i),
              child: ItemTile(
                item: items[i],
                onTap: switch (items[i].kind) {
                  ItemKind.event => () => onEditEvent(items[i].event!),
                  ItemKind.routine => () => onEditRoutine(items[i].routine!),
                  ItemKind.todo => () => store.setTodoDone(items[i].todo!.id, !items[i].todo!.done),
                },
                onToggle: (v) => store.setTodoDone(items[i].todo!.id, v),
              ),
            ),
          ),
      ],
    );
  }
}
