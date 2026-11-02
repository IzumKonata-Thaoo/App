import 'package:flutter/material.dart';

import '../layout.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'clay.dart';
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
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Builder(
                builder: (_) {
                  final d = ws.add(Duration(days: i));
                  final sel = d == current;
                  final isToday = d == today;
                  final fg = sel ? Colors.white : kInk;
                  return Pressable(
                    onTap: () => onSelect(d),
                    label: fullDate(d),
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutBack,
                      offset: Offset(0, sel ? -0.06 : 0),
                      child: Clay(
                        color: sel ? kPrimary : Colors.white,
                        tint: sel ? kPrimary : kShadowTint,
                        radius: 18,
                        depth: sel ? 0.9 : 0.45,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Column(
                          children: [
                            Text(
                              weekdayShort[i],
                              style: ts(11, w: FontWeight.w700, c: sel ? Colors.white : (i == 6 ? kDanger : kMuted)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${d.day}',
                              style: ts(17, w: FontWeight.w800, c: fg),
                            ),
                            const SizedBox(height: 3),
                            SizedBox(
                              height: 5,
                              child: isToday && !sel
                                  ? Container(
                                      width: 14,
                                      height: 4,
                                      decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)),
                                    )
                                  : dots(sel ? [Colors.white] : dotsFor(store, d).take(2).toList()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Lưới giờ trong ngày: lịch là khối đặc, khung giờ cố định có vân sọc. Chạm ô trống để thêm lịch.
class DayTimeline extends StatefulWidget {
  const DayTimeline({
    super.key,
    required this.store,
    required this.day,
    required this.onEditEvent,
    required this.onEditRoutine,
    required this.onAddAt,
  });
  final AppStore store;
  final DateTime day;
  final ValueChanged<Event> onEditEvent;
  final ValueChanged<RoutineBlock> onEditRoutine;
  final ValueChanged<int> onAddAt;

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  static const hourH = 60.0;
  static const gutter = 50.0;
  late final ScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    final timed = itemsOn(widget.store, widget.day).where((i) => i.span != null).toList();
    var focus = 7 * 60;
    if (widget.day == dateOnly(DateTime.now())) {
      focus = DateTime.now().hour * 60;
    } else if (timed.isNotEmpty) {
      focus = timed.map((i) => i.span!.$1).reduce((a, b) => a < b ? a : b);
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
    final items = itemsOn(widget.store, widget.day);
    final allDay = items.where((i) => i.span == null).toList();
    final placed = layoutColumns<DayItem>([for (final i in items.where((i) => i.span != null)) (i.span!.$1, i.span!.$2, i)]);
    final isToday = widget.day == dateOnly(DateTime.now());
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;

    return Column(
      children: [
        if (allDay.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: allDay.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final it = allDay[i];
                  final p = pastel(it.color);
                  return Pressable(
                    onTap: it.event != null ? () => widget.onEditEvent(it.event!) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        it.kind == ItemKind.todo ? 'Việc: ${it.title}' : it.title,
                        style: ts(12, w: FontWeight.w700, c: p.fg),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            controller: _ctrl,
            padding: const EdgeInsets.only(bottom: 120, top: 10),
            child: SizedBox(
              height: 24 * hourH,
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth - gutter;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var h = 0; h < 24; h++) ...[
                        Positioned(
                          top: h * hourH,
                          left: gutter - 4,
                          right: 0,
                          child: Container(height: 1, color: kLine),
                        ),
                        if (h > 0)
                          Positioned(
                            top: h * hourH - 8,
                            left: 0,
                            width: gutter - 12,
                            child: Text(
                              '${two(h)}:00',
                              textAlign: TextAlign.right,
                              style: ts(11, c: kMuted),
                            ),
                          ),
                      ],
                      Positioned.fill(
                        left: gutter,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => widget.onAddAt(((d.localPosition.dy / hourH * 2).floor() * 30).clamp(0, 23 * 60)),
                        ),
                      ),
                      for (var k = 0; k < placed.length; k++)
                        Positioned(
                          top: placed[k].start / 60 * hourH + 2,
                          left: gutter + placed[k].col * (w / placed[k].cols),
                          width: w / placed[k].cols - 4,
                          height: ((placed[k].end - placed[k].start) / 60 * hourH - 4).clamp(28.0, 24 * hourH),
                          child: FadeUp(
                            delay: Duration(milliseconds: 50 * k),
                            child: _block(placed[k], isToday ? nowMin : -1),
                          ),
                        ),
                      if (isToday)
                        Positioned(
                          top: nowMin / 60 * hourH - 6,
                          left: gutter - 8,
                          right: 0,
                          child: IgnorePointer(
                            child: Row(
                              children: [
                                const PulseDot(color: kPrimary, size: 12),
                                Expanded(child: Container(height: 2, color: kPrimary)),
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(7)),
                                  child: Text(
                                    '${two(now.hour)}:${two(now.minute)}',
                                    style: ts(10.5, w: FontWeight.w800, c: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _block(Placed<DayItem> p, int nowMin) {
    final it = p.item;
    final pc = pastel(it.color);
    final h = (p.end - p.start) / 60 * hourH;
    final live = nowMin >= p.start && nowMin < p.end;
    final past = nowMin >= p.end;
    final routine = it.kind == ItemKind.routine;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  it.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts(13, w: FontWeight.w800, c: pc.fg, deco: past ? TextDecoration.lineThrough : null),
                ),
              ),
              if (routine && h >= 40)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Ic.repeat, size: 10, color: pc.fg),
                      const SizedBox(width: 3),
                      Text(
                        'Cố định',
                        style: ts(10, w: FontWeight.w700, c: pc.fg),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (h >= 44) Text('${minToHhmm(p.start)} – ${minToHhmm(p.end >= 1440 ? 1439 : p.end)}', style: ts(11, c: pc.fg)),
        ],
      ),
    );
    final box = Container(
      decoration: routine ? stripes(lighten(pc.bg, 0.35), pc.bg) : BoxDecoration(color: pc.bg, borderRadius: BorderRadius.circular(16)),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: live ? Border.all(color: pc.dot, width: 2) : null,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.5), Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.06)],
          stops: const [0, 0.1, 0.85, 1],
        ),
      ),
      child: content,
    );
    final card = Opacity(
      opacity: past ? 0.6 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: past ? null : clayShadow(pc.fg, depth: 0.5)),
        child: box,
      ),
    );
    return Pressable(
      scale: 0.97,
      label: it.title,
      onTap: switch (it.kind) {
        ItemKind.event => () => widget.onEditEvent(it.event!),
        ItemKind.routine => () => widget.onEditRoutine(it.routine!),
        ItemKind.todo => null,
      },
      child: live
          ? Loop(
              period: const Duration(milliseconds: 1800),
              child: card,
              builder: (_, t, c) => Transform.translate(offset: Offset(0, -2.5 * t), child: c),
            )
          : card,
    );
  }
}
