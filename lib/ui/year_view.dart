import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';

class YearGrid extends StatelessWidget {
  const YearGrid({super.key, required this.store, required this.current, required this.onOpenDay});
  final AppStore store;
  final DateTime current;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 172),
      itemCount: 12,
      itemBuilder: (_, i) => _month(current.year, i + 1),
    );
  }

  Widget _month(int year, int m) {
    final today = dateOnly(DateTime.now());
    final first = DateTime(year, m, 1);
    final offset = first.weekday - 1;
    final days = daysInMonth(year, m);
    final isThisMonth = today.year == year && today.month == m;
    final rows = ((offset + days) / 7).ceil();
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: isThisMonth ? kAccent : kGrid, width: isThisMonth ? 1.8 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onOpenDay(DateTime(year, m, current.day.clamp(1, days))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text('Tháng $m',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isThisMonth ? kAccent : kInk)),
            ),
            Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(weekdayShort[i],
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: i == 6 ? kDanger : kMuted)),
                  ),
                ),
            ]),
            const SizedBox(height: 2),
            for (var r = 0; r < rows; r++)
              Row(children: [
                for (var c = 0; c < 7; c++) Expanded(child: _day(year, m, r * 7 + c - offset + 1, days, today)),
              ]),
          ]),
        ),
      ),
    );
  }

  Widget _day(int year, int m, int n, int days, DateTime today) {
    const h = 19.0;
    if (n < 1 || n > days) return const SizedBox(height: h);
    final d = DateTime(year, m, n);
    final evs = store.eventsOn(d);
    final p = evs.isNotEmpty ? pastel(evs.first.color) : (store.todosDueOn(d).isNotEmpty ? pastel('yellow') : null);
    final isToday = d == today;
    final selected = d == current;
    return SizedBox(
      height: h,
      child: Center(
        child: Container(
          width: 17,
          height: 17,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday ? kAccent : p?.bg,
            shape: BoxShape.circle,
            border: selected ? Border.all(color: kLavender, width: 1.6) : null,
          ),
          child: Text('$n',
              style: TextStyle(
                fontSize: 9,
                fontWeight: (p != null || isToday) ? FontWeight.w800 : FontWeight.w500,
                color: isToday ? Colors.white : (p?.fg ?? (d.weekday == 7 ? kDanger : kInk)),
              )),
        ),
      ),
    );
  }
}
