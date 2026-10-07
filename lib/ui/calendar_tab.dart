import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'event_editor.dart';
import 'month_view.dart';
import 'week_view.dart';
import 'year_view.dart';

enum ViewMode { month, week, year }

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key, required this.store});
  final AppStore store;

  @override
  State<CalendarTab> createState() => CalendarTabState();
}

class CalendarTabState extends State<CalendarTab> {
  ViewMode mode = ViewMode.month;
  DateTime current = dateOnly(DateTime.now());

  void addEvent({int? minute}) => openEventEditor(context, widget.store, day: current, minute: minute);
  void editEvent(Event e) => openEventEditor(context, widget.store, event: e);

  void _shift(int step) => setState(() {
        current = switch (mode) {
          ViewMode.month => addMonths(current, step),
          ViewMode.week => current.add(Duration(days: 7 * step)),
          ViewMode.year => addMonths(current, 12 * step),
        };
      });

  String get _title {
    switch (mode) {
      case ViewMode.month:
        return 'Tháng ${current.month}, ${current.year}';
      case ViewMode.year:
        return 'Năm ${current.year}';
      case ViewMode.week:
        final a = weekStart(current), b = a.add(const Duration(days: 6));
        return a.month == b.month ? '${a.day} – ${b.day}/${b.month}, ${b.year}' : '${a.day}/${a.month} – ${b.day}/${b.month}';
    }
  }

  Widget _body() {
    final s = widget.store;
    switch (mode) {
      case ViewMode.month:
        return Column(key: const ValueKey('month'), children: [
          MonthGrid(store: s, current: current, onSelect: (d) => setState(() => current = d)),
          const SizedBox(height: 4),
          const Divider(),
          Expanded(child: DayAgenda(store: s, day: current, onEdit: editEvent)),
        ]);
      case ViewMode.week:
        return Column(key: const ValueKey('week'), children: [
          WeekStrip(store: s, current: current, onSelect: (d) => setState(() => current = d)),
          const SizedBox(height: 4),
          Expanded(
            child: DayTimeline(
              key: ValueKey(isoDate(current)),
              store: s,
              day: current,
              onEdit: editEvent,
              onAddAt: (m) => addEvent(minute: m),
            ),
          ),
        ]);
      case ViewMode.year:
        return YearGrid(
          key: const ValueKey('year'),
          store: s,
          current: current,
          onOpenDay: (d) => setState(() {
            current = d;
            mode = ViewMode.month;
          }),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Mochi Planner 🌸', style: TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w800)),
                  Text(_title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ]),
              ),
              TextButton(
                onPressed: () => setState(() => current = dateOnly(DateTime.now())),
                style: TextButton.styleFrom(foregroundColor: kAccent, backgroundColor: kAccentSoft),
                child: const Text('Hôm nay', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded), tooltip: 'Trước'),
              IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded), tooltip: 'Sau'),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ViewMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ViewMode.month, label: Text('Tháng')),
                  ButtonSegment(value: ViewMode.week, label: Text('Tuần')),
                  ButtonSegment(value: ViewMode.year, label: Text('Năm')),
                ],
                selected: {mode},
                onSelectionChanged: (s) => setState(() => mode = s.first),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -350) _shift(1);
                if (v > 350) _shift(-1);
              },
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: _body()),
            ),
          ),
        ]),
      ),
    );
  }
}
