import 'package:flutter/material.dart';

import '../layout.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'widgets.dart';

DateTime weekStart(DateTime d) => dateOnly(d).subtract(Duration(days: d.weekday - 1));

class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.store, required this.current, required this.onSelect});
  final AppStore store;
  final DateTime current;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final ws = weekStart(current);
    final today = dateOnly(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(builder: (_) {
              final d = ws.add(Duration(days: i));
              final sel = d == current, isToday = d == today;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(d),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? kAccentSoft : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: sel ? kLavender : kGrid, width: sel ? 2 : 1),
                  ),
                  child: Column(children: [
                    Text(weekdayShort[i],
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: i == 6 ? kDanger : kMuted)),
                    const SizedBox(height: 4),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: isToday ? kAccent : null, shape: BoxShape.circle),
                      child: Text('${d.day}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: isToday ? Colors.white : kInk)),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(height: 7, child: dayDots(store.eventsOn(d), store.todosDueOn(d).length)),
                  ]),
                ),
              );
            }),
          ),
      ]),
    );
  }
}

/// Lưới giờ trong ngày: sự kiện được đặt theo giờ, chạm vào ô trống để thêm lịch.
class DayTimeline extends StatefulWidget {
  const DayTimeline({super.key, required this.store, required this.day, required this.onEdit, required this.onAddAt});
  final AppStore store;
  final DateTime day;
  final ValueChanged<Event> onEdit;
  final ValueChanged<int> onAddAt; // phút trong ngày

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  static const hourH = 58.0;
  static const gutter = 48.0;
  late final ScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    final timed = widget.store.eventsOn(widget.day).where((e) => e.start != null).toList();
    var focus = 7 * 60;
    if (timed.isNotEmpty) {
      focus = timed.map((e) => e.span!.$1).reduce((a, b) => a < b ? a : b);
    } else if (widget.day == dateOnly(DateTime.now())) {
      focus = DateTime.now().hour * 60;
    }
    _ctrl = ScrollController(initialScrollOffset: ((focus - 60) / 60 * hourH).clamp(0.0, 24 * hourH));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.store.eventsOn(widget.day);
    final allDay = events.where((e) => e.start == null).toList();
    final todos = widget.store.todosDueOn(widget.day);
    final timed = events.where((e) => e.start != null).toList();
    final placed = layoutColumns<Event>([for (final e in timed) (e.span!.$1, e.span!.$2, e)]);
    final isToday = widget.day == dateOnly(DateTime.now());
    final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;

    return Column(children: [
      if (allDay.isNotEmpty || todos.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in allDay)
                ActionChip(
                  label: Text(e.title),
                  backgroundColor: pastel(e.color).bg,
                  labelStyle: TextStyle(color: pastel(e.color).fg, fontWeight: FontWeight.w800),
                  side: BorderSide.none,
                  onPressed: () => widget.onEdit(e),
                ),
              for (final t in todos)
                Chip(
                  label: Text('☐ ${t.text}'),
                  backgroundColor: pastel('yellow').bg,
                  labelStyle: TextStyle(color: pastel('yellow').fg, fontWeight: FontWeight.w800),
                  side: BorderSide.none,
                ),
            ]),
          ),
        ),
      Expanded(
        child: SingleChildScrollView(
          controller: _ctrl,
          padding: const EdgeInsets.only(bottom: 96, top: 8),
          child: SizedBox(
            height: 24 * hourH,
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth - gutter - 10;
              return Stack(children: [
                for (var h = 0; h < 24; h++) ...[
                  Positioned(
                    top: h * hourH,
                    left: gutter - 6,
                    right: 8,
                    child: const Divider(height: 1, color: kGrid, thickness: 1),
                  ),
                  if (h > 0)
                    Positioned(
                      top: h * hourH - 8,
                      left: 0,
                      width: gutter - 10,
                      child: Text('${two(h)}:00', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, color: kMuted)),
                    ),
                ],
                Positioned.fill(
                  left: gutter,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => widget.onAddAt(((d.localPosition.dy / hourH * 2).floor() * 30).clamp(0, 23 * 60)),
                  ),
                ),
                for (final p in placed)
                  Positioned(
                    top: p.start / 60 * hourH + 1,
                    left: gutter + p.col * (w / p.cols),
                    width: w / p.cols - 3,
                    height: ((p.end - p.start) / 60 * hourH - 2).clamp(26.0, 24 * hourH),
                    child: _block(p.item, p.start, p.end),
                  ),
                if (isToday)
                  Positioned(
                    top: nowMin / 60 * hourH - 4,
                    left: gutter - 6,
                    right: 8,
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle)),
                      const Expanded(child: Divider(height: 2, thickness: 2, color: kAccent)),
                    ]),
                  ),
              ]);
            }),
          ),
        ),
      ),
    ]);
  }

  Widget _block(Event e, int s, int en) {
    final p = pastel(e.color);
    return Material(
      color: p.bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => widget.onEdit(e),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 4, 6, 3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.fg, fontWeight: FontWeight.w800, fontSize: 12)),
            if (en - s >= 45)
              Text('${minToHhmm(s)} – ${minToHhmm(en >= 1440 ? 1439 : en)}', style: TextStyle(color: p.fg, fontSize: 10.5)),
          ]),
        ),
      ),
    );
  }
}
