import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
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
    final rows = ((offset + daysInMonth(current.year, current.month)) / 7).ceil();
    final start = first.subtract(Duration(days: offset));
    final today = dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(weekdayShort[i],
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: i == 6 ? kDanger : kMuted)),
                ),
              ),
            ),
        ]),
        for (var r = 0; r < rows; r++)
          Row(children: [
            for (var c = 0; c < 7; c++)
              Expanded(child: _cell(start.add(Duration(days: r * 7 + c)), today)),
          ]),
      ]),
    );
  }

  Widget _cell(DateTime d, DateTime today) {
    final inMonth = d.month == current.month;
    final isToday = d == today;
    final selected = d == current;
    final events = store.eventsOn(d);
    final todos = store.todosDueOn(d).length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(d),
      child: Container(
        height: 54,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: inMonth ? Colors.white : kOtherMonth,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? kLavender : (isToday ? kAccent : kGrid), width: selected ? 2 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: isToday ? kAccent : null, shape: BoxShape.circle),
            child: Text('${d.day}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isToday
                      ? Colors.white
                      : d.weekday == 7
                          ? (inMonth ? kDanger : const Color(0xFFEBBCCB))
                          : (inMonth ? kInk : const Color(0xFFCDBBD6)),
                )),
          ),
          const SizedBox(height: 3),
          SizedBox(height: 7, child: dayDots(events, todos)),
        ]),
      ),
    );
  }
}

/// Danh sách lịch & việc đến hạn của một ngày.
class DayAgenda extends StatelessWidget {
  const DayAgenda({super.key, required this.store, required this.day, required this.onEdit});
  final AppStore store;
  final DateTime day;
  final ValueChanged<Event> onEdit;

  @override
  Widget build(BuildContext context) {
    final events = store.eventsOn(day);
    final todos = store.todosDueOn(day);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
      children: [
        Row(children: [
          Text(dayLabel(day), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (events.isNotEmpty || todos.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: kAccentSoft, borderRadius: BorderRadius.circular(10)),
              child: Text('${events.length + todos.length}',
                  style: const TextStyle(color: kAccent, fontWeight: FontWeight.w800)),
            ),
        ]),
        const SizedBox(height: 8),
        if (events.isEmpty && todos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Không có gì cả~ thư giãn nhé ☕', style: TextStyle(color: kMuted))),
          ),
        for (final e in events) Padding(padding: const EdgeInsets.only(bottom: 8), child: EventTile(event: e, onTap: () => onEdit(e))),
        if (todos.isNotEmpty) const SectionLabel('VIỆC ĐẾN HẠN'),
        for (final t in todos)
          Card(
            child: CheckboxListTile(
              value: t.done,
              onChanged: (v) => store.setTodoDone(t.id, v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(t.text, style: const TextStyle(fontWeight: FontWeight.w700)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
      ],
    );
  }
}
