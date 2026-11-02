import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'clay.dart';

class YearGrid extends StatelessWidget {
  const YearGrid({super.key, required this.store, required this.current, required this.onOpenDay});
  final AppStore store;
  final DateTime current;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        mainAxisExtent: 176,
      ),
      itemCount: 12,
      itemBuilder: (_, i) => FadeUp(
        delay: Duration(milliseconds: 35 * i),
        child: _month(current.year, i + 1),
      ),
    );
  }

  Widget _month(int year, int m) {
    final today = dateOnly(DateTime.now());
    final first = DateTime(year, m, 1);
    final offset = first.weekday - 1;
    final days = daysInMonth(year, m);
    final isThis = today.year == year && today.month == m;
    final rows = ((offset + days) / 7).ceil();
    return Pressable(
      scale: 0.97,
      label: 'Tháng $m',
      onTap: () => onOpenDay(DateTime(year, m, current.day.clamp(1, days))),
      child: Clay(
        radius: 22,
        depth: isThis ? 0.9 : 0.5,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                'Tháng $m',
                style: ts(14, w: FontWeight.w800, c: isThis ? kPrimary : kInk),
              ),
            ),
            for (var r = 0; r < rows; r++)
              Row(children: [for (var c = 0; c < 7; c++) Expanded(child: _day(year, m, r * 7 + c - offset + 1, days, today))]),
          ],
        ),
      ),
    );
  }

  Widget _day(int year, int m, int n, int days, DateTime today) {
    const h = 20.0;
    if (n < 1 || n > days) return const SizedBox(height: h);
    final d = DateTime(year, m, n);
    final evs = store.eventsOn(d);
    final p = evs.isNotEmpty ? pastel(evs.first.color) : (store.todosDueOn(d).isNotEmpty ? pastel('yellow') : null);
    final isToday = d == today;
    return SizedBox(
      height: h,
      child: Center(
        child: Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday ? kPrimary : p?.bg,
            shape: BoxShape.circle,
            border: d == current && !isToday ? Border.all(color: kViolet, width: 1.5) : null,
          ),
          child: Text(
            '$n',
            style: ts(
              9,
              w: (p != null || isToday) ? FontWeight.w800 : FontWeight.w500,
              c: isToday ? Colors.white : (p?.fg ?? (d.weekday == 7 ? kDanger : kInk)),
            ),
          ),
        ),
      ),
    );
  }
}
